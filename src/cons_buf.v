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

module cons_buf (
	// -- Clock & Reset
	input					core_clk,
	input					core_rst,
	input   				sdram_clk,
	input   				sd_rst,

	// --
	input					cons_mode,

	// -- data in
	input					sample_en,
	input					capture_done,
	input					capture_valid,
	input	[15:0]		capture_data,
	input					wr_done,

	// -- dread
	input					rd_req,
	output				rd_valid,
	input		[31:0]	rd_addr,
	output				rd_rdy,
	output	[15:0]	rd_data,

	// -- DSO config
	input		[23:0]	dso_sampleDivider,
	input		[23:0]	dso_triggerPos,
	input		[7:0]		dso_triggerSlope,
	input		[7:0]		dso_triggerSource,
	input		[16:0]	dso_triggerValue,
	
	// -- sdram
	// -- dread
	output				read_start,
	output				sd_rd_req,
	input					sd_rd_valid,
	output	[31:0]	sd_rd_addr,
	input					sd_rd_rdy,
	input		[15:0]	sd_rd_data
);

`define DP_MAXBIT			12
`define FPS_MAX			24'd5000000

// --
// internal signals definition
// --
reg	buf_rd_valid;
reg	buf_rd_rdy;
wire	[15:0]	buf_rd_data;
wire	cfifo_full;
wire	cfifo_empty;
reg	cfifo_wr;
wire	cfifo_wr_nxt;
reg	capture_wr;
wire	capture_wr_nxt;
reg	[`DP_MAXBIT:0]	cfifo_wr_cnt;
wire	[`DP_MAXBIT:0]	cfifo_wr_cnt_nxt;
wire	[`DP_MAXBIT:0]	cfifo_cnt;
reg	[15:0]	cfifo_din;
wire	[15:0]	cfifo_din_nxt;
wire	cfifo_rd;
reg	cfifo_rd_1T;
wire	[15:0]	cfifo_dout;
reg	[23:0]	div_cnt;
wire	[23:0]	div_cnt_nxt;
reg	sample_en_1T;
reg	[23:0]	fps_cnt;
wire	[23:0]	fps_cnt_nxt;

assign sd_rd_req = cons_mode ? 1'b0 : rd_req;
assign sd_rd_addr = cons_mode ? 32'b0 : rd_addr;
assign rd_valid = cons_mode ? buf_rd_valid : sd_rd_valid;
assign rd_rdy = cons_mode ? buf_rd_rdy : sd_rd_rdy;
assign rd_data = cons_mode ? buf_rd_data : sd_rd_data;

// --
// detection
// --
reg				rising0;
wire				rising0_nxt;
reg				falling0;
wire				falling0_nxt;
reg				rising1;
wire				rising1_nxt;
reg				falling1;
wire				falling1_nxt;
reg	[16:0]	capture_data_1T;
reg	[16:0]	capture_data_2T;
reg	[16:0]	capture_data_4T;
reg	[16:0]	capture_data_8T;
reg	[16:0]	capture_data_16T;
reg	[3:0]		slope01_log;
wire	[3:0]		slope01_log_nxt;
reg	[3:0]		slope02_log;
wire	[3:0]		slope02_log_nxt;
reg	[3:0]		slope04_log;
wire	[3:0]		slope04_log_nxt;
reg	[3:0]		slope08_log;
wire	[3:0]		slope08_log_nxt;
reg	[3:0]		slope016_log;
wire	[3:0]		slope016_log_nxt;
reg	[3:0]		slope11_log;
wire	[3:0]		slope11_log_nxt;
reg	[3:0]		slope12_log;
wire	[3:0]		slope12_log_nxt;
reg	[3:0]		slope14_log;
wire	[3:0]		slope14_log_nxt;
reg	[3:0]		slope18_log;
wire	[3:0]		slope18_log_nxt;
reg	[3:0]		slope116_log;
wire	[3:0]		slope116_log_nxt;

assign slope01_log_nxt = (sample_en & ~sample_en_1T) ? 'b0101 :
							   (capture_wr & (capture_data[7:0] > capture_data_1T[7:0])) ? {slope01_log[2:0], 1'b1} :
                        (capture_wr & (capture_data[7:0] < capture_data_1T[7:0])) ? {slope01_log[2:0], 1'b0} : slope01_log;	
assign slope02_log_nxt = (sample_en & ~sample_en_1T) ? 'b0101 :
							   (capture_wr & (capture_data[7:0] > capture_data_2T[7:0])) ? {slope02_log[2:0], 1'b1} :
                        (capture_wr & (capture_data[7:0] < capture_data_2T[7:0])) ? {slope02_log[2:0], 1'b0} : slope02_log;	
assign slope04_log_nxt = (sample_en & ~sample_en_1T) ? 'b0101 :
							   (capture_wr & (capture_data[7:0] > capture_data_4T[7:0])) ? {slope04_log[2:0], 1'b1} :
                        (capture_wr & (capture_data[7:0] < capture_data_4T[7:0])) ? {slope04_log[2:0], 1'b0} : slope04_log;	
assign slope08_log_nxt = (sample_en & ~sample_en_1T) ? 'b0101 :
							   (capture_wr & (capture_data[7:0] > capture_data_8T[7:0])) ? {slope08_log[2:0], 1'b1} :
                        (capture_wr & (capture_data[7:0] < capture_data_8T[7:0])) ? {slope08_log[2:0], 1'b0} : slope08_log;	
assign slope016_log_nxt = (sample_en & ~sample_en_1T) ? 'b0101 :
							   (capture_wr & (capture_data[7:0] > capture_data_16T[7:0])) ? {slope016_log[2:0], 1'b1} :
                        (capture_wr & (capture_data[7:0] < capture_data_16T[7:0])) ? {slope016_log[2:0], 1'b0} : slope016_log;									
assign slope11_log_nxt = (sample_en & ~sample_en_1T) ? 'b0101 :
							   (capture_wr & (capture_data[15:8] > capture_data_1T[15:8])) ? {slope11_log[2:0], 1'b1} :
                        (capture_wr & (capture_data[15:8] < capture_data_1T[15:8])) ? {slope11_log[2:0], 1'b0} : slope11_log;	
assign slope12_log_nxt = (sample_en & ~sample_en_1T) ? 'b0101 :
							   (capture_wr & (capture_data[15:8] > capture_data_2T[15:8])) ? {slope12_log[2:0], 1'b1} :
                        (capture_wr & (capture_data[15:8] < capture_data_2T[15:8])) ? {slope12_log[2:0], 1'b0} : slope12_log;	
assign slope14_log_nxt = (sample_en & ~sample_en_1T) ? 'b0101 :
							   (capture_wr & (capture_data[15:8] > capture_data_4T[15:8])) ? {slope14_log[2:0], 1'b1} :
                        (capture_wr & (capture_data[15:8] < capture_data_4T[15:8])) ? {slope14_log[2:0], 1'b0} : slope14_log;	
assign slope18_log_nxt = (sample_en & ~sample_en_1T) ? 'b0101 :
							   (capture_wr & (capture_data[15:8] > capture_data_8T[15:8])) ? {slope18_log[2:0], 1'b1} :
                        (capture_wr & (capture_data[15:8] < capture_data_8T[15:8])) ? {slope18_log[2:0], 1'b0} : slope18_log;	
assign slope116_log_nxt = (sample_en & ~sample_en_1T) ? 'b0101 :
							   (capture_wr & (capture_data[15:8] > capture_data_16T[15:8])) ? {slope116_log[2:0], 1'b1} :
                        (capture_wr & (capture_data[15:8] < capture_data_16T[15:8])) ? {slope116_log[2:0], 1'b0} : slope116_log;									

always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst) begin
		capture_data_1T <= `D 'b0;
		capture_data_2T <= `D 'b0;
		capture_data_4T <= `D 'b0;
		capture_data_8T <= `D 'b0;
		capture_data_16T <= `D 'b0;
		slope01_log <= `D 'b0101;
		slope02_log <= `D 'b0101;
		slope04_log <= `D 'b0101;
		slope08_log <= `D 'b0101;
		slope016_log <= `D 'b0101;
		slope11_log <= `D 'b0101;
		slope12_log <= `D 'b0101;
		slope14_log <= `D 'b0101;
		slope18_log <= `D 'b0101;
		slope116_log <= `D 'b0101;
	end else begin
		capture_data_1T <= `D capture_wr ? capture_data : capture_data_1T;
		capture_data_2T <= `D capture_wr & cfifo_wr_cnt[0] ? capture_data : capture_data_2T;
		capture_data_4T <= `D capture_wr & &cfifo_wr_cnt[1:0] ? capture_data : capture_data_4T;
		capture_data_8T <= `D capture_wr & &cfifo_wr_cnt[2:0] ? capture_data : capture_data_8T;
		capture_data_16T <= `D capture_wr & &cfifo_wr_cnt[3:0] ? capture_data : capture_data_16T;
		slope01_log <= `D slope01_log_nxt;
		slope02_log <= `D slope02_log_nxt;
		slope04_log <= `D slope04_log_nxt;
		slope08_log <= `D slope08_log_nxt;
		slope016_log <= `D slope016_log_nxt;
		slope11_log <= `D slope11_log_nxt;
		slope12_log <= `D slope12_log_nxt;
		slope14_log <= `D slope14_log_nxt;
		slope18_log <= `D slope18_log_nxt;
		slope116_log <= `D slope116_log_nxt;		
	end
end

assign rising0_nxt = &slope01_log | &slope02_log | &slope04_log |
                     &slope08_log | &slope016_log;
assign rising1_nxt = &slope11_log | &slope12_log | &slope14_log |
                     &slope18_log | &slope116_log;
assign falling0_nxt = ~|slope01_log | ~|slope02_log | ~|slope04_log |
                     ~|slope08_log | ~|slope016_log;
assign falling1_nxt = ~|slope11_log | ~|slope12_log | ~|slope14_log |
                     ~|slope18_log | ~|slope116_log;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst) begin
		rising0 <= `D 1'b0;
		rising1 <= `D 1'b0;
		falling0 <= `D 1'b0;
		falling1 <= `D 1'b0;
	end else begin
		rising0 <= `D rising0_nxt;
		rising1 <= `D rising1_nxt;
		falling0 <= `D falling0_nxt;
		falling1 <= `D falling1_nxt;
	end
end

// --
// trigger
// --
reg	[`DP_MAXBIT:0]	redunt_cnt;
wire	[`DP_MAXBIT:0]	redunt_cnt_nxt;
reg	redunt_rd;
wire	redunt_rd_nxt;
wire	cfifo_almost_full;
reg	buf_rdy;
wire	buf_rdy_nxt;
reg	buf_rdy_1T;
reg	trigger_hit;
wire	trigger_hit_nxt;
reg	trigger_hit_1T;
reg	rising0_hit;
reg	falling0_hit;
reg	rising1_hit;
reg	falling1_hit;	
wire	rising0_hit_nxt;
wire	falling0_hit_nxt;
wire	rising1_hit_nxt;
wire	falling1_hit_nxt;
reg	auto_req;
reg	rising0_req;
reg	falling0_req;
reg	rising1_req;
reg	falling1_req;
reg	rising0a1_req;
reg	falling0a1_req;
reg	rising0o1_req;
reg	falling0o1_req;
wire	auto_req_nxt;
wire	rising0_req_nxt;
wire	falling0_req_nxt;
wire	rising1_req_nxt;
wire	falling1_req_nxt;
wire	rising0a1_req_nxt;
wire	falling0a1_req_nxt;
wire	rising0o1_req_nxt;
wire	falling0o1_req_nxt;

// -- hit condition
assign rising0_hit_nxt = (capture_data[7:0] >= dso_triggerValue[7:0]) &
                     (capture_data_1T[7:0] <= dso_triggerValue[7:0]) &
							(rising0 | (~rising0 & ~falling0));
assign rising1_hit_nxt = (capture_data[15:8] >= dso_triggerValue[15:8]) &
                     (capture_data_1T[15:8] <= dso_triggerValue[15:8]) &
							(rising1 | (~rising1 & ~falling1));
assign falling0_hit_nxt = (capture_data[7:0] <= dso_triggerValue[7:0]) &
                      (capture_data_1T[7:0] >= dso_triggerValue[7:0]) &
							 (falling0 | (~rising0 & ~falling0));
assign falling1_hit_nxt = (capture_data[15:8] <= dso_triggerValue[15:8]) &
                      (capture_data_1T[15:8] >= dso_triggerValue[15:8]) &
							 (falling1 | (~rising1 & ~falling1));	
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst) begin
		rising0_hit <= `D 1'b0;
		rising1_hit <= `D 1'b0;
		falling0_hit <= `D 1'b0;
		falling1_hit <= `D 1'b0;
	end else begin
		rising0_hit <= `D rising0_hit_nxt;
		rising1_hit <= `D rising1_hit_nxt;
		falling0_hit <= `D falling0_hit_nxt;
		falling1_hit <= `D falling1_hit_nxt;
	end
end

// -- trigger setting
assign	auto_req_nxt = (dso_triggerSource == 'd0);
assign	rising0_req_nxt = (dso_triggerSource == 'd1) & (dso_triggerSlope == 'b0);
assign	falling0_req_nxt = (dso_triggerSource == 'd1) & (dso_triggerSlope == 'b1);
assign	rising1_req_nxt = (dso_triggerSource == 'd2) & (dso_triggerSlope == 'b0);
assign	falling1_req_nxt = (dso_triggerSource == 'd2) & (dso_triggerSlope == 'b1);
assign	rising0a1_req_nxt = (dso_triggerSource == 'd3) & (dso_triggerSlope == 'b0);
assign	falling0a1_req_nxt = (dso_triggerSource == 'd3) & (dso_triggerSlope == 'b1);
assign	rising0o1_req_nxt = (dso_triggerSource == 'd4) & (dso_triggerSlope == 'b0);
assign	falling0o1_req_nxt = (dso_triggerSource == 'd4) & (dso_triggerSlope == 'b1);
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst) begin
		auto_req <= `D 1'b0;
		rising0_req <= `D 1'b0;
		falling0_req <= `D 1'b0;
		rising1_req <= `D 1'b0;
		falling1_req <= `D 1'b0;
		rising0a1_req <= `D 1'b0;
		falling0a1_req <= `D 1'b0;
		rising0o1_req <= `D 1'b0;
		falling0o1_req <= `D 1'b0;
	end else begin
		auto_req <= `D auto_req_nxt;
		rising0_req <= `D rising0_req_nxt;
		falling0_req <= `D falling0_req_nxt;
		rising1_req <= `D rising1_req_nxt;
		falling1_req <= `D falling1_req_nxt;
		rising0a1_req <= `D rising0a1_req_nxt;
		falling0a1_req <= `D falling0a1_req_nxt;
		rising0o1_req <= `D rising0o1_req_nxt;
		falling0o1_req <= `D falling0o1_req_nxt;
	end
end
							
assign trigger_hit_nxt = (cfifo_wr & auto_req) ? 1'b1 :
                         (cfifo_wr & rising0_req & rising0_hit & cfifo_cnt >= dso_triggerPos) ? 1'b1 : 
								 (cfifo_wr & falling0_req & falling0_hit & cfifo_cnt >= dso_triggerPos) ? 1'b1 :
								 (cfifo_wr & rising1_req & rising1_hit & cfifo_cnt >= dso_triggerPos) ? 1'b1 :
								 (cfifo_wr & falling1_req & falling1_hit & cfifo_cnt >= dso_triggerPos) ? 1'b1 :
								 (cfifo_wr & rising0a1_req & rising0_hit & rising1_hit & cfifo_cnt >= dso_triggerPos) ? 1'b1 :
								 (cfifo_wr & falling0a1_req & falling0_hit & falling1_hit & cfifo_cnt >= dso_triggerPos) ? 1'b1 :
								 (cfifo_wr & rising0o1_req & (rising0_hit | rising1_hit) & cfifo_cnt >= dso_triggerPos) ? 1'b1 :
								 (cfifo_wr & falling0o1_req & (falling0_hit | falling1_hit) & cfifo_cnt >= dso_triggerPos) ? 1'b1 :								 
								 (buf_rdy_1T & ~buf_rdy) ? 1'b0 : trigger_hit;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst) begin
		trigger_hit <= `D 1'b0;
		trigger_hit_1T <= `D 1'b0;
	end else begin
		trigger_hit <= `D trigger_hit_nxt;
		trigger_hit_1T <= `D trigger_hit;
	end
end

// -- trigger position processing
assign redunt_rd_nxt = ((trigger_hit & ~trigger_hit_1T) | (redunt_rd & redunt_cnt == 'b10)) ? 1'b0 : 
							  ((cfifo_almost_full & ~trigger_hit) | (trigger_hit_1T & redunt_cnt > 'b1)) ? 1'b1 : redunt_rd;
assign redunt_cnt_nxt = (sample_en & ~sample_en_1T) ? dso_triggerPos :
                        (trigger_hit & ~trigger_hit_1T) ? cfifo_cnt - dso_triggerPos :  
                        (redunt_rd & trigger_hit_1T & redunt_cnt != 'b0) ? redunt_cnt - 1'b1 : redunt_cnt;							  
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst) begin
		redunt_rd <= `D 1'b0;
		redunt_cnt <= `D 'b0;
	end else begin
		redunt_rd <= `D redunt_rd_nxt;
		redunt_cnt <= `D redunt_cnt_nxt;
	end
end

assign buf_rdy_nxt = (trigger_hit & redunt_cnt == 'b1 & cfifo_full) ? 1'b1 : 
							cfifo_empty ? 1'b0 : buf_rdy;
assign cfifo_rd = buf_rdy & ~afifo_prog_full & ~cfifo_empty & ~|fps_cnt;
assign fps_cnt_nxt = ((sample_en & ~sample_en_1T) | (~buf_rdy & buf_rdy_1T)) ? `FPS_MAX :
                     |fps_cnt ? fps_cnt - 1'b1 : fps_cnt;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst) begin
		buf_rdy <= `D 1'b0;
		buf_rdy_1T <= `D 1'b0;
		cfifo_rd_1T <= `D 1'b0;
		fps_cnt <= `D 'b0;
	end else begin
		buf_rdy <= `D buf_rdy_nxt;
		buf_rdy_1T <= `D buf_rdy;
		cfifo_rd_1T <= `D cfifo_rd;
		fps_cnt <= `D fps_cnt_nxt;
	end
end

reg	[`DP_MAXBIT:0]	cfifo_rd_cnt;
wire	[`DP_MAXBIT:0]	cfifo_rd_cnt_nxt;
assign cfifo_rd_cnt_nxt = cfifo_rd ? cfifo_rd_cnt + 1'b1 :
                          cfifo_full ? 'b0 : cfifo_rd_cnt;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		cfifo_rd_cnt <= `D 'b0;
	else
		cfifo_rd_cnt <= `D cfifo_rd_cnt_nxt;
end

// --
// continous buffer
// --
always @(posedge core_clk)
begin
	sample_en_1T <= `D sample_en;
end	
assign div_cnt_nxt = (sample_en & ~sample_en_1T) ? 23'b0 :
							(capture_valid & (div_cnt == dso_sampleDivider)) ? 23'b0 :
							buf_rdy ? 23'b0 :
                     (capture_valid & ~buf_rdy) ? div_cnt + 1'b1 : div_cnt;
assign capture_wr_nxt = capture_valid & (div_cnt == dso_sampleDivider);							
assign cfifo_wr_nxt = capture_wr_nxt & ~buf_rdy;
assign cfifo_wr_cnt_nxt = (~buf_rdy & buf_rdy_1T) ? 'b0 : 
                          (cfifo_wr & ~&cfifo_wr_cnt) ? cfifo_wr_cnt + 1'b1 : cfifo_wr_cnt;
assign cfifo_din_nxt = capture_data_1T;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst) begin
		div_cnt <= `D 24'b0;
		capture_wr <= `D 1'b0;
		cfifo_wr <= `D 1'b0;
		cfifo_wr_cnt <= `D 'b0;
		cfifo_din <= `D 16'b0;
	end else begin
		div_cnt <= `D div_cnt_nxt;
		capture_wr <= `D capture_wr_nxt;
		cfifo_wr <= `D cfifo_wr_nxt;
		cfifo_wr_cnt <= `D cfifo_wr_cnt_nxt;
		cfifo_din <= `D cfifo_din_nxt;
	end
