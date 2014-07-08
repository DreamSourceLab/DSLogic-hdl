/*
 * This file is part of the DSLogic-hdl project.
 *
 * Copyright (C) 2014 DreamSourceLab <support@dreamsourcelab.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
 */

`timescale 1ns/100ps
`define D #1

module loopback(
	// -- clock & reset
	input	core_clk,
	input	core_rst,
	input	sdram_clk,
	input	sdram_rst,
	input	usb_clk,
	input	usb_rst,
	input	sd_lpb_mode,
	input	mux,
	
	// -- control
	input				sd_dcm0_locked,
	input				sd_dcm1_locked,
	output	reg	sd_clk_rst,
	output	reg	sd_clk_sel,
	output	reg	sd_clk_en,

	// -- write
	output		[31:0]	sample_depth,
	output					capture_done,
	output	reg				capture_valid,
	output	reg	[15:0]	capture_data,
	input			sdwr_done,
	input			sd_init_done,

	// -- read
	output	reg		read_done,
	output	reg		lpb_read,
	output			read_start,
	output		[31:0]	sd_saddr,
	output			sd_fbe,
	output	reg		usb_rd,
	input			usb_rd_valid,
	input		[15:0]	usb_rdata,
	input			usb_rdy,

	// -- error
	output	reg		lpb_error
);


//parameter	DEPTH = 32'h3fffff;
parameter	DEPTH = 32'hffffff;

parameter	INIT  = 3'b000;
parameter	SW_WR = 3'b001;
parameter	WRITE = 3'b010;
parameter	SW_RD = 3'b100;
parameter	READ  = 3'b101;

// --
// signal declare
// --
wire	sd_clk_rst_nxt;
wire	sd_clk_sel_nxt;
wire	sd_clk_en_nxt;
reg	[3:0]	sd_clk_rst_cnt;
wire	[3:0]	sd_clk_rst_cnt_nxt;

reg	[2:0]	lpb_cstate;
reg	[2:0]	lpb_nstate;

reg	swwr_done;
wire	swwr_done_nxt;
reg	swrd_done;
wire	swrd_done_nxt;

reg	sd_init_done_sync;
reg	init_done;
reg	sdwr_done_sync;
reg	write_done;

reg	mux_sync;
reg	mux_trig;

// -- loopback test for 128Mbit SDRAM
assign sample_depth = DEPTH;

// -- sd_clk_sel / sd_clk_en
assign sd_clk_sel_nxt = ((lpb_cstate != SW_WR) & (lpb_nstate == SW_WR)) ? 1'b1 :
								((lpb_cstate != SW_RD) & (lpb_nstate == SW_RD)) ? 1'b0 : sd_clk_sel;
assign sd_clk_en_nxt  = ((lpb_nstate != SW_WR) & (lpb_nstate != SW_RD)) ? 1'b1 : 1'b0;
assign sd_clk_rst_nxt = ((lpb_cstate != SW_WR) & (lpb_nstate == SW_WR)) ? 1'b1 :
								((lpb_cstate != SW_RD) & (lpb_nstate == SW_RD)) ? 1'b1 :
								~|sd_clk_rst_cnt ? 1'b0 : sd_clk_rst;
assign sd_clk_rst_cnt_nxt = ((lpb_cstate != SW_WR) & (lpb_nstate == SW_WR)) ? 4'b1111 : 
									 ((lpb_cstate != SW_RD) & (lpb_nstate == SW_RD)) ? 4'b1111 :
									 |sd_clk_rst_cnt ? sd_clk_rst_cnt - 1'b1 : sd_clk_rst_cnt;
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst) begin
		sd_clk_sel <= `D 1'b0;
		sd_clk_en <= `D 1'b0;
		sd_clk_rst <= `D 1'b0;
		sd_clk_rst_cnt <= `D 4'b0;
	end else begin
		sd_clk_sel <= `D sd_clk_sel_nxt;
		sd_clk_en <= `D sd_clk_en_nxt;
		sd_clk_rst <= `D sd_clk_rst_nxt;
		sd_clk_rst_cnt <= `D sd_clk_rst_cnt_nxt;
	end
end

