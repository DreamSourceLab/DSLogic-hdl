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

module trigger(
	// -- clock & reset
	input				core_clk,
	input				core_rst,

	// -- trigger configuration
	input				full_speed,
	input				trig_en,
	input	[3:0]		trig_stages,
	input	[1:0]		trig_mu,	
	input				trig_mask_wr,
	input				trig_value_wr,
	input				trig_edge_wr,
	input				trig_count_wr,
	input				trig_logic_wr,
	input	[15:0]	trig_mask,
	input	[15:0]	trig_value,
	input	[15:0]	trig_edge,
	input	[15:0]	trig_count,
	input	[1:0]		trig_logic,
	input				sample_en,
	
	// -- sample data in
	input				sample_valid,
	input	[15:0]	sample_data,

	// -- control
	input				capture_done,

	// -- trigger output
	output	[3:0]	trig_dly,
	output	reg	trig_hit = 1'b0
);

// --
// internal singals definition
// --
wire		trig_hit_nxt;

// --
// trigger flag setting
// --


// --
// trigger hit
// --
wire				trig_shift;
reg				sample_en_1T;
reg				sample_valid_1T = 1'b0;
reg				sample_valid_2T = 1'b0;
reg				edge_window = 1'b0;
wire				edge_window_nxt;
reg	[15:0]	cur_trig_value0 = 16'b0;
reg	[15:0]	cur_trig_value1 = 16'b0;
reg	[15:0]	cur_trig_value2 = 16'b0;
reg	[15:0]	cur_trig_value3 = 16'b0;
reg	[15:0]	cur_trig_mask0 = 16'b0;
reg	[15:0]	cur_trig_mask1 = 16'b0;
reg	[15:0]	cur_trig_mask2 = 16'b0;
reg	[15:0]	cur_trig_mask3 = 16'b0;
reg	[15:0]	cur_trig_edge0 = 16'b0;
reg	[15:0]	cur_trig_edge1 = 16'b0;
reg	[15:0]	cur_trig_edge2 = 16'b0;
reg	[15:0]	cur_trig_edge3 = 16'b0;
reg	[15:0]	cur_trig_count0 = 16'b0;
reg	[15:0]	cur_trig_count1 = 16'b0;
reg	[15:0]	cur_trig_count2 = 16'b0;
reg	[15:0]	cur_trig_count3 = 16'b0;
reg				cur_trig_and0 = 1'b1;
reg				cur_trig_and1 = 1'b1;
reg				cur_trig_and2 = 1'b1;
reg				cur_trig_and3 = 1'b1;
reg				cur_trig_inv0 = 1'b0;
reg				cur_trig_inv1 = 1'b0;
reg				cur_trig_inv2 = 1'b0;
reg				cur_trig_inv3 = 1'b0;
wire	[15:0]	cur_trig_value0_nxt;
wire	[15:0]	cur_trig_value1_nxt;
wire	[15:0]	cur_trig_value2_nxt;
wire	[15:0]	cur_trig_value3_nxt;
wire	[15:0]	cur_trig_mask0_nxt;
wire	[15:0]	cur_trig_mask1_nxt;
wire	[15:0]	cur_trig_mask2_nxt;
wire	[15:0]	cur_trig_mask3_nxt;
wire	[15:0]	cur_trig_edge0_nxt;
wire	[15:0]	cur_trig_edge1_nxt;
wire	[15:0]	cur_trig_edge2_nxt;
wire	[15:0]	cur_trig_edge3_nxt;
wire	[15:0]	cur_trig_count0_nxt;
wire	[15:0]	cur_trig_count1_nxt;
wire	[15:0]	cur_trig_count2_nxt;
wire	[15:0]	cur_trig_count3_nxt;
wire				cur_trig_and0_nxt;
wire				cur_trig_and1_nxt;
wire				cur_trig_and2_nxt;
wire				cur_trig_and3_nxt;
wire				cur_trig_inv0_nxt;
wire				cur_trig_inv1_nxt;
wire				cur_trig_inv2_nxt;
wire				cur_trig_inv3_nxt;

reg				cur_trig_count0_eq0 = 1'b0;
reg				cur_trig_count1_eq0 = 1'b0;
reg				cur_trig_count2_eq0 = 1'b0;
reg				cur_trig_count3_eq0 = 1'b0;
wire				cur_trig_count0_eq0_nxt;
wire				cur_trig_count1_eq0_nxt;
wire				cur_trig_count2_eq0_nxt;
wire				cur_trig_count3_eq0_nxt;

reg	mu0_match = 1'b0;
reg	mu1_match = 1'b0;
reg	mu2_match = 1'b0;
reg	mu3_match = 1'b0;
wire	mu0_match_nxt;
wire	mu1_match_nxt;
wire	mu2_match_nxt;
wire	mu3_match_nxt;
wire	mu0_match_count;
wire	mu1_match_count;
wire	mu2_match_count;
wire	mu3_match_count;
reg	mu_all_match = 1'b0;
wire	mu_all_match_nxt;

reg	[3:0]	match_stages = 4'b0;
wire	[3:0]	match_stages_nxt;
reg			match_stages_valid = 1'b0;
wire			match_stages_valid_nxt;

reg	[3:0]		data_delay = 4'b0;
wire	[3:0]		data_delay_nxt;
wire	[15:0]	data_shift;
reg	[15:0]	cur_cmp_data = 16'b0;
wire	[15:0]	cur_cmp_data_nxt;
reg				cur_cmp_valid = 1'b0;
reg	[15:0]	pre_cmp_data = 16'b0;
wire	[15:0]	pre_cmp_data_nxt;
wire	[15:0]	cur_edge;

