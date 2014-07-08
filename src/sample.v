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

module sample(
	// -- clock & reset
	input	core_clk,
	input	int_clk,
	input	int_clk_2x,
	input	ext_clk,
	output	sample_clk,
	input	core_rst,
	input	sample_rst,

	// -- 
	input		sample_en,
	input		ext_clk_mode,
	input		test_mode,
	input		ext_test_mode,
	input		falling_mode,
	input		half_mode,
	input		wireless_mode,
	input		quarter_mode,
	input		cons_mode,
	input	[23:0]	sample_divider,
	input		ext_trig_in,

	// --
	output	ledn,
	input		[15:0]	ext_data,
	output		[15:0]	sample_data,
	output	reg		sample_valid
);

// --
// internal signals definition
// --
wire	[15:0]	pos_sync_data;
wire	[15:0]	neg_sync_data;
reg	[15:0]	pos_data;
reg	[15:0]	neg_data;
reg	[15:0]	pos_data_1T;
reg	[15:0]	neg_data_1T;
reg	[15:0]	pos_data_2T;
reg	[15:0]	neg_data_2T;
reg	[15:0]	pos_data_final;
reg	[15:0]	neg_data_final;

reg		sample_en_1T;
reg	[23:0]	sample_cnt;
wire	[23:0]	sample_cnt_nxt;
reg		sample_rd;
wire		sample_rd_nxt;
wire		sample_valid_nxt;

// --
// Select between internal and external sampling clock...
// --
//wire	sample_clk;
wire	int_clk_mux;
BUFGMUX BUFGMUX_sample_2x(
  .O(int_clk_mux),	// Clock MUX output
  .I0(int_clk),		// Clock0 input
  .I1(int_clk_2x),	// Clock1 input
  .S(quarter_mode)
);
BUFGMUX BUFGMUX_sample(
  .O(sample_clk),		// Clock MUX output
  .I0(int_clk_mux),		// Clock0 input
  .I1(ext_clk),		// Clock1 input
  .S(ext_clk_mode)
);

