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

module DSLogic_top(
	// -- clock & reset
 	input	sys_clk,
	input cclk,
	inout	ext_clk,
	output	sd_clk_out,
	input	sd_clk_fb,
	input	sys_rst,
	input	sys_clr,
	input	sys_en,
	
	// control
	output	ledn,
	
	// -- external signal 
	inout		ext_trig,
	output		ext_out,
	input	[15:0]	ext_data,
	
	// -- i2c
	input		scl,
	inout		sda,

	// -- Slave FIFO interface
	input		usb_en,
	input		usb_rdwr,
	output		usb_rdy,
	output		usb_overflow,
	inout	[15:0]	usb_data,
	
	// -- SDRAM interface
	output	[12:0]	sd_addr,
	output	[1:0]	sd_ba,
	inout	[15:0]	sd_dq,
	output		sd_ras_,
	output		sd_cas_,
	output		sd_we_,
	output		sd_dqml,
	output		sd_dqmh,
	//output		sd_cke,
	output		sd_cs_
);

// --


// --
wire		usb_clk;
wire		core_clk;
wire		core_rst;
wire		int_clk;
wire		int_clk_2x;
wire		out_clk;
wire		sample_clk;
wire		sample_rst;
wire		sd_clk;
wire		sd_rst;
wire		sdram_rst_;

//wire		sample_en;
wire		ext_clk_mode;
wire		test_mode;
wire		ext_test_mode;
wire		sd_lpb_mode;
wire		falling_mode;
wire		cons_mode;
wire		half_mode;
wire		quarter_mode;
wire		wireless_mode;
wire	[23:0]	sample_divider;

wire	[15:0]	sample_data;
wire		sample_valid;

wire	[15:0]	usb_cfg_dout;
wire	[15:0]	usb_din;
wire	[15:0]	usb_dout;
wire	[15:0]	usb_rdata;

wire				full_speed;
wire				trig_en;
wire	[3:0]		trig_stages;
wire				trig_value_wr;
wire				trig_mask_wr;
wire				trig_edge_wr;
wire				trig_count_wr;
wire				trig_logic_wr;
wire	[1:0]		trig_mu;
wire	[15:0]	trig_mask;
wire	[15:0]	trig_value;
wire	[15:0]	trig_edge;
wire	[15:0]	trig_count;
wire	[1:0]		trig_logic;

wire	[31:0]	sample_depth;
wire	[31:0]	sample_last_cnt;
wire	[31:0]	sample_real_start;
wire	[31:0]	trig_set_pos;
wire	[31:0]	trig_set_pos_minus1;
wire	[31:0]	after_trig_depth;

wire		read_start;
wire	[31:0]	sd_saddr;
wire	[31:0]	trig_real_pos;
wire		sd_fbe;

wire		trig_hit;
wire	[3:0]	trig_dly;

wire		capture_done;
wire		capture_valid;
wire	[15:0]	capture_data;

wire				lpb_read_done;
wire				lpb_read;
wire				lpb_error;
wire	[31:0]	lpb_sample_last_cnt;
wire				lpb_capture_done;
wire				lpb_capture_valid;
wire	[15:0]	lpb_capture_data;
wire	[31:0]	dw_sample_last_cnt;
wire				dw_capture_done;
wire				dw_capture_valid;
wire	[15:0]	dw_capture_data;
wire				dr_usb_rdy;
wire	[15:0]	dr_usb_dout;

wire		wr_done;
wire		wr_req;
wire		wr_valid;
wire	[31:0]	wr_addr;
wire	[15:0]	wr_data;

wire		rd_req;
wire		rd_valid;
wire	[31:0]	rd_addr;
wire		rd_rdy;
wire	[15:0]	rd_data;

wire		sd_wr_done;
wire		sd_wr_req;
wire		sd_wr_valid;
wire	[31:0]	sd_wr_addr;
wire	[15:0]	sd_wr_data;

wire		sd_rd_req;
wire		sd_rd_valid;
wire	[31:0]	sd_rd_addr;
wire		sd_rd_rdy;
wire	[15:0]	sd_rd_data;

wire	ext_pin_oe;
wire	ext_trig_oe_oddr;
wire	ext_clk_oe_oddr;
wire	ext_clk_in;
wire	ext_clk_out;
wire	ext_trig_in;
wire	ext_trig_out;
wire	uart_tx;
wire	uart_rx;