end
cfifo cfifo (
  .clk(core_clk), // input clk
  .rst(core_rst), // input rst
  .din(cfifo_din), // input [15 : 0] din
  .wr_en(cfifo_wr), // input wr_en
  .rd_en(redunt_rd | cfifo_rd), // input rd_en
  .dout(cfifo_dout), // output [15 : 0] dout
  .full(cfifo_full), // output full
  .empty(cfifo_empty), // output empty
  .prog_full(cfifo_almost_full),
  .data_count(cfifo_cnt)
);

// --
// core --> sdram domain
// --
wire	afifo_empty;
wire	afifo_full;
wire	afifo_prog_empty;
wire	afifo_prog_full;
asyncfifo asyncfifo(
  .wr_clk(core_clk),	// input wr_clk
  .wr_rst(core_rst),	// input wr_rst
  .rd_clk(sdram_clk),	// input rd_clk
  .rd_rst(sd_rst),	// input rd_rst
  .din(cfifo_dout),	// input [15 : 0] din
  .wr_en(cfifo_rd_1T),	// input wr_en
  .rd_en(rd_req & ~afifo_empty),	// input rd_en
  .dout(buf_rd_data),	// output [15 : 0] dout
  .full(afifo_full),		// output full
  .empty(afifo_empty),	// output empty
  .prog_full(afifo_prog_full),  // output prog_full
  .prog_empty(afifo_prog_empty) // output prog_empty
);

always @(posedge sdram_clk or posedge sd_rst)
begin
	if (sd_rst) begin
		buf_rd_valid <= `D 1'b0;
		buf_rd_rdy <= `D 1'b0;
	end else begin
		buf_rd_valid <= `D rd_req & ~afifo_empty;
		buf_rd_rdy <= `D rd_req & ~afifo_empty;
	end
end

reg	read_rdy;
wire	read_rdy_nxt;
reg	read_rdy_1T;
assign read_rdy_nxt = afifo_prog_full ? 1'b1 : read_rdy;
always @(posedge sdram_clk or posedge sd_rst)
begin
	if (sd_rst) begin
		read_rdy <= `D 1'b0;
		read_rdy_1T <= `D 1'b0;
	end else begin
		read_rdy <= `D read_rdy_nxt;
		read_rdy_1T <= `D read_rdy;
	end
end
assign read_start = ~cons_mode ? wr_done : (read_rdy & ~read_rdy_1T);

endmodule /* module cons_buf (*/
