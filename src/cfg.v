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

module cfg(
	// --clock & reset
	input		usb_clk,
	input		usb_rst,
	input    core_clk,
	input    core_rst,
	
	// -- usb config
	input		usb_en,
	input		usb_wr,
	input	[15:0]	usb_data,

	input			capture_done,

	// -- config output
	output		ext_clk_mode,
	output		test_mode,
	output		ext_test_mode,
	output		sd_lpb_mode,
	output		falling_mode,
	output		cons_mode,
	output		half_mode,
	output		quarter_mode,
	output		wireless_mode,
	output	[23:0]	sample_divider,
	
	output	reg		full_speed,
	output				trig_en,
	output	[3:0]		trig_stages,
	output				trig_value_wr,
	output				trig_mask_wr,
	output				trig_edge_wr,
	output				trig_count_wr,
	output				trig_logic_wr,
	output	[1:0]		trig_mu,
	output	[15:0]	trig_mask,
	output	[15:0]	trig_value,
	output	[15:0]	trig_edge,
	output	[15:0]	trig_count,
	output	[1:0]		trig_logic,

	output	[31:0]	sample_depth,
	output	reg	[31:0]	sample_last_cnt,
	output	reg	[31:0]	sample_real_start,
	output	[31:0]	trig_set_pos,
	output	reg	[31:0]	trig_set_pos_minus1,
	output	[31:0]	after_trig_depth,

	output		read_start,
	output	[31:0]	sd_saddr,
	output		sd_fbe
);

// --
// parameters
// --
parameter    SYNC_CODE = 8'hFF;
parameter    UNSYNC_CODE = 8'h00;

// --
// configure protocol decode
// --
wire		usb_cfg_wr;
wire	[4:0]	usb_cfg_addr;
wire	[15:0]	usb_cfg_din;
wire		usb_cfg_rd;
reg	[15:0]	usb_cfg_dout;

reg		usb_en_reg;
reg		usb_wr_reg;
reg	[15:0]	usb_data_reg;

reg		usb_cfg_sync;
wire		usb_cfg_sync_nxt;
reg		usb_cfg;
wire		usb_cfg_nxt;
reg	[7:0]	usb_cfg_cnt;
wire	[7:0]	usb_cfg_cnt_nxt;
reg	[5:0]	usb_addr;
wire	[5:0]	usb_addr_nxt;

wire				cfg_trig_value_wr;
wire				cfg_trig_mask_wr;
wire				cfg_trig_edge_wr;
wire				cfg_trig_count_wr;
wire				cfg_trig_logic_wr;
wire	[1:0]		cfg_trig_mu;
wire	[15:0]	cfg_trig_mask;
wire	[15:0]	cfg_trig_value;
wire	[15:0]	cfg_trig_edge;
wire	[15:0]	cfg_trig_count;
wire	[15:0]	cfg_trig_logic;

// -- usb_cfg
always @(posedge usb_clk or posedge usb_rst)
begin
    if (usb_rst) begin
	usb_en_reg <= `D 1'b0;
	usb_wr_reg <= `D 1'b0;
	usb_data_reg <= `D 16'b0;
    end else begin
	usb_en_reg <= `D usb_en;
	usb_wr_reg <= `D usb_wr;
	usb_data_reg <= `D usb_data;
    end
end

