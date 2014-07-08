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

module dread(
	// --clock & reset
	input	sdram_clk,
	input	sdram_rst,
	input	usb_clk,
	input	usb_rst,

	// -- config
	input		sys_en,
	input		read_start,
	input	[31:0]	sd_saddr,
	input	[31:0]	trig_real_pos,
	input		sd_fbe,
	input	[31:0]	sample_last_cnt,
	input		half_mode,
	input		quarter_mode,
	input		sd_lpb_mode,
	
	// -- status
	output	rfifo_empty,
	output	rfifo_full,

	// -- usb controller
	input		usb_rd,
	output		usb_rd_valid,
	output	[15:0]	usb_rdata,
	output	reg	usb_rdy,

	// -- sdram 
	output	reg		rd_req,
	input			rd_valid,
	output	reg	[31:0]	rd_addr,
	input			rd_rdy,
	input		[15:0]	rd_data
);

// --
// parameter
// --
parameter	RFIFO_UP = 10'd768;
parameter	RFIFO_DN = 10'd512;

parameter	READ_RDY = 10'd512;
parameter	READ_NRDY = 10'd32;

// --
// internal signals definition
// --
wire	[9:0]	rfifo_rcnt;
wire	[9:0]	rfifo_wcnt;
//wire		rfifo_empty;

// --
// read data from sdram to rfifo after capture done
// --
// -- rd_cnt
//reg	[31:2]	rd_cnt;
//wire	[31:2]	rd_cnt_nxt;
//reg		rd_done;
//wire		rd_done_nxt;
//
//assign rd_cnt_nxt = read_start ? sample_depth :
//		    //rd_rdy ? rd_cnt - 1'b1 : rd_cnt;
//		    (rd_valid & |rd_cnt) ? rd_cnt - 1'b1 : rd_cnt;
//always @(posedge sdram_clk or posedge sdram_rst)
//begin
//	if (sdram_rst)
//		rd_cnt <= `D 30'b0;
//	else
//		rd_cnt <= `D rd_cnt_nxt;
//end

// -- rd_addr
wire	[31:0]	rd_addr_nxt;