wire	[15:0]	mu0mk_out;
wire	[15:0]	mu1mk_out;
wire	[15:0]	mu2mk_out;
wire	[15:0]	mu3mk_out;
wire	[15:0]	mu0_out;
wire	[15:0]	mu1_out;
wire	[15:0]	mu2_out;
wire	[15:0]	mu3_out;
wire	[15:0]	mu0eg_out;
wire	[15:0]	mu1eg_out;
wire	[15:0]	mu2eg_out;
wire	[15:0]	mu3eg_out;
wire	[15:0]	mu0ct_out;
wire	[15:0]	mu1ct_out;
wire	[15:0]	mu2ct_out;
wire	[15:0]	mu3ct_out;
wire	[1:0]	mu0lg_out;
wire	[1:0]	mu1lg_out;
wire	[1:0]	mu2lg_out;
wire	[1:0]	mu3lg_out;
wire mu0mk_shift = (trig_mask_wr & trig_mu == 2'b00) | trig_shift;
wire mu1mk_shift = (trig_mask_wr & trig_mu == 2'b01) | trig_shift;
wire mu2mk_shift = (trig_mask_wr & trig_mu == 2'b10) | trig_shift;
wire mu3mk_shift = (trig_mask_wr & trig_mu == 2'b11) | trig_shift;
wire [15:0]	mu0mk_in = trig_shift ? mu0mk_out : trig_mask;
wire [15:0]	mu1mk_in = trig_shift ? mu1mk_out : trig_mask;
wire [15:0]	mu2mk_in = trig_shift ? mu2mk_out : trig_mask;
wire [15:0]	mu3mk_in = trig_shift ? mu3mk_out : trig_mask;
wire mu0_shift = (trig_value_wr & trig_mu == 2'b00) | trig_shift;
wire mu1_shift = (trig_value_wr & trig_mu == 2'b01) | trig_shift;
wire mu2_shift = (trig_value_wr & trig_mu == 2'b10) | trig_shift;
wire mu3_shift = (trig_value_wr & trig_mu == 2'b11) | trig_shift;
wire [15:0]	mu0_in = trig_shift ? mu0_out : trig_value;
wire [15:0]	mu1_in = trig_shift ? mu1_out : trig_value;
wire [15:0]	mu2_in = trig_shift ? mu2_out : trig_value;
wire [15:0]	mu3_in = trig_shift ? mu3_out : trig_value;
wire mu0eg_shift = (trig_edge_wr & trig_mu == 2'b00) | trig_shift;
wire mu1eg_shift = (trig_edge_wr & trig_mu == 2'b01) | trig_shift;
wire mu2eg_shift = (trig_edge_wr & trig_mu == 2'b10) | trig_shift;
wire mu3eg_shift = (trig_edge_wr & trig_mu == 2'b11) | trig_shift;
wire [15:0]	mu0eg_in = trig_shift ? mu0eg_out : trig_edge;
wire [15:0]	mu1eg_in = trig_shift ? mu1eg_out : trig_edge;
wire [15:0]	mu2eg_in = trig_shift ? mu2eg_out : trig_edge;
wire [15:0]	mu3eg_in = trig_shift ? mu3eg_out : trig_edge;
wire mu0ct_shift = (trig_count_wr & trig_mu == 2'b00) | trig_shift;
wire mu1ct_shift = (trig_count_wr & trig_mu == 2'b01) | trig_shift;
wire mu2ct_shift = (trig_count_wr & trig_mu == 2'b10) | trig_shift;
wire mu3ct_shift = (trig_count_wr & trig_mu == 2'b11) | trig_shift;
wire [15:0]	mu0ct_in = trig_shift ? mu0ct_out : trig_count;
wire [15:0]	mu1ct_in = trig_shift ? mu1ct_out : trig_count;
wire [15:0]	mu2ct_in = trig_shift ? mu2ct_out : trig_count;
wire [15:0]	mu3ct_in = trig_shift ? mu3ct_out : trig_count;
wire mu0lg_shift = (trig_logic_wr & trig_mu == 2'b00) | trig_shift;
wire mu1lg_shift = (trig_logic_wr & trig_mu == 2'b01) | trig_shift;
wire mu2lg_shift = (trig_logic_wr & trig_mu == 2'b10) | trig_shift;
wire mu3lg_shift = (trig_logic_wr & trig_mu == 2'b11) | trig_shift;
wire [1:0]	mu0lg_in = trig_shift ? mu0lg_out : trig_logic;
wire [1:0]	mu1lg_in = trig_shift ? mu1lg_out : trig_logic;
wire [1:0]	mu2lg_in = trig_shift ? mu2lg_out : trig_logic;
wire [1:0]	mu3lg_in = trig_shift ? mu3lg_out : trig_logic;


assign trig_shift = (sample_en & ~sample_en_1T) | (sample_en & mu_all_match & ~trig_hit);
always @(posedge core_clk)
begin
	sample_en_1T <= `D sample_en;
end
assign cur_trig_value0_nxt = (trig_shift) ? mu0_out : cur_trig_value0;
assign cur_trig_value1_nxt = (trig_shift) ? mu1_out : cur_trig_value1;
assign cur_trig_value2_nxt = (trig_shift) ? mu2_out : cur_trig_value2;
assign cur_trig_value3_nxt = (trig_shift) ? mu3_out : cur_trig_value3;
assign cur_trig_mask0_nxt = (trig_shift) ? mu0mk_out : cur_trig_mask0;
assign cur_trig_mask1_nxt = (trig_shift) ? mu1mk_out : cur_trig_mask1;
assign cur_trig_mask2_nxt = (trig_shift) ? mu2mk_out : cur_trig_mask2;
assign cur_trig_mask3_nxt = (trig_shift) ? mu3mk_out : cur_trig_mask3;
assign cur_trig_edge0_nxt = (trig_shift) ? mu0eg_out : cur_trig_edge0;
assign cur_trig_edge1_nxt = (trig_shift) ? mu1eg_out : cur_trig_edge1;
assign cur_trig_edge2_nxt = (trig_shift) ? mu2eg_out : cur_trig_edge2;
assign cur_trig_edge3_nxt = (trig_shift) ? mu3eg_out : cur_trig_edge3;
assign cur_trig_count0_nxt = (trig_shift) ? mu0ct_out : 
									  (mu0_match & cur_trig_count0 != 'b0) ? cur_trig_count0 - 1'b1 : cur_trig_count0;
assign cur_trig_count1_nxt = (trig_shift) ? mu1ct_out : 
									  (mu1_match & cur_trig_count1 != 'b0) ? cur_trig_count1 - 1'b1 : cur_trig_count1;
assign cur_trig_count2_nxt = (trig_shift) ? mu2ct_out : 
									  (mu2_match & cur_trig_count2 != 'b0) ? cur_trig_count2 - 1'b1 : cur_trig_count2;
assign cur_trig_count3_nxt = (trig_shift) ? mu3ct_out :
									  (mu3_match & cur_trig_count3 != 'b0) ? cur_trig_count3 - 1'b1 : cur_trig_count3;
assign cur_trig_count0_eq0_nxt = (cur_trig_count0_nxt == 'b0);
assign cur_trig_count1_eq0_nxt = (cur_trig_count1_nxt == 'b0);
assign cur_trig_count2_eq0_nxt = (cur_trig_count2_nxt == 'b0);
assign cur_trig_count3_eq0_nxt = (cur_trig_count3_nxt == 'b0);
assign cur_trig_and0_nxt = (trig_shift) ? mu0lg_out[1] : cur_trig_and0;
assign cur_trig_and1_nxt = (trig_shift) ? mu1lg_out[1] : cur_trig_and1;
assign cur_trig_and2_nxt = (trig_shift) ? mu2lg_out[1] : cur_trig_and2;
assign cur_trig_and3_nxt = (trig_shift) ? mu3lg_out[1] : cur_trig_and3;
assign cur_trig_inv0_nxt = (trig_shift) ? mu0lg_out[0] : cur_trig_inv0;
assign cur_trig_inv1_nxt = (trig_shift) ? mu1lg_out[0] : cur_trig_inv1;
assign cur_trig_inv2_nxt = (trig_shift) ? mu2lg_out[0] : cur_trig_inv2;
assign cur_trig_inv3_nxt = (trig_shift) ? mu3lg_out[0] : cur_trig_inv3;
always @(posedge core_clk)
begin
	if (trig_en) begin
		cur_trig_value0 <= `D cur_trig_value0_nxt;
		cur_trig_value1 <= `D cur_trig_value1_nxt;
		cur_trig_value2 <= `D cur_trig_value2_nxt;
		cur_trig_value3 <= `D cur_trig_value3_nxt;
		cur_trig_mask0 <= `D cur_trig_mask0_nxt;
		cur_trig_mask1 <= `D cur_trig_mask1_nxt;
		cur_trig_mask2 <= `D cur_trig_mask2_nxt;
		cur_trig_mask3 <= `D cur_trig_mask3_nxt;
		cur_trig_edge0 <= `D cur_trig_edge0_nxt;
		cur_trig_edge1 <= `D cur_trig_edge1_nxt;
		cur_trig_edge2 <= `D cur_trig_edge2_nxt;
		cur_trig_edge3 <= `D cur_trig_edge3_nxt;
		cur_trig_count0 <= `D cur_trig_count0_nxt;
		cur_trig_count1 <= `D cur_trig_count1_nxt;
		cur_trig_count2 <= `D cur_trig_count2_nxt;
		cur_trig_count3 <= `D cur_trig_count3_nxt;
		cur_trig_count0_eq0 <= `D cur_trig_count0_eq0_nxt;
		cur_trig_count1_eq0 <= `D cur_trig_count1_eq0_nxt;
		cur_trig_count2_eq0 <= `D cur_trig_count2_eq0_nxt;
		cur_trig_count3_eq0 <= `D cur_trig_count3_eq0_nxt;
		cur_trig_and0 <= `D cur_trig_and0_nxt;
		cur_trig_and1 <= `D cur_trig_and1_nxt;
		cur_trig_and2 <= `D cur_trig_and2_nxt;
		cur_trig_and3 <= `D cur_trig_and3_nxt;
		cur_trig_inv0 <= `D cur_trig_inv0_nxt;
		cur_trig_inv1 <= `D cur_trig_inv1_nxt;
		cur_trig_inv2 <= `D cur_trig_inv2_nxt;
		cur_trig_inv3 <= `D cur_trig_inv3_nxt;
	end
end

assign   cur_edge = {16{edge_window}} & (cur_cmp_data ^ pre_cmp_data);
//assign	mu0_match_nxt = cur_trig_inv0 ^ (~|(((cur_cmp_data ^ cur_trig_value0) | (cur_trig_edge0 & ~cur_edge)) & ~cur_trig_mask0) & cur_cmp_valid);
//assign	mu1_match_nxt = cur_trig_inv1 ^ (~|(((cur_cmp_data ^ cur_trig_value1) | (cur_trig_edge1 & ~cur_edge)) & ~cur_trig_mask1) & cur_cmp_valid);
//assign	mu2_match_nxt = cur_trig_inv2 ^ (~|(((cur_cmp_data ^ cur_trig_value2) | (cur_trig_edge2 & ~cur_edge)) & ~cur_trig_mask2) & cur_cmp_valid);
//assign	mu3_match_nxt = cur_trig_inv3 ^ (~|(((cur_cmp_data ^ cur_trig_value3) | (cur_trig_edge3 & ~cur_edge)) & ~cur_trig_mask3) & cur_cmp_valid);
assign	mu0_match_nxt = cur_trig_inv0 ^ (~|(((cur_cmp_data ^ cur_trig_value0) & ~cur_trig_mask0) | (cur_trig_edge0 & ~cur_edge)) & cur_cmp_valid);
assign	mu1_match_nxt = cur_trig_inv1 ^ (~|(((cur_cmp_data ^ cur_trig_value1) & ~cur_trig_mask1) | (cur_trig_edge1 & ~cur_edge)) & cur_cmp_valid);
assign	mu2_match_nxt = cur_trig_inv2 ^ (~|(((cur_cmp_data ^ cur_trig_value2) & ~cur_trig_mask2) | (cur_trig_edge2 & ~cur_edge)) & cur_cmp_valid);
assign	mu3_match_nxt = cur_trig_inv3 ^ (~|(((cur_cmp_data ^ cur_trig_value3) & ~cur_trig_mask3) | (cur_trig_edge3 & ~cur_edge)) & cur_cmp_valid);
//assign	mu0_match_nxt = cur_trig_inv0 ^ (~|(((cur_cmp_data ^ cur_trig_value0)) & ~cur_trig_mask0) & cur_cmp_valid);
//assign	mu1_match_nxt = cur_trig_inv1 ^ (~|(((cur_cmp_data ^ cur_trig_value1)) & ~cur_trig_mask1) & cur_cmp_valid);
//assign	mu2_match_nxt = cur_trig_inv2 ^ (~|(((cur_cmp_data ^ cur_trig_value2)) & ~cur_trig_mask2) & cur_cmp_valid);
//assign	mu3_match_nxt = cur_trig_inv3 ^ (~|(((cur_cmp_data ^ cur_trig_value3)) & ~cur_trig_mask3) & cur_cmp_valid);

always @(posedge core_clk)
begin
    mu0_match <= `D mu0_match_nxt;
    mu1_match <= `D mu1_match_nxt;
    mu2_match <= `D mu2_match_nxt;
    mu3_match <= `D mu3_match_nxt;
end
assign mu0_match_count = mu0_match_nxt  & (cur_trig_count0 == 'b0);
assign mu1_match_count = mu1_match_nxt  & (cur_trig_count1 == 'b0);
assign mu2_match_count = mu2_match_nxt  & (cur_trig_count2 == 'b0);
assign mu3_match_count = mu3_match_nxt  & (cur_trig_count3 == 'b0);
//assign mu_all_match_nxt = cur_trig_and0 ? (mu0_match_count & mu1_match_count & mu2_match_count & mu3_match_count) :
//											       (mu0_match_count | mu1_match_count | mu2_match_count | mu3_match_count);
assign mu_all_match_nxt = cur_trig_and0 ? (mu0_match_count & mu1_match_count) :
											       (mu0_match_count | mu1_match_count);
//assign mu_all_match_nxt = cur_trig_and0 ? (mu0_match_nxt & mu1_match_nxt & mu2_match_nxt & mu3_match_nxt) :
//											       (mu0_match_nxt | mu1_match_nxt | mu2_match_nxt | mu3_match_nxt);
													 
always @(posedge core_clk)
begin
    mu_all_match <= `D mu_all_match_nxt;
end

assign data_delay_nxt = (sample_en & ~sample_en_1T) ? 4'b0 :
								(full_speed & mu_all_match_nxt) ? data_delay + 1'b1 : data_delay;
always @(posedge core_clk)
begin
    data_delay <= `D data_delay_nxt;
end

assign match_stages_valid_nxt = (~sample_en & sample_en_1T) ? 1'b0 :
								  mu_all_match & sample_en ? 1'b1 : match_stages_valid;
assign match_stages_nxt = (sample_en & ~sample_en_1T) ? 4'b0 :
								  (mu_all_match & match_stages_valid) ? match_stages + 1'b1 : match_stages;
always @(posedge core_clk)
begin
	match_stages_valid <= `D match_stages_valid_nxt;
	match_stages <= `D match_stages_nxt;
end
assign trig_hit_nxt = (~sample_en & sample_en_1T) ? 1'b0 :
							 (sample_en & ~sample_en_1T & ~trig_en) ? 1'b1 :
							 (sample_en & match_stages_valid & (match_stages == trig_stages)) ? 1'b1 : trig_hit;
always @(posedge core_clk)
begin
		trig_hit <= `D trig_hit_nxt;
end

// --
// trigger delay clock count
// --
assign trig_dly = full_speed ? trig_stages : 4'b0;

// --
// data shift
// --
assign cur_cmp_data_nxt = sample_valid_1T ? data_shift : cur_cmp_data;
assign pre_cmp_data_nxt = (sample_valid_2T & ~(full_speed & mu_all_match))? cur_cmp_data : pre_cmp_data;
assign edge_window_nxt = (sample_en & ~sample_en_1T) ? 1'b0 :
                         sample_valid_2T ? 1'b1 : edge_window;
                         
always @(posedge core_clk)
begin
    sample_valid_1T <= `D sample_valid;
	 sample_valid_2T <= `D sample_valid_1T;
	 edge_window <= `D edge_window_nxt;
    cur_cmp_valid <= `D sample_valid_1T;
    cur_cmp_data <= `D cur_cmp_data_nxt;
	 pre_cmp_data <= `D pre_cmp_data_nxt;
end
SRL16E data00(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[0]), .Q(data_shift[0]));
SRL16E data01(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[1]), .Q(data_shift[1]));
SRL16E data02(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[2]), .Q(data_shift[2]));
SRL16E data03(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[3]), .Q(data_shift[3]));
SRL16E data04(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[4]), .Q(data_shift[4]));
SRL16E data05(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[5]), .Q(data_shift[5]));
SRL16E data06(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[6]), .Q(data_shift[6]));
SRL16E data07(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[7]), .Q(data_shift[7]));
SRL16E data08(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[8]), .Q(data_shift[8]));
SRL16E data09(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[9]), .Q(data_shift[9]));
SRL16E data10(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[10]), .Q(data_shift[10]));
SRL16E data11(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[11]), .Q(data_shift[11]));
SRL16E data12(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[12]), .Q(data_shift[12]));
SRL16E data13(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[13]), .Q(data_shift[13]));
SRL16E data14(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[14]), .Q(data_shift[14]));
SRL16E data15(.A0(data_delay[0]), .A1(data_delay[1]), .A2(data_delay[2]), .A3(data_delay[3]), .CLK(core_clk), .CE(sample_valid), .D(sample_data[15]), .Q(data_shift[15]));

// --
// Match Units 16stages*4sets
// --
// -- Match Unit 0 
SRL16E mu0mk00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[0]), .Q(mu0mk_out[0]));
SRL16E mu0mk01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[1]), .Q(mu0mk_out[1]));
SRL16E mu0mk02(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[2]), .Q(mu0mk_out[2]));
SRL16E mu0mk03(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[3]), .Q(mu0mk_out[3]));
SRL16E mu0mk04(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[4]), .Q(mu0mk_out[4]));
SRL16E mu0mk05(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[5]), .Q(mu0mk_out[5]));
SRL16E mu0mk06(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[6]), .Q(mu0mk_out[6]));
SRL16E mu0mk07(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[7]), .Q(mu0mk_out[7]));
SRL16E mu0mk08(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[8]), .Q(mu0mk_out[8]));
SRL16E mu0mk09(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[9]), .Q(mu0mk_out[9]));
SRL16E mu0mk10(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[10]), .Q(mu0mk_out[10]));
SRL16E mu0mk11(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[11]), .Q(mu0mk_out[11]));
SRL16E mu0mk12(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[12]), .Q(mu0mk_out[12]));
SRL16E mu0mk13(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[13]), .Q(mu0mk_out[13]));
SRL16E mu0mk14(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[14]), .Q(mu0mk_out[14]));
SRL16E mu0mk15(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0mk_shift), .D(mu0mk_in[15]), .Q(mu0mk_out[15]));
SRL16E mu0eg00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[0]), .Q(mu0eg_out[0]));
SRL16E mu0eg01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[1]), .Q(mu0eg_out[1]));
SRL16E mu0eg02(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[2]), .Q(mu0eg_out[2]));
SRL16E mu0eg03(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[3]), .Q(mu0eg_out[3]));
SRL16E mu0eg04(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[4]), .Q(mu0eg_out[4]));
SRL16E mu0eg05(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[5]), .Q(mu0eg_out[5]));
SRL16E mu0eg06(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[6]), .Q(mu0eg_out[6]));
SRL16E mu0eg07(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[7]), .Q(mu0eg_out[7]));
SRL16E mu0eg08(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[8]), .Q(mu0eg_out[8]));
SRL16E mu0eg09(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[9]), .Q(mu0eg_out[9]));
SRL16E mu0eg10(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[10]), .Q(mu0eg_out[10]));
SRL16E mu0eg11(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[11]), .Q(mu0eg_out[11]));
SRL16E mu0eg12(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[12]), .Q(mu0eg_out[12]));
SRL16E mu0eg13(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[13]), .Q(mu0eg_out[13]));
SRL16E mu0eg14(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[14]), .Q(mu0eg_out[14]));
SRL16E mu0eg15(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0eg_shift), .D(mu0eg_in[15]), .Q(mu0eg_out[15]));
SRL16E mu0ct00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[0]), .Q(mu0ct_out[0]));
SRL16E mu0ct01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[1]), .Q(mu0ct_out[1]));
SRL16E mu0ct02(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[2]), .Q(mu0ct_out[2]));
SRL16E mu0ct03(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[3]), .Q(mu0ct_out[3]));
SRL16E mu0ct04(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[4]), .Q(mu0ct_out[4]));
SRL16E mu0ct05(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[5]), .Q(mu0ct_out[5]));
SRL16E mu0ct06(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[6]), .Q(mu0ct_out[6]));
SRL16E mu0ct07(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[7]), .Q(mu0ct_out[7]));
SRL16E mu0ct08(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[8]), .Q(mu0ct_out[8]));
SRL16E mu0ct09(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[9]), .Q(mu0ct_out[9]));
SRL16E mu0ct10(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[10]), .Q(mu0ct_out[10]));
SRL16E mu0ct11(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[11]), .Q(mu0ct_out[11]));
SRL16E mu0ct12(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[12]), .Q(mu0ct_out[12]));
SRL16E mu0ct13(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[13]), .Q(mu0ct_out[13]));
SRL16E mu0ct14(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[14]), .Q(mu0ct_out[14]));
SRL16E mu0ct15(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0ct_shift), .D(mu0ct_in[15]), .Q(mu0ct_out[15]));
SRL16E mu000(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[0]), .Q(mu0_out[0]));
SRL16E mu001(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[1]), .Q(mu0_out[1]));
SRL16E mu002(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[2]), .Q(mu0_out[2]));
SRL16E mu003(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[3]), .Q(mu0_out[3]));
SRL16E mu004(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[4]), .Q(mu0_out[4]));
SRL16E mu005(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[5]), .Q(mu0_out[5]));
SRL16E mu006(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[6]), .Q(mu0_out[6]));
SRL16E mu007(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[7]), .Q(mu0_out[7]));
SRL16E mu008(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[8]), .Q(mu0_out[8]));
SRL16E mu009(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[9]), .Q(mu0_out[9]));
SRL16E mu010(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[10]), .Q(mu0_out[10]));
SRL16E mu011(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[11]), .Q(mu0_out[11]));
SRL16E mu012(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[12]), .Q(mu0_out[12]));
SRL16E mu013(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[13]), .Q(mu0_out[13]));
SRL16E mu014(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[14]), .Q(mu0_out[14]));
SRL16E mu015(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0_shift), .D(mu0_in[15]), .Q(mu0_out[15]));
SRL16E mu0lg00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0lg_shift), .D(mu0lg_in[0]), .Q(mu0lg_out[0]));
SRL16E mu0lg01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu0lg_shift), .D(mu0lg_in[1]), .Q(mu0lg_out[1]));