assign usb_cfg_sync_nxt = usb_en_reg & usb_wr_reg & (usb_data_reg == 16'hf5a5) ? 1'b1 :
                          usb_en_reg & usb_wr_reg & (usb_data_reg == 16'hfa5a) ? 1'b0 : usb_cfg_sync;
assign usb_cfg_nxt = usb_cfg_sync & (usb_data_reg[15:14] == 2'b0) & |usb_data_reg & ~usb_cfg ? 1'b1 :
		     usb_cfg_sync & (usb_cfg_cnt == 8'd1) ? 1'b0 : usb_cfg;
assign usb_cfg_cnt_nxt = (usb_cfg_sync & (usb_data_reg[15:14] == 2'b0) & (usb_cfg_cnt == 8'b0)) ? usb_data_reg[7:0] :
			 (usb_cfg_sync & (usb_cfg_cnt != 8'b0)) ? usb_cfg_cnt - 1'b1 : usb_cfg_cnt;
assign usb_addr_nxt = (usb_cfg_nxt & ~usb_cfg) ? usb_data_reg[13:8] :
		      usb_cfg_wr ? usb_addr + 1'b1 : usb_addr;
always @(posedge usb_clk or posedge usb_rst)
begin
    if (usb_rst) begin
	usb_cfg_sync <= `D 1'b0;
	usb_cfg <= `D 1'b0;
	usb_cfg_cnt <= `D 8'b0;
	usb_addr <= `D 6'b0;
    end else begin
	usb_cfg_sync <= `D usb_cfg_sync_nxt;
	usb_cfg <= `D usb_cfg_nxt;
	usb_cfg_cnt <= `D usb_cfg_cnt_nxt;
	usb_addr <= `D usb_addr_nxt;
    end
end    
assign usb_cfg_wr = usb_cfg & usb_en_reg & usb_wr & (usb_addr[5:4] == 2'b0);
assign usb_cfg_addr = usb_addr[4:0];
assign usb_cfg_din = usb_data_reg;
assign usb_cfg_rd = 1'b0;

reg	[5:0]	cfg_trig_mu_addr;
wire	[5:0]	cfg_trig_mu_addr_nxt;
assign cfg_trig_mask_wr = usb_cfg & usb_en_reg & usb_wr & (cfg_trig_mu_addr[5:2] == 4'b0100);
assign cfg_trig_value_wr = usb_cfg & usb_en_reg & usb_wr & (cfg_trig_mu_addr[5:2] == 4'b0101);
assign cfg_trig_edge_wr = usb_cfg & usb_en_reg & usb_wr & (cfg_trig_mu_addr[5:2] == 4'b0110);
assign cfg_trig_count_wr = usb_cfg & usb_en_reg & usb_wr & (cfg_trig_mu_addr[5:2] == 4'b0111);
assign cfg_trig_logic_wr = usb_cfg & usb_en_reg & usb_wr & (cfg_trig_mu_addr[5:2] == 4'b1000);
assign cfg_trig_mu_addr_nxt = (usb_cfg_nxt & ~usb_cfg) ? usb_data_reg[13:8] : cfg_trig_mu_addr;
always @(posedge usb_clk)
begin
	cfg_trig_mu_addr <= `D cfg_trig_mu_addr_nxt;
end
assign cfg_trig_mu = cfg_trig_mu_addr[1:0];
assign cfg_trig_mask = usb_data_reg;
assign cfg_trig_value = usb_data_reg;
assign cfg_trig_edge = usb_data_reg;
assign cfg_trig_count = usb_data_reg;
assign cfg_trig_logic = usb_data_reg;

wire	mask_cfg_empty;
wire	[17:0]	mask_dout;
wire	value_cfg_empty;
wire	[17:0]	value_dout;
wire	edge_cfg_empty;
wire	[17:0]	edge_dout;
wire	count_cfg_empty;
wire	[17:0]	count_dout;
wire	logic_cfg_empty;
wire	[17:0]	logic_dout;
trig_cfg_fifo mask_cfg(
  .wr_clk(usb_clk), // input wr_clk
  .wr_rst(usb_rst), // input wr_rst
  .rd_clk(core_clk), // input rd_clk
  .rd_rst(core_rst), // input rd_rst
  .din({cfg_trig_mu, cfg_trig_mask}), // input [17 : 0] din
  .wr_en(cfg_trig_mask_wr), // input wr_en
  .rd_en(~mask_cfg_empty), // input rd_en
  .dout(mask_dout), // output [17 : 0] dout
  .full(), // output full
  .empty(mask_cfg_empty) // output empty
);
trig_cfg_fifo value_cfg(
  .wr_clk(usb_clk), // input wr_clk
  .wr_rst(usb_rst), // input wr_rst
  .rd_clk(core_clk), // input rd_clk
  .rd_rst(core_rst), // input rd_rst
  .din({cfg_trig_mu, cfg_trig_value}), // input [17 : 0] din
  .wr_en(cfg_trig_value_wr), // input wr_en
  .rd_en(~value_cfg_empty), // input rd_en
  .dout(value_dout), // output [17 : 0] dout
  .full(), // output full
  .empty(value_cfg_empty) // output empty
);
trig_cfg_fifo edge_cfg(
  .wr_clk(usb_clk), // input wr_clk
  .wr_rst(usb_rst), // input wr_rst
  .rd_clk(core_clk), // input rd_clk
  .rd_rst(core_rst), // input rd_rst
  .din({cfg_trig_mu, cfg_trig_edge}), // input [17 : 0] din
  .wr_en(cfg_trig_edge_wr), // input wr_en
  .rd_en(~edge_cfg_empty), // input rd_en
  .dout(edge_dout), // output [17 : 0] dout
  .full(), // output full
  .empty(edge_cfg_empty) // output empty
);
trig_cfg_fifo count_cfg(
  .wr_clk(usb_clk), // input wr_clk
  .wr_rst(usb_rst), // input wr_rst
  .rd_clk(core_clk), // input rd_clk
  .rd_rst(core_rst), // input rd_rst
  .din({cfg_trig_mu, cfg_trig_count}), // input [17 : 0] din
  .wr_en(cfg_trig_count_wr), // input wr_en
  .rd_en(~count_cfg_empty), // input rd_en
  .dout(count_dout), // output [17 : 0] dout
  .full(), // output full
  .empty(count_cfg_empty) // output empty
);
trig_cfg_fifo logic_cfg(
  .wr_clk(usb_clk), // input wr_clk
  .wr_rst(usb_rst), // input wr_rst
  .rd_clk(core_clk), // input rd_clk
  .rd_rst(core_rst), // input rd_rst
  .din({cfg_trig_mu, cfg_trig_logic}), // input [17 : 0] din
  .wr_en(cfg_trig_logic_wr), // input wr_en
  .rd_en(~logic_cfg_empty), // input rd_en
  .dout(logic_dout), // output [17 : 0] dout
  .full(), // output full
  .empty(logic_cfg_empty) // output empty
);
assign trig_mask_wr = ~mask_cfg_empty;
assign trig_value_wr = ~value_cfg_empty;
assign trig_edge_wr = ~edge_cfg_empty;
assign trig_count_wr = ~count_cfg_empty;
assign trig_logic_wr = ~logic_cfg_empty;
assign trig_mu = trig_mask_wr ? mask_dout[17:16] : 
					  trig_value_wr ? value_dout[17:16] : 
					  trig_edge_wr ? edge_dout[17:16] : 
					  trig_count_wr ? count_dout[17:16] : logic_dout[17:16];
assign trig_mask = mask_dout[15:0];
assign trig_value = value_dout[15:0];
assign trig_edge = edge_dout[15:0];
assign trig_count = count_dout[15:0];
assign trig_logic = logic_dout[1:0];


// --
// configure registers
// --
reg	[15:0]	cfg0_reg;
wire	[15:0]	cfg0_reg_nxt;
reg	[15:0]	cfg1_reg;
wire	[15:0]	cfg1_reg_nxt;
reg	[15:0]	cfg2_reg;
wire	[15:0]	cfg2_reg_nxt;
reg	[15:0]	cfg3_reg;
wire	[15:0]	cfg3_reg_nxt;
reg	[15:0]	cfg4_reg;
wire	[15:0]	cfg4_reg_nxt;
reg	[15:0]	cfg5_reg;
wire	[15:0]	cfg5_reg_nxt;
reg	[15:0]	cfg6_reg;
wire	[15:0]	cfg6_reg_nxt;
reg	[15:0]	cfg7_reg;
wire	[15:0]	cfg7_reg_nxt;
reg	[15:0]	cfg8_reg;
wire	[15:0]	cfg8_reg_nxt;
reg	[15:0]	cfg9_reg;
wire	[15:0]	cfg9_reg_nxt;
reg	[15:0]	cfg10_reg;
wire	[15:0]	cfg10_reg_nxt;
reg	[15:0]	cfg11_reg;
wire	[15:0]	cfg11_reg_nxt;
reg	[15:0]	cfg12_reg;
wire	[15:0]	cfg12_reg_nxt;
reg	[15:0]	cfg13_reg;
wire	[15:0]	cfg13_reg_nxt;


// --
// registers output mapping
// --
assign trig_en = cfg0_reg[0];
assign ext_clk_mode = cfg0_reg[1];
assign falling_mode = cfg0_reg[2];
assign adv_mode = cfg0_reg[3];
assign cons_mode = cfg0_reg[4];
assign half_mode = cfg0_reg[5];
assign quarter_mode = cfg0_reg[6];
assign wireless_mode = cfg0_reg[7];
assign sd_lpb_mode = cfg0_reg[13];
assign ext_test_mode = cfg0_reg[14];
assign test_mode = cfg0_reg[15];

wire	full_speed_nxt = (sample_divider == 24'd1);
always @(posedge usb_clk)
begin
	full_speed <= `D full_speed_nxt;
end
assign sample_divider[15:0] = cfg1_reg;
assign sample_divider[23:16] = cfg2_reg[7:0];

assign sample_depth[15:0] = cfg3_reg;
assign sample_depth[31:16] = cfg4_reg;
always @(posedge usb_clk)
begin
	sample_last_cnt <= `D sample_depth - 1'b1;
	sample_real_start <= `D (trig_set_pos == 32'b0) ? 32'b0 : sample_depth - trig_set_pos;
	trig_set_pos_minus1 <= `D (trig_set_pos == 32'b0) ? 32'b0 : trig_set_pos - 1'b1;
end
assign trig_set_pos[15:0] = half_mode ? {cfg6_reg[0], cfg5_reg[15:1]} : 
                            quarter_mode ? {cfg6_reg[1:0], cfg5_reg[15:2]} : cfg5_reg;
assign trig_set_pos[31:16] = half_mode ? cfg6_reg >> 1 : 
                             quarter_mode ? cfg6_reg >> 2 : cfg6_reg;

assign trig_stages = cfg7_reg[3:0];

assign after_trig_depth[15:0] = cfg10_reg;
assign after_trig_depth[31:16] = cfg11_reg;

assign read_start = cfg12_reg[0];
assign sd_fbe = cfg12_reg[1];
assign sd_saddr[31:16] = cfg13_reg;
assign sd_saddr[15:0] = {cfg12_reg[15:2], 2'b0};

// --
//
// --
wire	r00 = usb_cfg_rd & (usb_cfg_addr == 5'd0);
wire	r01 = usb_cfg_rd & (usb_cfg_addr == 5'd1);
wire	r02 = usb_cfg_rd & (usb_cfg_addr == 5'd2);
wire	r03 = usb_cfg_rd & (usb_cfg_addr == 5'd3);
wire	r04 = usb_cfg_rd & (usb_cfg_addr == 5'd4);
wire	r05 = usb_cfg_rd & (usb_cfg_addr == 5'd5);
wire	r06 = usb_cfg_rd & (usb_cfg_addr == 5'd6);
wire	r07 = usb_cfg_rd & (usb_cfg_addr == 5'd7);
wire	r08 = usb_cfg_rd & (usb_cfg_addr == 5'd8);
wire	r09 = usb_cfg_rd & (usb_cfg_addr == 5'd9);
wire	r10 = usb_cfg_rd & (usb_cfg_addr == 5'd10);
wire	r11 = usb_cfg_rd & (usb_cfg_addr == 5'd11);
wire	r12 = usb_cfg_rd & (usb_cfg_addr == 5'd12);
wire	r13 = usb_cfg_rd & (usb_cfg_addr == 5'd13);
wire	r17 = usb_cfg_rd & (usb_cfg_addr == 5'd17);
wire	r18 = usb_cfg_rd & (usb_cfg_addr == 5'd18);
wire	r19 = usb_cfg_rd & (usb_cfg_addr == 5'd19);

wire	w00 = usb_cfg_wr & (usb_cfg_addr == 5'd0);
wire	w01 = usb_cfg_wr & (usb_cfg_addr == 5'd1);
wire	w02 = usb_cfg_wr & (usb_cfg_addr == 5'd2);
wire	w03 = usb_cfg_wr & (usb_cfg_addr == 5'd3);
wire	w04 = usb_cfg_wr & (usb_cfg_addr == 5'd4);
wire	w05 = usb_cfg_wr & (usb_cfg_addr == 5'd5);
wire	w06 = usb_cfg_wr & (usb_cfg_addr == 5'd6);
wire	w07 = usb_cfg_wr & (usb_cfg_addr == 5'd7);
wire	w08 = usb_cfg_wr & (usb_cfg_addr == 5'd8);
wire	w09 = usb_cfg_wr & (usb_cfg_addr == 5'd9);
wire	w10 = usb_cfg_wr & (usb_cfg_addr == 5'd10);
wire	w11 = usb_cfg_wr & (usb_cfg_addr == 5'd11);
wire	w12 = usb_cfg_wr & (usb_cfg_addr == 5'd12);
wire	w13 = usb_cfg_wr & (usb_cfg_addr == 5'd13);

// --
// config write
// --
assign cfg0_reg_nxt = w00 ? usb_cfg_din : cfg0_reg;
assign cfg1_reg_nxt = w01 ? usb_cfg_din : cfg1_reg;
assign cfg2_reg_nxt = w02 ? usb_cfg_din : cfg2_reg;
assign cfg3_reg_nxt = w03 ? usb_cfg_din : cfg3_reg;
assign cfg4_reg_nxt = w04 ? usb_cfg_din : cfg4_reg;
assign cfg5_reg_nxt = w05 ? usb_cfg_din : cfg5_reg;
assign cfg6_reg_nxt = w06 ? usb_cfg_din : cfg6_reg;
assign cfg7_reg_nxt = w07 ? usb_cfg_din : cfg7_reg;
assign cfg8_reg_nxt = w08 ? usb_cfg_din : cfg8_reg;
assign cfg9_reg_nxt = w09 ? usb_cfg_din : cfg9_reg;
assign cfg10_reg_nxt = w10 ? usb_cfg_din : cfg10_reg;
assign cfg11_reg_nxt = w11 ? usb_cfg_din : cfg11_reg;
assign cfg12_reg_nxt[15] = cfg12_reg[15] ? 1'b0 :
			   w12 ? usb_cfg_din[15] : cfg12_reg[15];
assign cfg12_reg_nxt[14:0] = w12 ? usb_cfg_din[14:0] : cfg12_reg[14:0];
assign cfg13_reg_nxt = w13 ? usb_cfg_din : cfg13_reg;
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst)
	begin
		cfg0_reg <= `D 16'b0;
		cfg1_reg <= `D 16'b1;
		cfg2_reg <= `D 16'b0;
		cfg3_reg <= `D 16'b0;
		cfg4_reg <= `D 16'b0;
		cfg5_reg <= `D 16'b0;
		cfg6_reg <= `D 16'b0;
		cfg7_reg <= `D 16'b0;
		cfg8_reg <= `D 16'b0;
		cfg9_reg <= `D 16'b0;
		cfg10_reg <= `D 16'b0;
		cfg11_reg <= `D 16'b0;
		cfg12_reg <= `D 16'b0;
		cfg13_reg <= `D 16'b0;
	end
	else
	begin
		cfg0_reg <= `D cfg0_reg_nxt;
		cfg1_reg <= `D cfg1_reg_nxt;
		cfg2_reg <= `D cfg2_reg_nxt;
		cfg3_reg <= `D cfg3_reg_nxt;
		cfg4_reg <= `D cfg4_reg_nxt;
		cfg5_reg <= `D cfg5_reg_nxt;
		cfg6_reg <= `D cfg6_reg_nxt;
		cfg7_reg <= `D cfg7_reg_nxt;
		cfg8_reg <= `D cfg8_reg_nxt;
		cfg9_reg <= `D cfg9_reg_nxt;
		cfg10_reg <= `D cfg10_reg_nxt;
		cfg11_reg <= `D cfg11_reg_nxt;
		cfg12_reg <= `D cfg12_reg_nxt;
		cfg13_reg <= `D cfg13_reg_nxt;
	end
end

// --
// -- config read
// --
//reg	[15:0]	usb_cfg_dout;
wire	[15:0]	usb_cfg_dout_nxt;

assign usb_cfg_dout_nxt = r00 ? cfg0_reg :
       			  r01 ? cfg1_reg :
		  	  r02 ? cfg2_reg :
		  	  r03 ? cfg3_reg :
		  	  r04 ? cfg4_reg :
		  	  r05 ? cfg5_reg :
		  	  r06 ? cfg6_reg :
		  	  r07 ? cfg7_reg :
		  	  r08 ? cfg8_reg :
		  	  r09 ? cfg9_reg :
		  	  r10 ? cfg10_reg :
		          r11 ? cfg11_reg :
		          r12 ? cfg12_reg :
		          r13 ? cfg13_reg : 16'b0;
always @(posedge usb_clk or posedge usb_rst)
begin
	if (usb_rst)
		usb_cfg_dout <= `D 16'b0;
	else
		usb_cfg_dout <= `D usb_cfg_dout_nxt;
end	


endmodule