// -- swwr_done / swrd_done
reg	sd_dcm0_locked_sync;
reg	sd_clk0_locked;
reg	sd_clk0_locked_1T;
reg	sd_dcm1_locked_sync;
reg	sd_clk1_locked;
reg	sd_clk1_locked_1T;
reg	sd_clk_locked;
reg	sd_clk_locked_1T;
always @(posedge usb_clk)
begin
	sd_dcm0_locked_sync <= `D sd_dcm0_locked;
	sd_clk0_locked <= `D sd_dcm0_locked_sync;
	sd_clk0_locked_1T <= `D sd_clk0_locked;
	sd_dcm1_locked_sync <= `D sd_dcm1_locked;
	sd_clk1_locked <= `D sd_dcm1_locked_sync;
	sd_clk1_locked_1T <= `D sd_clk1_locked;
	sd_clk_locked <= `D sd_clk0_locked & sd_clk1_locked;
	sd_clk_locked_1T <= `D sd_clk_locked;
end


//assign swwr_done_nxt = ((lpb_cstate == SW_WR) & sd_clk_locked & ~sd_clk_locked_1T) ? 1'b1 : 1'b0;
//assign swrd_done_nxt = ((lpb_cstate == SW_RD) & sd_clk_locked & ~sd_clk_locked_1T) ? 1'b1 : 1'b0;
assign swwr_done_nxt = ((lpb_cstate == SW_WR) & sd_clk_locked) ? 1'b1 : 1'b0;
assign swrd_done_nxt = ((lpb_cstate == SW_RD) & sd_clk_locked) ? 1'b1 : 1'b0;
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst) begin
		swwr_done <= `D 1'b0;
		swrd_done <= `D 1'b0;
	end else begin
		swwr_done <= `D swwr_done_nxt;
		swrd_done <= `D swrd_done_nxt;
	end
end

// -- state machine
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst)
		lpb_cstate <= `D INIT;
	else
		lpb_cstate <= `D lpb_nstate;
end

always @(*)
begin
	case(lpb_cstate)
		INIT:
			if (sd_lpb_mode & init_done & mux_trig)
				lpb_nstate = SW_WR;
			else
				lpb_nstate = INIT;
		SW_WR:
			if (swwr_done)
				lpb_nstate = WRITE;
			else
				lpb_nstate = SW_WR;
		WRITE:
			if (write_done)
				lpb_nstate = SW_RD;
			else
				lpb_nstate = WRITE;
		SW_RD:
			//if (swrd_done)
			if (usb_rdy)
				lpb_nstate = READ;
			else
				lpb_nstate = SW_RD;
		READ:
			if (read_done)
				lpb_nstate = SW_WR;
			else
				lpb_nstate = READ;
		default:
			lpb_nstate = INIT;
	endcase
end

// -- init_done / write_done
reg	[7:0]	sdwr_done_shift;
reg			sdwr_done_extend;
wire			sdwr_done_extend_nxt;
assign sdwr_done_extend_nxt = |sdwr_done_shift;
always @(posedge sdram_clk)
begin
	sdwr_done_shift <= `D {sdwr_done_shift[6:0], sdwr_done};
	sdwr_done_extend <= `D sdwr_done_extend_nxt;
end

always @(posedge usb_clk)
begin
	sd_init_done_sync <= `D sd_init_done;
	init_done <= `D sd_init_done_sync;
	mux_sync <= `D mux;
	mux_trig <= `D mux_sync;
	sdwr_done_sync <= `D sdwr_done_extend;
	write_done <= `D sdwr_done_sync;
end

reg	wr_phase;
reg	rd_phase;
wire	wr_phase_nxt;
wire	rd_phase_nxt;
wire	lpb_read_nxt;

assign wr_phase_nxt = (lpb_nstate == WRITE);
assign rd_phase_nxt = (lpb_nstate == READ);
assign lpb_read_nxt = (lpb_nstate == SW_RD) | (lpb_nstate == READ);
always @(posedge usb_clk)
begin
	wr_phase <= `D wr_phase_nxt;
	rd_phase <= `D rd_phase_nxt;
	lpb_read <= `D lpb_read_nxt;
end

// -- write @ core_clk
reg	wr_phase_sync;
reg	wr_flag;
reg	wr_flag_1T;
always @(posedge core_clk)
begin
	wr_phase_sync <= `D wr_phase;
	wr_flag <= `D wr_phase_sync;
	wr_flag_1T <= `D wr_flag;
