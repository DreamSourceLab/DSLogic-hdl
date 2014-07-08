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

module dwrite(
	// -- clock & reset
	input	core_clk,
	input	core_rst,
	input	sdram_clk,
	input	sdram_rst,
	
	// -- status
	output wfifo_full,

	// --
	input	cons_mode,
	
	// -- capture
	input		sample_en,
	input	[31:0]	sample_last_cnt,
	input		capture_done,
	input		capture_valid,
	input	[15:0]	capture_data,

	// -- sdramc
	output	reg		wr_done,
    	input           	wr_valid,
    	output	           	wr_req,
    	output	reg	[31:0]  wr_addr,
    	output  	[15:0]  wr_data
);

// --
// internal signals definition
// --
wire			wfifo_empty;
wire	[9:0]	wfifo_rcnt;
wire			wfifo_prog_empty;

wire		wr_req_nxt;
wire	[31:0]	wr_addr_nxt;
reg		wr_req_1T;
wire		wr_done_nxt;
reg		capture_done_sync;
reg		capture_done_sdram_clk;

reg	[31:0]	wr_cnt;
wire	[31:0]	wr_cnt_nxt;
reg				sample_en_sync0;
reg				sample_en_sync1;
reg				sample_en_sync2;

reg	[3:0]		wfifo_empty_dly_cnt;
wire	[3:0]		wfifo_empty_dly_cnt_nxt;
reg				wfifo_real_empty;
wire				wfifo_real_empty_nxt;
reg				wfifo_real_empty_sync0;
reg				wfifo_real_empty_sync1;

assign wfifo_real_empty_nxt = (wfifo_empty_dly_cnt == 4'b0);
assign wfifo_empty_dly_cnt_nxt = capture_valid ? 4'b1111 :
											(wfifo_empty_dly_cnt != 4'b0) ? wfifo_empty_dly_cnt - 1'b1 : wfifo_empty_dly_cnt;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst) begin
		wfifo_empty_dly_cnt <= `D 4'b0;
		wfifo_real_empty <= `D 1'b0;
	end else begin
		wfifo_empty_dly_cnt <= `D wfifo_empty_dly_cnt_nxt;
		wfifo_real_empty <= `D wfifo_real_empty_nxt;
	end
end											

// --
// async fifo / core_clk -> sdram_clk
// --
wfifo wfifo(
	.wr_clk(core_clk),	// input wr_clk
	.wr_rst(core_rst),	// input wr_rst
	.rd_clk(sdram_clk),	// input rd_clk
	.rd_rst(sdram_rst),	// input rd_rst
	.din(capture_data),	// input [15 : 0] din
	.wr_en(capture_valid & ~cons_mode),	// input wr_en
	.rd_en(wr_valid),	// input rd_en
	.dout(wr_data),		// output [15 : 0] dout
	.full(wfifo_full),		// output full
	.empty(wfifo_empty),	// output empty
	.prog_empty(wfifo_prog_empty)
);

// --
// sdramc write interface
// --
// -- wr_done
reg	core_done;
wire	core_done_nxt;
reg	cons_done;
wire	cons_done_nxt;
assign core_done_nxt = capture_done_sdram_clk ? 1'b1 :
							  wr_done ? 1'b0 : core_done;
always @(posedge sdram_clk or posedge sdram_rst)
begin
	if (sdram_rst)
		core_done <= `D 1'b0;
	else
		core_done <= `D core_done_nxt;
end
always @(posedge sdram_clk or posedge sdram_rst)
begin
	if (sdram_rst) begin
		{capture_done_sdram_clk, capture_done_sync} <= `D 2'b0;
		{wfifo_real_empty_sync1, wfifo_real_empty_sync0} <= `D 2'b0;
	end else begin
		{capture_done_sdram_clk, capture_done_sync} <= `D {capture_done_sync, capture_done};
		{wfifo_real_empty_sync1, wfifo_real_empty_sync0} <= `D {wfifo_real_empty_sync0, wfifo_real_empty};
	end
end

//assign wr_done_nxt = (~cons_mode & core_done & wfifo_empty & wfifo_real_empty_sync1 & ~wr_done) ? 1'b1 : 
//							(cons_mode & ~cons_done & ~wfifo_prog_empty & ~wr_done) ? 1'b1 : 1'b0;
assign wr_done_nxt = (core_done & wfifo_empty & wfifo_real_empty_sync1 & ~wr_done) ? 1'b1 : 1'b0;
always @(posedge sdram_clk or posedge sdram_rst)
begin
	if (sdram_rst)
		wr_done <= `D 1'b0;
	else
		wr_done <= `D wr_done_nxt;
end
assign cons_done_nxt = wr_done ? 1'b1 :
							  (sample_en_sync1 & ~sample_en_sync2) ? 1'b0 : cons_done;
always @(posedge sdram_clk or posedge sdram_rst)
begin
	if (sdram_rst)
		cons_done <= `D 1'b0;
	else
		cons_done <= `D cons_done_nxt;
end

// -- wr_cnt
always @(posedge sdram_clk or posedge sdram_rst)
begin
	if (sdram_rst) begin
		sample_en_sync0 <= `D 1'b0;
		sample_en_sync1 <= `D 1'b0;
		sample_en_sync2 <= `D 1'b0;
	end else begin
		sample_en_sync0 <= `D sample_en;
		sample_en_sync1 <= `D sample_en_sync0;
		sample_en_sync2 <= `D sample_en_sync1;
	end
end
//
//assign wr_cnt_nxt = (sample_en_sync1 & ~sample_en_sync2) ? sample_depth - 1:
//						  (wr_req & wr_valid & |wr_cnt) ? wr_cnt - 1'b1 : wr_cnt;
//always @(posedge sdram_clk or posedge sdram_rst)
//begin
//	if (sdram_rst)
//		wr_cnt <= `D 32'b0;
//	else
//		wr_cnt <= `D wr_cnt_nxt;
//end

// -- wr_req
//assign wr_req_nxt = (wr_req & wr_valid & ~|wr_cnt) ? 1'b0 : 
//						  (~core_done & wfifo_prog_empty) ? 1'b0 :
//							~wfifo_prog_empty ? 1'b1 :
//						  (core_done & ~wr_done_nxt)? 1'b1 : wr_req;
//always @(posedge sdram_clk or posedge sdram_rst)
//begin
//	if (sdram_rst)
//		wr_req <= `D 1'b0;
//	else
//		wr_req <= `D wr_req_nxt;
//end
assign wr_req = ~wfifo_empty;

// -- wr_addr
assign wr_addr_nxt = (wr_valid & ({2'b0, wr_addr[31:2]} == sample_last_cnt)) ? 32'b0 :
		     wr_valid ? wr_addr + 3'b100 : wr_addr;
always @(posedge sdram_clk or posedge sdram_rst)
begin
	if (sdram_rst)
		wr_addr <= `D 32'b0;
	else
		wr_addr <= `D wr_addr_nxt;
end


endmodule