assign rd_addr_nxt = read_start ? sd_saddr :
						   (rd_valid & rd_addr == {sample_last_cnt[29:0], 2'b0}) ? 32'b0 : 
							rd_valid ? rd_addr + 3'b100 : rd_addr;
always @(posedge sdram_clk or posedge sdram_rst)
begin
	if (sdram_rst)
		rd_addr <= `D 32'b0;
	else
		rd_addr <= `D rd_addr_nxt;
end

// -- rd_req
wire	rd_req_nxt;

//assign rd_req_nxt = read_start ? 1'b1 :
//		    (rd_valid & ~|rd_cnt) ? 1'b0 : 
//			 (rfifo_wcnt > RFIFO_UP) ? 1'b0 :
//			 ((rfifo_wcnt < RFIFO_DN) & |rd_cnt) ? 1'b1 : rd_req;
reg	sys_en_sync0;
reg	sys_en_sync1;
reg	sys_en_sync2;
always @(posedge sdram_clk)
begin
	sys_en_sync0 <= `D sys_en;
	sys_en_sync1 <= `D sys_en_sync0;
	sys_en_sync2 <= `D sys_en_sync1;
end
reg   [7:0]	read_start_cnt;
wire	[7:0]	read_start_cnt_nxt;
//reg	read_start_1T;
//reg	read_start_2T;
//reg	read_start_3T;
//reg	read_start_4T;
reg	read_header;
wire	read_header_nxt;
//assign read_header_nxt = read_start_4T ? 1'b0 :
//								 read_start ? 1'b1 : read_header;
assign read_header_nxt = &read_start_cnt ? 1'b0 :
								 read_start ? 1'b1 : read_header;								 
reg	[15:0]	header;
wire	[15:0]	header_nxt;
assign header_nxt = (read_start & half_mode) ? trig_real_pos[15:0] << 1 :
                    (read_start & quarter_mode) ? trig_real_pos[15:0] << 2 :
                    (read_start) ? trig_real_pos[15:0] :
						  ((read_start_cnt == 8'd0) & half_mode) ? {trig_real_pos[30:16], trig_real_pos[15]} :
						  ((read_start_cnt == 8'd0) & quarter_mode) ? {trig_real_pos[29:16], trig_real_pos[15:14]} :
						  (read_start_cnt == 8'd0) ? trig_real_pos[31:16] :
						  (read_start_cnt == 8'd1) ? sd_saddr[15:0] :
						  (read_start_cnt == 8'd2) ? sd_saddr[31:16] : header;
assign read_start_cnt_nxt = read_header ? read_start_cnt + 1'b1 : read_start_cnt;
always @(posedge sdram_clk or posedge sdram_rst)
begin
	if (sdram_rst) begin
		read_start_cnt <= `D 9'b0;
		//read_start_1T <= `D 1'b0;
		//read_start_2T <= `D 1'b0;
		//read_start_3T <= `D 1'b0;
		//read_start_4T <= `D 1'b0;
		read_header <= `D 1'b0;
		header <= `D 16'b0;
	end else begin
		read_start_cnt <= `D read_start_cnt_nxt;
		//read_start_1T <= `D read_start;
		//read_start_2T <= `D read_start_1T;
		//read_start_3T <= `D read_start_2T;
		//read_start_4T <= `D read_start_3T;
		read_header <= `D read_header_nxt;
		header <= `D header_nxt;
	end
end

reg	rd_phase;
wire	rd_phase_nxt;
//assign rd_phase_nxt = (read_start_4T & sys_en_sync1) ? 1'b1 :
//							  ~sys_en_sync1 ? 1'b0 : rd_phase;
//assign rd_phase_nxt = (&read_start_cnt & sys_en_sync1) ? 1'b1 :
assign rd_phase_nxt = &read_start_cnt ? 1'b1 :
							 (sys_en_sync2 & ~sys_en_sync1) ? 1'b0 : rd_phase;
always @(posedge sdram_clk or posedge sdram_rst)
begin
	if (sdram_rst)
		rd_phase <= `D 1'b0;
	else
		rd_phase <= `D rd_phase_nxt;
end
//assign rd_req_nxt = read_start_4T ? 1'b1 :
//		    ~sys_en_sync1 ? 1'b0 : 
//		    (rfifo_wcnt >= RFIFO_UP & rd_phase) ? 1'b0 :
//		    (rfifo_wcnt <= RFIFO_DN & rd_phase) ? 1'b1 : rd_req;
assign rd_req_nxt = &read_start_cnt ? 1'b1 :
		    (sys_en_sync2 & ~sys_en_sync1) ? 1'b0 : 
		    (rfifo_wcnt >= RFIFO_UP & rd_phase) ? 1'b0 :
		    (rfifo_wcnt <= RFIFO_DN & rd_phase) ? 1'b1 : rd_req;			 
always @(posedge sdram_clk or posedge sdram_rst)
begin
	if (sdram_rst)
		rd_req <= `D 1'b0;
	else
		rd_req <= `D rd_req_nxt;
end

// --
//assign rd_done_nxt = (rd_valid & ~|rd_cnt) ? 1'b1 : rd_done;
//always @(posedge sdram_clk or posedge sdram_rst)
//begin
//	if (sdram_rst)
//		rd_done <= `D 1'b0;
//	else
//		rd_done <= `D rd_done_nxt;
//end

// --
// async fifo / sdram_clk -> usb_clk
// --
wire				rfifo_wr_en;
wire	[15:0]	rfifo_din;
wire	[15:0]	rfifo_dout;
wire				rfifo_rd_en;
reg				rfifo_rd_rst_sync;
reg				rfifo_rd_rst;
reg				rfifo_wr_rst_sync;
reg				rfifo_wr_rst;
always @(posedge sdram_clk)
begin
	rfifo_wr_rst_sync <= `D sdram_rst;
	rfifo_wr_rst <= `D rfifo_wr_rst_sync;
end
always @(posedge usb_clk)
begin
	rfifo_rd_rst_sync <= `D usb_rst;
	rfifo_rd_rst <= `D rfifo_rd_rst_sync;
end
assign rfifo_din = read_header ? header : rd_data;
assign rfifo_wr_en = sd_lpb_mode ? rd_rdy : rd_rdy | read_header;
rfifo rfifo(
  .wr_clk(sdram_clk),		// input wr_clk
  .wr_rst(rfifo_wr_rst | (sd_lpb_mode & ~sys_en)),		// input wr_rst
  .rd_clk(usb_clk),		// input rd_clk
  .rd_rst(rfifo_rd_rst | (sd_lpb_mode & ~sys_en)),		// input rd_rst
  .din(rfifo_din),		// input [15 : 0] din
  .wr_en(rfifo_wr_en),		// input wr_en
  .rd_en(rfifo_rd_en),		// input rd_en
  .dout(rfifo_dout),		// output [15 : 0] dout
  .full(rfifo_full),			// output full
  .empty(rfifo_empty),		// output empty
  .rd_data_count(rfifo_rcnt),	// output [9 : 0] rd_data_count
  .wr_data_count(rfifo_wcnt) // output [9 : 0] wr_data_count
);

// --
// output to usb controller
// --
reg	usb_data_phase;
wire	usb_data_phase_nxt;
reg	[7:0]	usb_rd_cnt;
wire	[7:0]	usb_rd_cnt_nxt;
assign usb_rd_cnt_nxt = usb_rd ? usb_rd_cnt + 1'b1 : usb_rd_cnt;
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst)
		usb_rd_cnt <= `D 8'b0;
	else
		usb_rd_cnt <= `D usb_rd_cnt_nxt;
end
assign usb_data_phase_nxt = (usb_rd & &usb_rd_cnt) ? 1'b1 : usb_data_phase;
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst)
		usb_data_phase <= `D 1'b0;
	else
		usb_data_phase <= `D usb_data_phase_nxt;