end

reg	[31:0]	write_cnt;
wire	[31:0]	write_cnt_nxt;
reg	wr_loop;
wire	wr_loop_nxt;
assign wr_loop_nxt = (wr_flag & ~wr_flag_1T) ? ~wr_loop : wr_loop;
assign write_cnt_nxt = (wr_flag & ~wr_flag_1T) ? DEPTH :
							  capture_valid ? write_cnt - 1'b1 : write_cnt;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst) begin
		wr_loop <= `D 1'b0;
		write_cnt <= `D DEPTH;
	end else begin
		wr_loop <= `D wr_loop_nxt;
		write_cnt <= `D write_cnt_nxt;
	end
end

wire	capture_valid_nxt;
wire	[31:0]	capture_data_nxt;
assign capture_done = capture_valid & ~|write_cnt;
assign capture_valid_nxt = (wr_flag & ~wr_flag_1T) ? 1'b1 :
									~|write_cnt ? 1'b0 : capture_valid;
assign capture_data_nxt = (~wr_loop & capture_valid) ? capture_data + 1'b1 :
								  (wr_loop & capture_valid) ? capture_data - 1'b1 : capture_data;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst) begin
		capture_data <= `D 16'b0;
		capture_valid <= `D 1'b0;
	end else begin
		capture_data <= `D capture_data_nxt;
		//capture_data <= `D 16'h1;
		capture_valid <= `D capture_valid_nxt;
	end
end

// -- read @ usb_clk
reg	[31:0]	read_cnt;
wire	[31:0]	read_cnt_nxt;
reg		read_loop;
wire		read_loop_nxt;

reg	rd_phase_sync;
reg	rd_phase_sdram;
reg	rd_phase_sdram_1T;
always @(posedge sdram_clk)
begin
	rd_phase_sync <= `D rd_phase;
	rd_phase_sdram <= `D rd_phase_sync;
	rd_phase_sdram_1T <= `D rd_phase_sdram;
end
assign read_start = rd_phase_sdram & ~rd_phase_sdram_1T;
// --
reg	rd_phase_1T;
always @(posedge usb_clk)
begin
	rd_phase_1T <= `D rd_phase;
end
assign usb_start = rd_phase & ~rd_phase_1T;

// --
assign sd_saddr = 32'b0;
assign sd_fbe = 1'b0;
wire	usb_rd_nxt;
assign usb_rd_nxt = usb_start ? 1'b1 :
						  ((read_cnt == 32'b0) & usb_rd & usb_rd_valid) ? 1'b0 : usb_rd;
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst) begin
		usb_rd <= `D 1'b0;
	end else begin
		usb_rd <= `D usb_rd_nxt;
	end
end

assign read_done_nxt = read_done ? 1'b0 : 
							  (read_cnt == 32'b0 & usb_rd & usb_rd_valid) ? 1'b1 : read_done;
assign read_loop_nxt = usb_start ? ~read_loop : read_loop;
assign read_cnt_nxt = usb_start ? DEPTH :
							 (usb_rd & usb_rd_valid) ? read_cnt - 1'b1 : read_cnt;
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst) begin
		read_cnt <= `D 32'b0;
		read_done <= `D 1'b0;
		read_loop <= `D 1'b0;
	end else begin
		read_cnt <= `D read_cnt_nxt;
		read_done <= `D read_done_nxt;
		read_loop <= `D read_loop_nxt;
	end
end



// -- read data check
reg	[15:0]	exp_data;
wire	[15:0]	exp_data_nxt;
wire				lpb_error_nxt;

assign exp_data_nxt = (~read_loop & usb_rd & usb_rd_valid) ? exp_data + 1'b1 :
							 (read_loop & usb_rd & usb_rd_valid) ? exp_data - 1'b1 : exp_data;
assign lpb_error_nxt = (usb_rd & usb_rd_valid & (exp_data != usb_rdata) | lpb_error) ? 1'b1 : 1'b0;
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst) begin
		exp_data <= `D 16'b0;
		lpb_error <= `D 1'b0;
	end else begin
		exp_data <= `D exp_data_nxt;
		//exp_data <= `D 16'h1;
		lpb_error <= `D lpb_error_nxt;
	end
end


endmodule