wire	[23:0]	dso_sampleDivider;
wire	[23:0]	dso_triggerPos;
wire	[7:0]		dso_triggerSlope;
wire	[7:0]		dso_triggerSource;
wire	[15:0]	dso_triggerValue;
wire				dso_setZero;
wire				dso_setZero_done;

// --
// ports
//--

assign usb_din = (usb_rdwr == 1'b1) ? 16'b0 : usb_data;
assign usb_data = (usb_rdwr == 1'b1) ? usb_dout : 16'bz;

assign usb_dout = sd_lpb_mode ? {lpb_usb_rd, dr_usb_rdy, lpb_error} : dr_usb_dout;
assign usb_rdy = sd_lpb_mode ? lpb_error : dr_usb_rdy;

assign ext_pin_oe = cons_mode & ~wireless_mode;
//assign ext_clk_in = ext_clk_oe_oddr ? 1'b0 : ext_clk;
//assign ext_clk = ext_clk_oe_oddr ? ext_clk_out : 1'bz;
IBUF 	ext_clk_i(.I(ext_clk), .O(ext_clk_in));
OBUFT ext_clk_o (.O (ext_clk),
              .I (ext_clk_out),
              .T (ext_clk_oe_oddr) // 1=tri-state, 0=enable
              );
//assign ext_trig_in = ext_trig_oe_oddr ? 1'b0 : ext_trig;
//assign ext_trig = ext_trig_oe_oddr ? ext_trig_out : 1'bz;
IBUF 	ext_trig_i(.I(ext_trig), .O(ext_trig_in));
OBUFT ext_trig_o (.O (ext_trig),
              .I (ext_trig_out),
              .T (ext_trig_oe_oddr) // 1=tri-state, 0=enable
              );
// --
// clock DCM
// --
wire	clk_120M;
wire	clk_48M;
wire	in_dcm_locked;
wire	core_dcm_locked;
wire	out_skew_dcm_locked;
wire	int_skew_dcm_locked;
in_dcm in_dcm (
    // Clock in ports
    .CLK_IN1(sys_clk),      // IN
    // Clock out ports
    .CLK_OUT1(),            // OUT
	 .CLK_OUT2(clk_120M),
    // Status and control signals
    .RESET(~sys_rst),       // IN
    .LOCKED(in_dcm_locked)  // OUT
);
core_dcm core_dcm (
    // Clock in ports
    .CLK_IN1(cclk),         // IN
    // Clock out ports
    .CLK_OUT1(usb_clk),     // OUT
    .CLK_OUT2(core_clk),    // OUT
    .CLK_OUT3(int_clk),     // OUT
	 .CLK_OUT4(int_clk_2x),  // OUT
	 .CLK_OUT5(out_clk),		 // OUT
    // Status and control signals
    .RESET(~in_dcm_locked), // IN
    .LOCKED(core_dcm_locked)// OUT
);
out_skew_dcm out_skew (
    // Clock in ports
    .CLK_IN1(clk_120M),     // IN
    .CLKFB_IN(sd_clk_fb),   // IN
    // Clock out ports
    .CLK_OUT1(),  // OUT
    .CLKFB_OUT(sd_clk_out),           // OUT
    // Status and control signals
    .RESET(~in_dcm_locked), // IN
    .LOCKED()               // OUT
);
int_skew_dcm int_skew (
    // Clock in ports
    .CLK_IN1(clk_120M),     // IN
    // Clock out ports
    .CLK_OUT1(sd_clk),      // OUT
    // Status and control signals
    .RESET(~in_dcm_locked), // IN
    .LOCKED()               // OUT
);

//wire	adc_clk_out;
//reg [1:0] core_clk_div;
//reg [1:0] int_clk_div;
//wire adc_clk_out = core_clk_div[1];
//wire int_clk_out = int_clk_div[1];
////wire adc_clk_out = out_clk;
//always @(posedge core_clk)
//begin
//	core_clk_div <= `D core_clk_div + 1'b1;
//end
//always @(posedge int_clk)
//begin
//	int_clk_div <= `D int_clk_div + 1'b1;
//end
wire	adc_clka;
wire	adc_clkb;
wire	adc_clka_out;
wire	adc_clkb_out;
adc_dcm adc_dcm
(// Clock in ports
	.CLK_IN1(out_clk),      // IN
	// Clock out ports
	.CLK_OUT1(adc_clka),     // OUT
	.CLK_OUT2(adc_clkb),     // OUT
	// Status and control signals
	.RESET(~core_dcm_locked),// IN
	.LOCKED()      // OUT
 );
ODDR2 #(
      .DDR_ALIGNMENT("C0"), // Sets output alignment to "NONE", "C0" or "C1"
      .INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
      .SRTYPE("ASYNC") // Specifies "SYNC" or "ASYNC" set/reset
) adc_clka_oddr (
      .Q(ext_clk_out),   // 1-bit DDR output data
      .C0(adc_clka),   // 1-bit clock input
      .C1(~adc_clka),   // 1-bit clock input
      .CE(1'b1), // 1-bit clock enable input
      .D0(1'b1), // 1-bit data input (associated with C0)
      .D1(1'b0), // 1-bit data input (associated with C1)
      .R(core_rst),   // 1-bit reset input
      .S(1'b0)    // 1-bit set input
);
ODDR2 #(
      .DDR_ALIGNMENT("C0"), // Sets output alignment to "NONE", "C0" or "C1"
      .INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
      .SRTYPE("ASYNC") // Specifies "SYNC" or "ASYNC" set/reset
) adc_clkb_oddr (
      .Q(ext_trig_out),   // 1-bit DDR output data
      .C0(adc_clkb),   // 1-bit clock input
      .C1(~adc_clkb),   // 1-bit clock input
      .CE(1'b1), // 1-bit clock enable input
      .D0(1'b1), // 1-bit data input (associated with C0)
      .D1(1'b0), // 1-bit data input (associated with C1)
      .R(core_rst),   // 1-bit reset input
      .S(1'b0)    // 1-bit set input
);
ODDR2 #(
      .DDR_ALIGNMENT("C0"), // Sets output alignment to "NONE", "C0" or "C1"
      .INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
      .SRTYPE("ASYNC") // Specifies "SYNC" or "ASYNC" set/reset
) clk_oe_oddr (
      .Q(ext_clk_oe_oddr),   // 1-bit DDR output data
      .C0(adc_clka),   // 1-bit clock input
      .C1(~adc_clka),   // 1-bit clock input
      .CE(1'b1), // 1-bit clock enable input
      .D0(~ext_pin_oe), // 1-bit data input (associated with C0)
      .D1(~ext_pin_oe), // 1-bit data input (associated with C1)
      .R(core_rst),   // 1-bit reset input
      .S(1'b0)    // 1-bit set input
);
ODDR2 #(
      .DDR_ALIGNMENT("C0"), // Sets output alignment to "NONE", "C0" or "C1"
      .INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
      .SRTYPE("ASYNC") // Specifies "SYNC" or "ASYNC" set/reset
) trig_oe_oddr (
      .Q(ext_trig_oe_oddr),   // 1-bit DDR output data
      .C0(adc_clkb),   // 1-bit clock input
      .C1(~adc_clkb),   // 1-bit clock input
      .CE(1'b1), // 1-bit clock enable input
      .D0(~ext_pin_oe), // 1-bit data input (associated with C0)
      .D1(~ext_pin_oe), // 1-bit data input (associated with C1)
      .R(core_rst),   // 1-bit reset input
      .S(1'b0)    // 1-bit set input
);

// --
// reset signal sync & stretch
// --
reset reset(
	// -- raw
	.core_clk(core_clk),
	.sample_clk(sample_clk),
	.sd_clk(sd_clk),
	.usb_clk(usb_clk),
	.sys_rst(~sys_rst),
	.sys_clr(~sys_clr),

	// -- sync
	.core_rst(core_rst),
	.sample_rst(sample_rst),
	.sd_rst(sd_rst),
	.sdram_rst_(sdram_rst_),
	.cfg_rst(cfg_rst),
	.usb_rst(usb_rst)
);

// --
// configuration through usb controller
// --
cfg cfg(
	// -- clock & reset
	.usb_clk(usb_clk),
	.usb_rst(cfg_rst),
	.core_clk(core_clk),
	.core_rst(core_rst),

	// -- usb config
	.usb_en(~usb_en),
	.usb_wr(~usb_rdwr),
	.usb_data(usb_din),

	.capture_done(capture_done),

	// -- config output
	.ext_clk_mode(ext_clk_mode),
	.test_mode(test_mode),
	.ext_test_mode(ext_test_mode),
	.sd_lpb_mode(sd_lpb_mode),
	.falling_mode(falling_mode),
	.cons_mode(cons_mode),
	.half_mode(half_mode),
	.quarter_mode(quarter_mode),
	.wireless_mode(wireless_mode),
	.sample_divider(sample_divider),

	.full_speed(full_speed),
	.trig_en(trig_en),
	.trig_stages(trig_stages),
	.trig_value_wr(trig_value_wr),
	.trig_mask_wr(trig_mask_wr),
	.trig_edge_wr(trig_edge_wr),
	.trig_count_wr(trig_count_wr),
	.trig_logic_wr(trig_logic_wr),
	.trig_mu(trig_mu),
	.trig_mask(trig_mask),
	.trig_value(trig_value),
	.trig_edge(trig_edge),
	.trig_count(trig_count),
	.trig_logic(trig_logic),

	.sample_depth(sample_depth),
	.sample_last_cnt(sample_last_cnt),
	.sample_real_start(sample_real_start),
	.trig_set_pos(trig_set_pos),
	.trig_set_pos_minus1(trig_set_pos_minus1),
	.after_trig_depth(after_trig_depth),

	.read_start(),
	.sd_saddr(),
	.sd_fbe(sd_fbe)
);

// --
// ext_data preprocessing and sampling
// --
reg	sys_en_sync0;
reg	sys_en_sync1;
reg	sample_rdy;
reg	sample_rdy_1T;
reg	sample_en;
wire	sd_init_done;
reg	sd_init_done_sync0;
reg	sd_init_done_sync1;

always @(posedge core_clk or posedge core_rst)
begin
	if (core_rst) begin
	    sys_en_sync0 <= `D 1'b0;
    sys_en_sync1 <= `D 1'b0;
    sd_init_done_sync0 <= `D 1'b0;
    sd_init_done_sync1 <= `D 1'b0;
    sample_rdy <= `D 1'b0;
    sample_rdy_1T <= `D 1'b0;
    sample_en <= `D 1'b0;
	end else begin
    sys_en_sync0 <= `D sys_en;
    sys_en_sync1 <= `D sys_en_sync0;
    sd_init_done_sync0 <= `D sd_init_done;
    sd_init_done_sync1 <= `D sd_init_done_sync0;
    sample_rdy <= `D sys_en_sync1 & sd_init_done_sync1;
    sample_rdy_1T <= `D sample_rdy;
    sample_en <= `D (sample_rdy & ~sample_rdy_1T) ? 1'b1 :
	    	    (capture_done | (~sample_rdy & sample_rdy_1T)) ? 1'b0 : sample_en;
	end
end
assign ext_out = wireless_mode ? sample_en : uart_tx;
sample sample(
	// -- clock & reset
	.core_clk(core_clk),
	.int_clk(int_clk),
	.int_clk_2x(int_clk_2x),
	.ext_clk(ext_clk_in),
	.sample_clk(sample_clk),
	.core_rst(core_rst),
	.sample_rst(sample_rst),

	// -- 
	.sample_en(sample_en & ~lpb_error),
	.ext_clk_mode(ext_clk_mode),
	.test_mode(test_mode),
	.ext_test_mode(ext_test_mode),
	.falling_mode(falling_mode),
	.half_mode(half_mode),
	.quarter_mode(quarter_mode),
	.cons_mode(cons_mode),
	.sample_divider(sample_divider),

	// --
	.ledn(ledn),
	.ext_data(ext_data),
	.sample_data(sample_data),
	.sample_valid(sample_valid)
);

// --
// trigger
// --
trigger trigger(
	// -- clock & reset
	.core_clk(core_clk),
	.core_rst(core_rst),

	// -- trigger configuration
	.full_speed(full_speed),
	.trig_en(trig_en),
	.trig_stages(trig_stages),
	.trig_value_wr(trig_value_wr),
	.trig_mask_wr(trig_mask_wr),
	.trig_edge_wr(trig_edge_wr),
	.trig_count_wr(trig_count_wr),
	.trig_logic_wr(trig_logic_wr),
	.trig_mu(trig_mu),
	.trig_mask(trig_mask),
	.trig_value(trig_value),
	.trig_edge(trig_edge),
	.trig_count(trig_count),
	.trig_logic(trig_logic),
	.sample_en(sample_en & ~lpb_error),
	
	// -- sample data in
	.sample_valid(sample_valid),
	.sample_data(sample_data),

	// -- control
	.capture_done(capture_done),
	
	// -- trigger output
	.trig_dly(trig_dly),
	.trig_hit(trig_hit)
);

// --
// capture data per trigger setting
// --
capture capture(
	// -- clock & reset
	.core_clk(core_clk),
	.core_rst(core_rst),

	// -- sample configuration
	.cons_mode(cons_mode),
	.wireless_mode(wireless_mode),
	.dso_setZero(dso_setZero),
	.sample_en(sample_en & ~lpb_error),
	.full_speed(full_speed),
	.sample_depth(sample_depth),
	.sample_last_cnt(sample_last_cnt),
	.sample_real_start(sample_real_start),
	.trig_set_pos(trig_set_pos),
	.trig_set_pos_minus1(trig_set_pos_minus1),
	.after_trig_depth(after_trig_depth),
	
	// -- sample data in
	.sample_valid(sample_valid),
	.sample_data(sample_data),

	// -- trigger control in
	.trig_en(trig_en),
	.trig_hit(trig_hit),
	.trig_dly(trig_dly),

	// -- capture control output
	.dso_setZero_done(dso_setZero_done),
	.trig_real_pos(trig_real_pos),
	.capture_done(capture_done),
	.sd_saddr(sd_saddr),
	.capture_valid(capture_valid),
	.capture_data(capture_data)
);

// --
// SDRAM loopback test mode
// --
loopback loopback(
	// -- clock & reset
	.core_clk(core_clk),
	.core_rst(core_rst),
	.sdram_clk(sd_clk),
	.sdram_rst(sd_rst),
	.usb_clk(usb_clk),
	.usb_rst(usb_rst),
	.sd_lpb_mode(sd_lpb_mode),
	.mux(sys_en),

	// -- control
	.sd_dcm0_locked(core_dcm_locked),
	.sd_dcm1_locked(1'b1),
	.sd_clk_rst(),
	.sd_clk_sel(),
	.sd_clk_en(),
	
	// -- write
	.sample_depth(lpb_sample_last_cnt),
	.capture_done(lpb_capture_done),
	.capture_valid(lpb_capture_valid),
	.capture_data(lpb_capture_data),
	.sdwr_done(wr_done),
	.sd_init_done(sd_init_done),

	// -- read
	.read_done(lpb_read_done),
	.lpb_read(lpb_read),
	.read_start(lpb_read_start),
	.sd_saddr(),
	.sd_fbe(),
	.usb_rd(lpb_usb_rd),
	.usb_rd_valid(1'b1),
	.usb_rdata(dr_usb_dout),
	.usb_rdy(dr_usb_rdy),

	// -- error
	.lpb_error(lpb_error)
);


// --
// write capture_data to sdramc
// --
assign dw_sample_last_cnt = sd_lpb_mode ? lpb_sample_last_cnt : sample_last_cnt;
assign dw_capture_done = sd_lpb_mode ? lpb_capture_done : capture_done;
assign dw_capture_valid = sd_lpb_mode ? lpb_capture_valid : capture_valid;
assign dw_capture_data = sd_lpb_mode ? lpb_capture_data : capture_data;
dwrite dwrite(
	// -- clock & reset
	.core_clk(core_clk),
	.core_rst(core_rst),
	.sdram_clk(sd_clk),
	.sdram_rst(sd_rst),

	.wfifo_full(usb_overflow),
	.cons_mode(cons_mode),

	// -- capture
	.sample_en(sample_en),
	.sample_last_cnt(dw_sample_last_cnt),
	.capture_done(dw_capture_done),
	.capture_valid(dw_capture_valid),
	.capture_data(dw_capture_data),

	// -- sdramc
	.wr_done(wr_done),
   .wr_req(wr_req),
   .wr_valid(wr_valid),
   .wr_addr(wr_addr),
	.wr_data(wr_data)
);

// --
// cons buffer
// --
cons_buf cons_buf(
	// -- Clock & Reset
	.core_clk(core_clk),
	.core_rst(core_rst),
	.sdram_clk(sd_clk),
	.sd_rst(sd_rst),

	// --
	.cons_mode(cons_mode),

	// -- data in
	.sample_en(sample_en),
	.capture_done(capture_done),
	.capture_valid(capture_valid),
	.capture_data(capture_data),
	.wr_done(wr_done),

	// -- dread
	.rd_req(rd_req),
	.rd_valid(rd_valid),
	.rd_addr(rd_addr),
	.rd_rdy(rd_rdy),
	.rd_data(rd_data),

	// -- DSO config
	.dso_sampleDivider(dso_sampleDivider),
	.dso_triggerPos(dso_triggerPos),
	.dso_triggerSlope(dso_triggerSlope),
	.dso_triggerSource(dso_triggerSource),
	.dso_triggerValue(dso_triggerValue),
	
	// -- sdram
	// -- dread
	.read_start(read_start),
	.sd_rd_req(sd_rd_req),
	.sd_rd_valid(sd_rd_valid),
	.sd_rd_addr(sd_rd_addr),
	.sd_rd_rdy(sd_rd_rdy),
	.sd_rd_data(sd_rd_data)
);

// --
// sdramc
// --
mem_ctrl sdramc(
	// -- Clock & Reset
	.sdram_clk(sd_clk),
	.sdram_rst_(sdram_rst_),

	// -- dwrite
	.wr_req(wr_req),
	.wr_valid(wr_valid),
	.wr_addr(wr_addr),
	.wr_data(wr_data),

	// -- dread
	.rd_req(sd_rd_req),
	.rd_valid(sd_rd_valid),
	.rd_addr(sd_rd_addr),
	.rd_rdy(sd_rd_rdy),
	.rd_data(sd_rd_data),

	.sd_init_done(sd_init_done),
	    
	// -- From/to SDRAM Signals
	.sdram_addr(sd_addr),
	.sdram_ba(sd_ba), 
	.sdram_dq(sd_dq),
	.sdram_ras_(sd_ras_),
	.sdram_cas_(sd_cas_),
	.sdram_we_(sd_we_),
	.sdram_dqml(sd_dqml),
	.sdram_dqmh(sd_dqmh),	
	.sdram_cke(sd_cke),
	.sdram_cs_(sd_cs_)
);

// --
// read capture data to usb controller
// --
wire	usb_rd;
wire	dr_sys_en;
wire	[31:0]	dr_sample_last_cnt;
assign usb_rd = sd_lpb_mode ? lpb_usb_rd : ~usb_en & usb_rdwr;
assign dr_sys_en = sd_lpb_mode ? lpb_read : sys_en;
assign dr_sample_last_cnt = sd_lpb_mode ? lpb_sample_last_cnt : sample_last_cnt;
dread dread(
	// --clock & reset
	.sdram_clk(sd_clk),
	.sdram_rst(sd_rst),
	.usb_clk(usb_clk),
	.usb_rst(usb_rst),

	// -- config
	.sys_en(dr_sys_en),
	.read_start(read_start),
	.sd_saddr(sd_saddr),
	.trig_real_pos(trig_real_pos),
	.sd_fbe(sd_fbe),
	.sample_last_cnt(dr_sample_last_cnt),
	.half_mode(half_mode),
	.quarter_mode(quarter_mode),
	.sd_lpb_mode(sd_lpb_mode),

	// -- usb controller
	.usb_rd(usb_rd),
	.usb_rd_valid(),
	.usb_rdata(dr_usb_dout),
	.usb_rdy(dr_usb_rdy),

	// -- sdram 
	.rd_req(rd_req),
	.rd_valid(rd_valid),
	.rd_addr(rd_addr),
	.rd_rdy(rd_rdy),
	.rd_data(rd_data)
);

//assign uart_rx = ext_trig_in;
assign uart_rx = 1'b1;
dso_ctl dso_ctl(
	// --clock & reset
	.core_clk(core_clk),
	.core_rst(core_rst),
	
	// -- i2c
	.scl(scl),
	.sda(sda),

	// -- DSO config
	.dso_setZero(dso_setZero),
	.dso_sampleDivider(dso_sampleDivider),
	.dso_triggerPos(dso_triggerPos),
	.dso_triggerSlope(dso_triggerSlope),
	.dso_triggerSource(dso_triggerSource),
	.dso_triggerValue(dso_triggerValue),
	
	// -- uart
	.uart_rx(uart_rx),
	.uart_tx(uart_tx)
);

endmodule
