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

module capture(
	// -- clock & reset
	input	core_clk,
	input	core_rst,

	// -- sample configuration
	input		cons_mode,
	input		wireless_mode,
	input		dso_setZero,
	input		sample_en,
	input				full_speed,
	input	[31:0]	sample_depth,
	input	[31:0]	sample_last_cnt,
	input	[31:0]	sample_real_start,
	input	[31:0]	trig_set_pos,
	input	[31:0]	trig_set_pos_minus1,
	input	[31:0]	after_trig_depth,
	
	// -- sample data in
	input		sample_valid,
	input	[15:0]	sample_data,

	// -- trigger control in
	input		trig_en,
	input		trig_hit,
	input	[3:0]	trig_dly,

	// -- capture control output
	output	reg		dso_setZero_done,
	output	reg	[31:0]	trig_real_pos,
	output	reg		capture_done,
	output	reg	[31:0]	sd_saddr,
	output					capture_valid,
	output		[15:0]	capture_data
);
// --
// internal singals definition
// --
reg				capture_cnt_valid = 1'b0;
wire				caputre_cnt_valid_nxt;
reg	[31:0]	capture_cnt;
wire	[31:0]	capture_cnt_nxt;

wire		trig_hit_pulse;
reg		trig_hit_dly;
wire		trig_hit_dly_nxt;
wire		capture_done_nxt;
reg	[32:0]	trig_real_start;
wire	[32:0]	trig_real_start_nxt;
wire	[32:0]	sd_saddr_nxt;

reg	loop0;
wire	loop0_nxt;

wire	[15:0]	capture_data_pre;
reg				capture_valid_pre;
wire				capture_valid_pre_nxt;

// --
// capture_cnt record the count(mod sample_depth) before trig_hit
// --
assign trig_hit_pulse = trig_hit & capture_valid_pre & ~trig_hit_dly;
assign trig_hit_dly_nxt = capture_done ? 1'b0 :
								  trig_hit & capture_valid_pre ? 1'b1 : trig_hit_dly;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		trig_hit_dly <= `D 1'b0;
	else
		trig_hit_dly <= `D trig_hit_dly_nxt;
end

assign capture_cnt_valid_nxt = capture_done ? 1'b0 : 
										 capture_valid_pre_nxt ? 1'b1 : capture_cnt_valid;
always @(posedge core_clk)
begin
	capture_cnt_valid <= `D capture_cnt_valid_nxt;