// --
// Synchronize ext_data guarantees use of iob ff on spartan 3
// --
IDDR2	ext_sync0(.Q0(pos_sync_data[0]), .Q1(neg_sync_data[0]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[0]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync1(.Q0(pos_sync_data[1]), .Q1(neg_sync_data[1]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[1]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync2(.Q0(pos_sync_data[2]), .Q1(neg_sync_data[2]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[2]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync3(.Q0(pos_sync_data[3]), .Q1(neg_sync_data[3]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[3]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync4(.Q0(pos_sync_data[4]), .Q1(neg_sync_data[4]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[4]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync5(.Q0(pos_sync_data[5]), .Q1(neg_sync_data[5]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[5]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync6(.Q0(pos_sync_data[6]), .Q1(neg_sync_data[6]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[6]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync7(.Q0(pos_sync_data[7]), .Q1(neg_sync_data[7]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[7]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync8(.Q0(pos_sync_data[8]), .Q1(neg_sync_data[8]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[8]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync9(.Q0(pos_sync_data[9]), .Q1(neg_sync_data[9]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[9]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync10(.Q0(pos_sync_data[10]), .Q1(neg_sync_data[10]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[10]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync11(.Q0(pos_sync_data[11]), .Q1(neg_sync_data[11]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[11]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync12(.Q0(pos_sync_data[12]), .Q1(neg_sync_data[12]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[12]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync13(.Q0(pos_sync_data[13]), .Q1(neg_sync_data[13]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[13]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync14(.Q0(pos_sync_data[14]), .Q1(neg_sync_data[14]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[14]), .R(1'b0), .S(1'b0));
IDDR2	ext_sync15(.Q0(pos_sync_data[15]), .Q1(neg_sync_data[15]), .C0(sample_clk), .C1(~sample_clk), .CE(1'b1), .D(ext_data[15]), .R(1'b0), .S(1'b0));

always @(posedge sample_clk or posedge sample_rst)
begin
	if (sample_rst)
		pos_data <= `D 16'b0;
	else
//		pos_data <= `D half_mode ? ext_data : 
//							cons_mode ? {pos_sync_data[15:8], neg_sync_data[7:0]} : pos_sync_data;
		pos_data <= `D ext_clk_mode ? ext_data : pos_sync_data;
end
always @(negedge sample_clk or posedge sample_rst)
begin
	if (sample_rst)
		neg_data <= `D 16'b0;
	else
		neg_data <= `D neg_sync_data;
end

always @(posedge sample_clk)
begin
	pos_data_1T <= `D pos_data;
	pos_data_2T <= `D pos_data_1T;
//	pos_data_final <= `D (((pos_data ^ pos_data_1T) | (pos_data_1T ^ pos_data_2T)) & pos_data_final) | 
//	                     (~((pos_data ^ pos_data_1T) | (pos_data_1T ^ pos_data_2T))& pos_data_1T);
	pos_data_final <= `D ((pos_data ^ pos_data_1T) & pos_data_final) | 
	                     (~(pos_data ^ pos_data_1T) & pos_data_1T);
end
always @(negedge sample_clk or posedge sample_rst)
begin
	neg_data_1T <= `D neg_data;
	neg_data_2T <= `D neg_data_1T;
//	neg_data_final <= `D (((neg_data ^ neg_data_1T) | (neg_data_1T ^ neg_data_2T)) & neg_data_final) | 
//	                     (~((neg_data ^ neg_data_1T) | (neg_data_1T ^ neg_data_2T))& neg_data_1T);
	neg_data_final <= `D ((neg_data ^ neg_data_1T) & neg_data_final) | 
	                     (~(neg_data ^ neg_data_1T) & neg_data_1T);
end



// --
// sample data mux: external/test data
// --
wire	[15:0]	pre_data;
reg	[15:0]	half_data;
wire	[15:0]	half_data_nxt;
reg	[15:0]	neg_data_pos;
//assign half_data_nxt = {2{(((neg_data_pos[7:0] ^ pos_data[7:0]) | (pos_data[7:0] ^ pos_data_1T[7:0])) & half_data[7:0]) |
//                       (~((neg_data_pos[7:0] ^ pos_data[7:0]) | (pos_data[7:0] ^ pos_data_1T[7:0])) & pos_data[7:0])}};
//assign half_data_nxt = {neg_data[7:0], pos_data[7:0]};
assign half_data_nxt = wireless_mode ? {neg_data[7:0], pos_data[7:0]} :
							  {2{((neg_data_pos[7:0] ^ pos_data[7:0]) & half_data[7:0]) |
                       (~(neg_data_pos[7:0] ^ pos_data[7:0]) & pos_data[7:0])}};
always @(posedge sample_clk or posedge sample_rst)
begin
	if (sample_rst) begin
		half_data <= `D 16'b0;
	end else begin
		half_data <= `D half_data_nxt;
	end
end
always @(posedge sample_clk)
begin
	neg_data_pos <= `D neg_data;
end

reg	[15:0]	quarter_data;
wire	[15:0]	quarter_data_nxt;
//assign quarter_data_nxt[15:8] = quarter_data[7:0];
//assign quarter_data_nxt[7:0] = {2{(((neg_data_pos[3:0] ^ pos_data[3:0]) | (pos_data[3:0] ^ pos_data_1T[3:0])) & quarter_data[3:0]) |
//                               (~((neg_data_pos[3:0] ^ pos_data[3:0]) | (pos_data[3:0] ^ pos_data_1T[3:0])) & pos_data[3:0])}};
//assign quarter_data_nxt = {quarter_data[7:0], neg_data[3:0], pos_data[3:0]};
assign quarter_data_nxt[15:8] = quarter_data[7:0];
assign quarter_data_nxt[7:0] = {2{((neg_data_pos[3:0] ^ pos_data[3:0]) & quarter_data[3:0]) |
                               (~(neg_data_pos[3:0] ^ pos_data[3:0]) & pos_data[3:0])}};
always @(posedge sample_clk or posedge sample_rst)
begin
	if (sample_rst) begin
		quarter_data <= `D 16'b0;
	end else begin
		quarter_data <= `D quarter_data_nxt;
	end
end

reg	quarter_valid;
wire	quarter_valid_nxt;
assign quarter_valid_nxt = ~quarter_valid;
always @(posedge sample_clk or posedge sample_rst)
begin
	if (sample_rst)
		quarter_valid <= `D 1'b0;
	else
		quarter_valid <= `D quarter_valid_nxt;
end

// --
// Internal test mode. a 16-bit test pattern
// --
wire	rempty;
wire	pempty;
wire	wfull;
reg	stable_valid;
wire	stable_valid_nxt;
reg	[15:0]	test_data;
wire	[15:0]	test_data_nxt;

assign test_data_nxt = (wfull | (quarter_mode & ~quarter_valid)) ? test_data : 
		       ~sample_en ? 16'b0 : test_data + 1'b1;
always @(posedge sample_clk or posedge sample_rst)
begin
	if (sample_rst)
		test_data <= `D 16'b0;
	else
		test_data <= `D test_data_nxt;
end

assign pre_data = test_mode ? test_data :
						half_mode ? half_data :
						quarter_mode ? quarter_data :
						(ext_clk_mode & falling_mode) ? neg_data :
						(ext_clk_mode | cons_mode) ? pos_data :
						(falling_mode) ? neg_data_final : pos_data_final;
//assign pre_data = test_mode ? test_data :
//						half_mode ? half_data :
//						quarter_mode ? quarter_data :
//						(ext_clk_mode & falling_mode) ? neg_data : pos_data;

// --
// Transfer from input clock (whatever it may be) to the core clock 
// --
assign stable_valid_nxt = ~pempty;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		stable_valid <= `D 1'b0;
	else
		stable_valid <= `D stable_valid_nxt;
end

//async_fifo async_fifo(
//  .clkw(sample_clk),
//  .rstw(sample_rst),
//  .wfull(), 
//  .wr_en(sample_en), 
//  .wdata(pre_data),
//
//  .clkr(core_clk),
//  .rstr(core_rst),
//  .rd_en(1'b1), 
//  .rempty(rempty), 
//  .rdata(sample_data)
//);

wire	[15:0]	sync_dout;
wire	sample_wr_en = quarter_mode ? sample_en & quarter_valid : sample_en;
asyncfifo asyncfifo(
  .wr_clk(sample_clk),	// input wr_clk
  .wr_rst(sample_rst),	// input wr_rst
  .rd_clk(core_clk),	// input rd_clk
  .rd_rst(core_rst),	// input rd_rst
  .din(pre_data),	// input [15 : 0] din
  .wr_en(sample_wr_en),	// input wr_en
  .rd_en(sample_rd),	// input rd_en
  .dout(sample_data),	// output [15 : 0] dout
  .full(wfull),		// output full
  .empty(rempty),	// output empty
  .prog_empty(pempty) // output prog_empty
);


// --
// Sample data according to various sample rate 
// --
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		sample_en_1T <= `D 1'b0;
	else
		sample_en_1T <= `D sample_en;
end

assign sample_cnt_nxt = ~sample_en ? 24'b0 :
			(~ext_clk_mode & sample_en & ~sample_en_1T) ? sample_divider :
			(~ext_clk_mode & (sample_cnt == 24'b1)) ? sample_divider :
			(~ext_clk_mode) ? sample_cnt - 1'b1 : sample_cnt;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		sample_cnt <= `D 24'b0;
	else
		sample_cnt <= `D sample_cnt_nxt;
end

// --
// sample data out
// --
//assign sample_rd_nxt = ext_clk_mode ? stable_valid : (~rempty & sample_cnt_nxt == 24'b1);
assign sample_rd_nxt = stable_valid;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		sample_rd <= `D 1'b0;
	else
		sample_rd <= `D sample_rd_nxt;
end
assign sample_valid_nxt = sample_rd & (ext_clk_mode | (sample_cnt_nxt == 24'b1));
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		sample_valid <= `D 1'b0;
	else
		sample_valid <= `D sample_valid_nxt;
end
//always @(posedge core_clk or posedge core_rst)
//begin
//	if (core_rst)
//		sample_data <= `D 16'b0;
//	else
//		sample_data <= `D sync_dout;
//end

// --
// LED control
// --
assign ledn = ext_test_mode ? ~test_ledn_cnt[25] : ~ledn_cnt[19];
reg	[19:0]	ledn_cnt;
wire	[19:0]	ledn_cnt_nxt;
assign ledn_cnt_nxt = ~sample_en ? 20'hfffff : 
							 sample_valid ? ledn_cnt + 1 + (sample_divider >> 1) : ledn_cnt;
always @(posedge core_clk)
begin
	ledn_cnt <= `D ledn_cnt_nxt;
end

reg	[25:0]	test_ledn_cnt;
wire	[25:0]	test_ledn_cnt_nxt;
assign test_ledn_cnt_nxt = test_ledn_cnt + 1;
always @(posedge ext_clk)
begin
	test_ledn_cnt <= `D test_ledn_cnt_nxt;
end

endmodule