// -- Match Unit 1 
SRL16E mu1mk00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[0]), .Q(mu1mk_out[0]));
SRL16E mu1mk01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[1]), .Q(mu1mk_out[1]));
SRL16E mu1mk02(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[2]), .Q(mu1mk_out[2]));
SRL16E mu1mk03(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[3]), .Q(mu1mk_out[3]));
SRL16E mu1mk04(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[4]), .Q(mu1mk_out[4]));
SRL16E mu1mk05(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[5]), .Q(mu1mk_out[5]));
SRL16E mu1mk06(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[6]), .Q(mu1mk_out[6]));
SRL16E mu1mk07(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[7]), .Q(mu1mk_out[7]));
SRL16E mu1mk08(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[8]), .Q(mu1mk_out[8]));
SRL16E mu1mk09(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[9]), .Q(mu1mk_out[9]));
SRL16E mu1mk10(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[10]), .Q(mu1mk_out[10]));
SRL16E mu1mk11(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[11]), .Q(mu1mk_out[11]));
SRL16E mu1mk12(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[12]), .Q(mu1mk_out[12]));
SRL16E mu1mk13(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[13]), .Q(mu1mk_out[13]));
SRL16E mu1mk14(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[14]), .Q(mu1mk_out[14]));
SRL16E mu1mk15(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1mk_shift), .D(mu1mk_in[15]), .Q(mu1mk_out[15]));
SRL16E mu1eg00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[0]), .Q(mu1eg_out[0]));
SRL16E mu1eg01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[1]), .Q(mu1eg_out[1]));
SRL16E mu1eg02(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[2]), .Q(mu1eg_out[2]));
SRL16E mu1eg03(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[3]), .Q(mu1eg_out[3]));
SRL16E mu1eg04(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[4]), .Q(mu1eg_out[4]));
SRL16E mu1eg05(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[5]), .Q(mu1eg_out[5]));
SRL16E mu1eg06(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[6]), .Q(mu1eg_out[6]));
SRL16E mu1eg07(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[7]), .Q(mu1eg_out[7]));
SRL16E mu1eg08(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[8]), .Q(mu1eg_out[8]));
SRL16E mu1eg09(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[9]), .Q(mu1eg_out[9]));
SRL16E mu1eg10(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[10]), .Q(mu1eg_out[10]));
SRL16E mu1eg11(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[11]), .Q(mu1eg_out[11]));
SRL16E mu1eg12(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[12]), .Q(mu1eg_out[12]));
SRL16E mu1eg13(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[13]), .Q(mu1eg_out[13]));
SRL16E mu1eg14(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[14]), .Q(mu1eg_out[14]));
SRL16E mu1eg15(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1eg_shift), .D(mu1eg_in[15]), .Q(mu1eg_out[15]));
SRL16E mu1ct00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[0]), .Q(mu1ct_out[0]));
SRL16E mu1ct01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[1]), .Q(mu1ct_out[1]));
SRL16E mu1ct02(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[2]), .Q(mu1ct_out[2]));
SRL16E mu1ct03(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[3]), .Q(mu1ct_out[3]));
SRL16E mu1ct04(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[4]), .Q(mu1ct_out[4]));
SRL16E mu1ct05(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[5]), .Q(mu1ct_out[5]));
SRL16E mu1ct06(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[6]), .Q(mu1ct_out[6]));
SRL16E mu1ct07(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[7]), .Q(mu1ct_out[7]));
SRL16E mu1ct08(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[8]), .Q(mu1ct_out[8]));
SRL16E mu1ct09(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[9]), .Q(mu1ct_out[9]));
SRL16E mu1ct10(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[10]), .Q(mu1ct_out[10]));
SRL16E mu1ct11(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[11]), .Q(mu1ct_out[11]));
SRL16E mu1ct12(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[12]), .Q(mu1ct_out[12]));
SRL16E mu1ct13(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[13]), .Q(mu1ct_out[13]));
SRL16E mu1ct14(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[14]), .Q(mu1ct_out[14]));
SRL16E mu1ct15(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1ct_shift), .D(mu1ct_in[15]), .Q(mu1ct_out[15]));
SRL16E mu100(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[0]), .Q(mu1_out[0]));
SRL16E mu101(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[1]), .Q(mu1_out[1]));
SRL16E mu102(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[2]), .Q(mu1_out[2]));
SRL16E mu103(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[3]), .Q(mu1_out[3]));
SRL16E mu104(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[4]), .Q(mu1_out[4]));
SRL16E mu105(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[5]), .Q(mu1_out[5]));
SRL16E mu106(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[6]), .Q(mu1_out[6]));
SRL16E mu107(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[7]), .Q(mu1_out[7]));
SRL16E mu108(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[8]), .Q(mu1_out[8]));
SRL16E mu109(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[9]), .Q(mu1_out[9]));
SRL16E mu110(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[10]), .Q(mu1_out[10]));
SRL16E mu111(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[11]), .Q(mu1_out[11]));
SRL16E mu112(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[12]), .Q(mu1_out[12]));
SRL16E mu113(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[13]), .Q(mu1_out[13]));
SRL16E mu114(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[14]), .Q(mu1_out[14]));
SRL16E mu115(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1_shift), .D(mu1_in[15]), .Q(mu1_out[15]));
SRL16E mu1lg00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1lg_shift), .D(mu1lg_in[0]), .Q(mu1lg_out[0]));
SRL16E mu1lg01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu1lg_shift), .D(mu1lg_in[1]), .Q(mu1lg_out[1]));