end										 
assign capture_cnt_nxt = capture_done ? 32'b0 :
			(capture_valid_pre & (capture_cnt == sample_last_cnt)) ? 32'b0 :
			(trig_en & ~full_speed & capture_valid_pre & loop0 & trig_hit & (capture_cnt >= trig_set_pos)) ? 32'b0 :
			(trig_en & full_speed & capture_valid_pre & loop0 & trig_hit & (capture_cnt >= trig_set_pos_minus1)) ? 32'b0 :
			(trig_en & capture_valid_pre & ~loop0 & trig_hit_pulse) ? 32'b0 :
			(capture_valid_pre) ? capture_cnt + 1'b1 : capture_cnt;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		capture_cnt <= `D 32'b0;
	else
		capture_cnt <= `D capture_cnt_nxt;
end

// --
// trigger position
// --
reg	sample_en_1T = 1'b0;
reg	trig_hit_1T = 1'b0;
reg	set_before_real;
wire	set_before_real_nxt;
reg	trig_real_hit;
wire	trig_real_hit_nxt;
always @(posedge core_clk)
begin
	sample_en_1T <= `D sample_en;
	trig_hit_1T <= `D trig_hit;
end
assign set_before_real_nxt = capture_done ? 1'b0 :
		   (trig_real_hit & loop0 & capture_cnt < trig_set_pos) ? 1'b1 : set_before_real;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		set_before_real <= `D 1'b0;
	else
		set_before_real <= `D set_before_real_nxt;
end

assign trig_real_hit_nxt = trig_hit ? 1'b1 : 
							 capture_valid_pre ? 1'b0 : trig_real_hit;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		trig_real_hit <= 	`D 1'b0;
	else
		trig_real_hit <= `D trig_real_hit_nxt;
end
assign trig_real_start_nxt = (sample_en & ~sample_en_1T) ? sample_real_start :
									  (~trig_real_hit & capture_valid_pre & trig_real_start == sample_last_cnt) ? 32'b0 : 
									  (~trig_real_hit & capture_valid_pre) ? trig_real_start + 1'b1 : trig_real_start;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		trig_real_start <= `D 32'b0;
	else
		trig_real_start <= `D trig_real_start_nxt;
end									  
assign sd_saddr_nxt = (capture_done & (set_before_real | ~trig_en)) ? 32'b0 : 
							 capture_done ? {trig_real_start[29:0], 2'b0} : sd_saddr;
always @(posedge core_clk or posedge core_rst)
begin
    if (core_rst)
	     sd_saddr <= `D 32'b0;
    else
        sd_saddr <= `D sd_saddr_nxt;
end																										 
wire	[31:0]	trig_real_pos_nxt;
reg				trig_after;
wire				trig_after_nxt;
assign trig_after_nxt = trig_hit ? 1'b1 : 
							 capture_valid_pre ? 1'b0 : trig_after;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		trig_after <= 	`D 1'b0;
	else
		trig_after <= `D trig_after_nxt;
end
assign trig_real_pos_nxt = ~trig_en? 32'b0 :
									(capture_valid_pre & ~trig_after & trig_real_pos < trig_set_pos) ? trig_real_pos + 1'b1 : trig_real_pos;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		trig_real_pos <= 	`D 32'b0;
	else
		trig_real_pos <= `D trig_real_pos_nxt;
end

// --
// capture_done
// --
assign loop0_nxt = capture_done ? 1'b1 :
		   (~full_speed & capture_valid_pre & capture_cnt >= trig_set_pos) ? 1'b0 : 
			(full_speed & capture_valid_pre & capture_cnt >= trig_set_pos_minus1) ? 1'b0 : loop0;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		loop0 <= `D 1'b1;
	else
		loop0 <= `D loop0_nxt;
end

assign capture_done_nxt = capture_done ? 1'b0 :
			 (~cons_mode & trig_hit & trig_en & capture_cnt_valid & (capture_cnt == after_trig_depth)) ? 1'b1 :
			 (~cons_mode & trig_hit & ~trig_en & capture_valid_pre & (capture_cnt == sample_last_cnt)) ? 1'b1 : capture_done;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		capture_done <= `D 1'b0;
	else
		capture_done <= `D capture_done_nxt;
end

// --
// sample_data delay for trigger
// --
// -- fix delay 3T for trigger module delay
wire	[15:0]	sample_data_fix_dly;
wire				sample_valid_fix_dly;
SRL16E sv_fix(.A0(1'b1), .A1(1'b1), .A2(1'b0), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_valid), .Q(sample_valid_fix_dly));
SRL16E s0_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[0]), .Q(sample_data_fix_dly[0]));
SRL16E s1_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[1]), .Q(sample_data_fix_dly[1]));
SRL16E s2_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[2]), .Q(sample_data_fix_dly[2]));
SRL16E s3_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[3]), .Q(sample_data_fix_dly[3]));
SRL16E s4_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[4]), .Q(sample_data_fix_dly[4]));
SRL16E s5_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[5]), .Q(sample_data_fix_dly[5]));
SRL16E s6_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[6]), .Q(sample_data_fix_dly[6]));
SRL16E s7_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[7]), .Q(sample_data_fix_dly[7]));
SRL16E s8_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[8]), .Q(sample_data_fix_dly[8]));
SRL16E s9_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[9]), .Q(sample_data_fix_dly[9]));
SRL16E sa_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[10]), .Q(sample_data_fix_dly[10]));
SRL16E sb_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[11]), .Q(sample_data_fix_dly[11]));
SRL16E sc_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[12]), .Q(sample_data_fix_dly[12]));
SRL16E sd_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[13]), .Q(sample_data_fix_dly[13]));
SRL16E se_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[14]), .Q(sample_data_fix_dly[14]));
SRL16E sf_fix(.A0(1'b0), .A1(1'b0), .A2(1'b1), .A3(1'b0), .CLK(core_clk), .CE(1'b1), .D(sample_data[15]), .Q(sample_data_fix_dly[15]));



wire	sample_valid_dly;
SRL16E sv(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_valid_fix_dly), .Q(sample_valid_dly));

assign capture_valid_pre_nxt = capture_done_nxt ? 1'b0 : 
			   sample_en & ~capture_done? sample_valid_dly : 1'b0;
always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst)
		capture_valid_pre <= `D 1'b0;
	else
		capture_valid_pre <= `D capture_valid_pre_nxt;
end

SRL16E s0(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[0]), .Q(capture_data_pre[0]));
SRL16E s1(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[1]), .Q(capture_data_pre[1]));
SRL16E s2(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[2]), .Q(capture_data_pre[2]));
SRL16E s3(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[3]), .Q(capture_data_pre[3]));
SRL16E s4(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[4]), .Q(capture_data_pre[4]));
SRL16E s5(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[5]), .Q(capture_data_pre[5]));
SRL16E s6(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[6]), .Q(capture_data_pre[6]));
SRL16E s7(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[7]), .Q(capture_data_pre[7]));
SRL16E s8(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[8]), .Q(capture_data_pre[8]));
SRL16E s9(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[9]), .Q(capture_data_pre[9]));
SRL16E sa(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[10]), .Q(capture_data_pre[10]));
SRL16E sb(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[11]), .Q(capture_data_pre[11]));
SRL16E sc(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[12]), .Q(capture_data_pre[12]));
SRL16E sd(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[13]), .Q(capture_data_pre[13]));
SRL16E se(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[14]), .Q(capture_data_pre[14]));
SRL16E sf(.A0(trig_dly[0]), .A1(trig_dly[1]), .A2(trig_dly[2]), .A3(trig_dly[3]), .CLK(core_clk), .CE(1'b1), .D(sample_data_fix_dly[15]), .Q(capture_data_pre[15]));

// -- data zero adjustemnt in DSO mode
reg			dso_zero = 1'b0;
wire			dso_zero_nxt;
wire			dso_setZero_done_nxt;
reg	[15:0]	dso_zero_cnt = 16'b0;
wire	[15:0]	dso_zero_cnt_nxt;
reg	[7:0]	ch0_offset = 8'h0;
reg	[7:0]	ch1_offset = 8'h0;
wire	[7:0]	ch0_offset_nxt;
wire	[7:0]	ch1_offset_nxt;
reg			ch0_sign = 1'b0;
reg			ch1_sign = 1'b0;
wire			ch0_sign_nxt;
wire			ch1_sign_nxt;
reg	[15:0]	capture_data_fix;
wire	[15:0]	capture_data_fix_nxt;
reg	[15:0]	capture_data_zero;
wire	[15:0]	capture_data_zero_nxt;
reg			capture_valid_pre_1T;
reg			capture_valid_pre_2T;
wire			capture_valid_zero;
reg			zero_capture;
wire			zero_capture_nxt;

assign dso_zero_nxt = dso_setZero ? 1'b1 : 
                      dso_setZero_done_nxt ? 1'b0 : dso_zero;
assign dso_zero_cnt_nxt = dso_setZero ? 16'b0 : 
                          (dso_zero & capture_valid_pre) ? dso_zero_cnt + 1'b1 : dso_zero_cnt;
assign dso_setZero_done_nxt = dso_setZero_done ? 1'b0 :
                              (dso_zero & &dso_zero_cnt) ? 1'b1 : dso_setZero_done;
assign capture_data_fix_nxt = capture_valid_pre ? 16'hffff - capture_data_pre : capture_data_fix;
assign capture_data_zero_nxt[7:0] = (ch0_sign & (capture_data_fix[7:0] > ch0_offset))? capture_data_fix[7:0] - ch0_offset : capture_data_fix[7:0] + ch0_offset;
assign capture_data_zero_nxt[15:8] = (ch1_sign & (capture_data_fix[15:8] > ch1_offset))? capture_data_fix[15:8] - ch1_offset : capture_data_fix[15:8] + ch1_offset;
assign ch0_sign_nxt = dso_zero ? ((capture_data_fix[7:0] > 8'h80) ? 1'b1 : 1'b0) : ch0_sign;
assign ch1_sign_nxt = dso_zero ? ((capture_data_fix[15:8] > 8'h80) ? 1'b1 : 1'b0) : ch1_sign;
assign ch0_offset_nxt = (dso_zero & dso_zero_cnt[15] & ch0_sign) ? (capture_data_fix[7:0] - 8'h80 + ch0_offset) >> 1 :
							   (dso_zero & dso_zero_cnt[15] & ~ch0_sign) ? (8'h80 - capture_data_fix[7:0] + ch0_offset) >> 1 : ch0_offset;
assign ch1_offset_nxt = (dso_zero & dso_zero_cnt[15] & ch1_sign) ? (capture_data_fix[15:8] - 8'h80 + ch1_offset) >> 1 :
							   (dso_zero & dso_zero_cnt[15] & ~ch1_sign) ? (8'h80 - capture_data_fix[15:8] + ch1_offset) >> 1 : ch1_offset;
assign zero_capture_nxt = dso_setZero ? 1'b1 : 
                          (capture_valid_pre_2T & ~capture_valid_pre_1T) ? 1'b0 : zero_capture;
always @(posedge core_clk)
begin
		dso_zero <= `D dso_zero_nxt;
		dso_zero_cnt <= `D dso_zero_cnt_nxt;
		dso_setZero_done <= `D dso_setZero_done_nxt;
end
always @(posedge core_clk)
begin
		capture_valid_pre_1T <= `D capture_valid_pre;
		capture_valid_pre_2T <= `D capture_valid_pre_1T;
		capture_data_fix <= `D capture_data_fix_nxt;
		capture_data_zero <= `D capture_data_zero_nxt;
		ch0_sign <= `D ch0_sign_nxt;
		ch1_sign <= `D ch1_sign_nxt;
		ch0_offset <= `D ch0_offset_nxt;
		ch1_offset <= `D ch1_offset_nxt;
		zero_capture <= `D zero_capture_nxt;
end

assign capture_valid_zero = capture_valid_pre_1T & ~zero_capture;
assign capture_data = (cons_mode & !wireless_mode) ? capture_data_zero : capture_data_pre;
assign capture_valid = (cons_mode & !wireless_mode) ? capture_valid_zero : capture_valid_pre;

endmodule