end

reg	quarter_toggle;
wire	quarter_toggle_nxt;
assign quarter_toggle_nxt = (quarter_mode & usb_rd & usb_data_phase) ? ~quarter_toggle : quarter_toggle;
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst)
		quarter_toggle <= `D 1'b0;
	else
		quarter_toggle <= `D quarter_toggle_nxt;
end
assign rfifo_rd_en = usb_rd & (quarter_mode & ~quarter_toggle | ~quarter_mode | ~usb_data_phase);

wire	[15:0]	usb_rdata_low;
reg	[15:0]	usb_rdata_high;
wire	[15:0]	usb_rdata_high_nxt;
assign usb_rdata_low = {4'b0, rfifo_dout[7:4], 4'b0, rfifo_dout[3:0]};
assign usb_rdata_high_nxt = {4'b0, rfifo_dout[15:12], 4'b0, rfifo_dout[11:8]};
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst)
		usb_rdata_high <= `D 16'b0;
	else
		usb_rdata_high <= `D usb_rdata_high_nxt;
end
assign usb_rdata = (quarter_mode & ~quarter_toggle & usb_data_phase) ? usb_rdata_low :
						 (quarter_mode & quarter_toggle & usb_data_phase) ? usb_rdata_high : rfifo_dout;

wire	usb_rdy_nxt;
assign usb_rdy_nxt = (rfifo_rcnt > READ_RDY & sys_en) ? 1'b1 :
		     (rfifo_rcnt < READ_NRDY | ~sys_en) ? 1'b0 : usb_rdy;
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst)
		usb_rdy <= `D 1'b0;
	else
		usb_rdy <= `D usb_rdy_nxt;
end

endmodule