// -- Match Unit 2 
SRL16E mu2mk00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[0]), .Q(mu2mk_out[0]));
SRL16E mu2mk01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[1]), .Q(mu2mk_out[1]));
SRL16E mu2mk02(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[2]), .Q(mu2mk_out[2]));
SRL16E mu2mk03(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[3]), .Q(mu2mk_out[3]));
SRL16E mu2mk04(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[4]), .Q(mu2mk_out[4]));
SRL16E mu2mk05(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[5]), .Q(mu2mk_out[5]));
SRL16E mu2mk06(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[6]), .Q(mu2mk_out[6]));
SRL16E mu2mk07(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[7]), .Q(mu2mk_out[7]));
SRL16E mu2mk08(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[8]), .Q(mu2mk_out[8]));
SRL16E mu2mk09(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[9]), .Q(mu2mk_out[9]));
SRL16E mu2mk10(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[10]), .Q(mu2mk_out[10]));
SRL16E mu2mk11(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[11]), .Q(mu2mk_out[11]));
SRL16E mu2mk12(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[12]), .Q(mu2mk_out[12]));
SRL16E mu2mk13(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[13]), .Q(mu2mk_out[13]));
SRL16E mu2mk14(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[14]), .Q(mu2mk_out[14]));
SRL16E mu2mk15(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2mk_shift), .D(mu2mk_in[15]), .Q(mu2mk_out[15]));
SRL16E mu2eg00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[0]), .Q(mu2eg_out[0]));
SRL16E mu2eg01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[1]), .Q(mu2eg_out[1]));
SRL16E mu2eg02(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[2]), .Q(mu2eg_out[2]));
SRL16E mu2eg03(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[3]), .Q(mu2eg_out[3]));
SRL16E mu2eg04(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[4]), .Q(mu2eg_out[4]));
SRL16E mu2eg05(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[5]), .Q(mu2eg_out[5]));
SRL16E mu2eg06(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[6]), .Q(mu2eg_out[6]));
SRL16E mu2eg07(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[7]), .Q(mu2eg_out[7]));
SRL16E mu2eg08(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[8]), .Q(mu2eg_out[8]));
SRL16E mu2eg09(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[9]), .Q(mu2eg_out[9]));
SRL16E mu2eg10(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[10]), .Q(mu2eg_out[10]));
SRL16E mu2eg11(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[11]), .Q(mu2eg_out[11]));
SRL16E mu2eg12(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[12]), .Q(mu2eg_out[12]));
SRL16E mu2eg13(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[13]), .Q(mu2eg_out[13]));
SRL16E mu2eg14(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[14]), .Q(mu2eg_out[14]));
SRL16E mu2eg15(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2eg_shift), .D(mu2eg_in[15]), .Q(mu2eg_out[15]));
SRL16E mu2ct00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[0]), .Q(mu2ct_out[0]));
SRL16E mu2ct01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[1]), .Q(mu2ct_out[1]));
SRL16E mu2ct02(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[2]), .Q(mu2ct_out[2]));
SRL16E mu2ct03(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[3]), .Q(mu2ct_out[3]));
SRL16E mu2ct04(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[4]), .Q(mu2ct_out[4]));
SRL16E mu2ct05(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[5]), .Q(mu2ct_out[5]));
SRL16E mu2ct06(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[6]), .Q(mu2ct_out[6]));
SRL16E mu2ct07(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[7]), .Q(mu2ct_out[7]));
SRL16E mu2ct08(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[8]), .Q(mu2ct_out[8]));
SRL16E mu2ct09(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[9]), .Q(mu2ct_out[9]));
SRL16E mu2ct10(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[10]), .Q(mu2ct_out[10]));
SRL16E mu2ct11(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[11]), .Q(mu2ct_out[11]));
SRL16E mu2ct12(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[12]), .Q(mu2ct_out[12]));
SRL16E mu2ct13(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[13]), .Q(mu2ct_out[13]));
SRL16E mu2ct14(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[14]), .Q(mu2ct_out[14]));
SRL16E mu2ct15(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2ct_shift), .D(mu2ct_in[15]), .Q(mu2ct_out[15]));
SRL16E mu200(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[0]), .Q(mu2_out[0]));
SRL16E mu201(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[1]), .Q(mu2_out[1]));
SRL16E mu202(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[2]), .Q(mu2_out[2]));
SRL16E mu203(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[3]), .Q(mu2_out[3]));
SRL16E mu204(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[4]), .Q(mu2_out[4]));
SRL16E mu205(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[5]), .Q(mu2_out[5]));
SRL16E mu206(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[6]), .Q(mu2_out[6]));
SRL16E mu207(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[7]), .Q(mu2_out[7]));
SRL16E mu208(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[8]), .Q(mu2_out[8]));
SRL16E mu209(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[9]), .Q(mu2_out[9]));
SRL16E mu210(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[10]), .Q(mu2_out[10]));
SRL16E mu211(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[11]), .Q(mu2_out[11]));
SRL16E mu212(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[12]), .Q(mu2_out[12]));
SRL16E mu213(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[13]), .Q(mu2_out[13]));
SRL16E mu214(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[14]), .Q(mu2_out[14]));
SRL16E mu215(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2_shift), .D(mu2_in[15]), .Q(mu2_out[15]));
SRL16E mu2lg00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2lg_shift), .D(mu2lg_in[0]), .Q(mu2lg_out[0]));
SRL16E mu2lg01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu2lg_shift), .D(mu2lg_in[1]), .Q(mu2lg_out[1]));

// -- Match Unit 3 
SRL16E mu3mk00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[0]), .Q(mu3mk_out[0]));
SRL16E mu3mk01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[1]), .Q(mu3mk_out[1]));
SRL16E mu3mk02(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[2]), .Q(mu3mk_out[2]));
SRL16E mu3mk03(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[3]), .Q(mu3mk_out[3]));
SRL16E mu3mk04(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[4]), .Q(mu3mk_out[4]));
SRL16E mu3mk05(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[5]), .Q(mu3mk_out[5]));
SRL16E mu3mk06(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[6]), .Q(mu3mk_out[6]));
SRL16E mu3mk07(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[7]), .Q(mu3mk_out[7]));
SRL16E mu3mk08(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[8]), .Q(mu3mk_out[8]));
SRL16E mu3mk09(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[9]), .Q(mu3mk_out[9]));
SRL16E mu3mk10(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[10]), .Q(mu3mk_out[10]));
SRL16E mu3mk11(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[11]), .Q(mu3mk_out[11]));
SRL16E mu3mk12(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[12]), .Q(mu3mk_out[12]));
SRL16E mu3mk13(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[13]), .Q(mu3mk_out[13]));
SRL16E mu3mk14(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[14]), .Q(mu3mk_out[14]));
SRL16E mu3mk15(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3mk_shift), .D(mu3mk_in[15]), .Q(mu3mk_out[15]));
SRL16E mu3eg00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[0]), .Q(mu3eg_out[0]));
SRL16E mu3eg01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[1]), .Q(mu3eg_out[1]));
SRL16E mu3eg02(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[2]), .Q(mu3eg_out[2]));
SRL16E mu3eg03(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[3]), .Q(mu3eg_out[3]));
SRL16E mu3eg04(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[4]), .Q(mu3eg_out[4]));
SRL16E mu3eg05(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[5]), .Q(mu3eg_out[5]));
SRL16E mu3eg06(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[6]), .Q(mu3eg_out[6]));
SRL16E mu3eg07(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[7]), .Q(mu3eg_out[7]));
SRL16E mu3eg08(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[8]), .Q(mu3eg_out[8]));
SRL16E mu3eg09(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[9]), .Q(mu3eg_out[9]));
SRL16E mu3eg10(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[10]), .Q(mu3eg_out[10]));
SRL16E mu3eg11(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[11]), .Q(mu3eg_out[11]));
SRL16E mu3eg12(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[12]), .Q(mu3eg_out[12]));
SRL16E mu3eg13(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[13]), .Q(mu3eg_out[13]));
SRL16E mu3eg14(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[14]), .Q(mu3eg_out[14]));
SRL16E mu3eg15(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3eg_shift), .D(mu3eg_in[15]), .Q(mu3eg_out[15]));
SRL16E mu3ct00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[0]), .Q(mu3ct_out[0]));
SRL16E mu3ct01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[1]), .Q(mu3ct_out[1]));
SRL16E mu3ct02(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[2]), .Q(mu3ct_out[2]));
SRL16E mu3ct03(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[3]), .Q(mu3ct_out[3]));
SRL16E mu3ct04(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[4]), .Q(mu3ct_out[4]));
SRL16E mu3ct05(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[5]), .Q(mu3ct_out[5]));
SRL16E mu3ct06(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[6]), .Q(mu3ct_out[6]));
SRL16E mu3ct07(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[7]), .Q(mu3ct_out[7]));
SRL16E mu3ct08(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[8]), .Q(mu3ct_out[8]));
SRL16E mu3ct09(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[9]), .Q(mu3ct_out[9]));
SRL16E mu3ct10(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[10]), .Q(mu3ct_out[10]));
SRL16E mu3ct11(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[11]), .Q(mu3ct_out[11]));
SRL16E mu3ct12(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[12]), .Q(mu3ct_out[12]));
SRL16E mu3ct13(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[13]), .Q(mu3ct_out[13]));
SRL16E mu3ct14(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[14]), .Q(mu3ct_out[14]));
SRL16E mu3ct15(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3ct_shift), .D(mu3ct_in[15]), .Q(mu3ct_out[15]));
SRL16E mu300(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[0]), .Q(mu3_out[0]));
SRL16E mu301(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[1]), .Q(mu3_out[1]));
SRL16E mu302(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[2]), .Q(mu3_out[2]));
SRL16E mu303(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[3]), .Q(mu3_out[3]));
SRL16E mu304(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[4]), .Q(mu3_out[4]));
SRL16E mu305(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[5]), .Q(mu3_out[5]));
SRL16E mu306(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[6]), .Q(mu3_out[6]));
SRL16E mu307(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[7]), .Q(mu3_out[7]));
SRL16E mu308(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[8]), .Q(mu3_out[8]));
SRL16E mu309(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[9]), .Q(mu3_out[9]));
SRL16E mu310(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[10]), .Q(mu3_out[10]));
SRL16E mu311(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[11]), .Q(mu3_out[11]));
SRL16E mu312(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[12]), .Q(mu3_out[12]));
SRL16E mu313(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[13]), .Q(mu3_out[13]));
SRL16E mu314(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[14]), .Q(mu3_out[14]));
SRL16E mu315(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3_shift), .D(mu3_in[15]), .Q(mu3_out[15]));
SRL16E mu3lg00(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3lg_shift), .D(mu3lg_in[0]), .Q(mu3lg_out[0]));
SRL16E mu3lg01(.A0(1'b1), .A1(1'b1), .A2(1'b1), .A3(1'b1), .CLK(core_clk), .CE(mu3lg_shift), .D(mu3lg_in[1]), .Q(mu3lg_out[1]));


endmodule
