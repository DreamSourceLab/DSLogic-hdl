// file: out_skew_dcm.v
// 
// (c) Copyright 2008 - 2011 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
//----------------------------------------------------------------------------
// User entered comments
//----------------------------------------------------------------------------
// None
//
//----------------------------------------------------------------------------
// "Output    Output      Phase     Duty      Pk-to-Pk        Phase"
// "Clock    Freq (MHz) (degrees) Cycle (%) Jitter (ps)  Error (ps)"
//----------------------------------------------------------------------------
// CLK_OUT1___120.005______0.000______50.0______200.000_____60.000
//
//----------------------------------------------------------------------------
// "Input Clock   Freq (MHz)    Input Jitter (UI)"
//----------------------------------------------------------------------------
// __primary_________120.000____________0.010

`timescale 1ps/1ps

(* CORE_GENERATION_INFO = "out_skew_dcm,clk_wiz_v3_2,{component_name=out_skew_dcm,use_phase_alignment=true,use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=false,feedback_source=FDBK_AUTO_OFFCHIP,primtype_sel=DCM_SP,num_out_clk=1,clkin1_period=8.333,clkin2_period=8.333,use_power_down=false,use_reset=true,use_locked=true,use_inclk_stopped=false,use_status=false,use_freeze=false,use_clk_valid=false,feedback_type=SINGLE,clock_mgr_type=MANUAL,manual_override=true}" *)
module out_skew_dcm
 (// Clock in ports
  input         CLK_IN1,
  input         CLKFB_IN,
  // Clock out ports
  output        CLK_OUT1,
  output        CLKFB_OUT,
  // Status and control signals
  input         RESET,
  output        LOCKED
 );

  // Input buffering
  //------------------------------------
  assign clkin1 = CLK_IN1;

  wire clkfb_ibuf2bufio2fb;
  wire clkfb_in_buf_out;

  // feedback clock input buffer
  IBUFG clkfb_ibufg
   (.O  (clkfb_ibuf2bufio2fb),
    .I  (CLKFB_IN));

  // bufio2fb instantiation
  BUFIO2FB #(.DIVIDE_BYPASS("TRUE")) clkfb_bufio2fb
   (.O(clkfb_in_buf_out),
    .I(clkfb_ibuf2bufio2fb));

  // Clocking primitive
  //------------------------------------

  // Instantiation of the DCM primitive
  //    * Unused inputs are tied off
  //    * Unused outputs are labeled unused
  wire        psdone_unused;
  wire        locked_int;
  wire [7:0]  status_int;
  wire clkfb;
  wire clk0;

  DCM_SP
  #(.CLKDV_DIVIDE          (2.000),
    .CLKFX_DIVIDE          (1),
    .CLKFX_MULTIPLY        (4),
    .CLKIN_DIVIDE_BY_2     ("FALSE"),
    .CLKIN_PERIOD          (8.333),
    .CLKOUT_PHASE_SHIFT    ("NONE"),
    .CLK_FEEDBACK          ("1X"),
    .DESKEW_ADJUST         ("SYSTEM_SYNCHRONOUS"),
    .PHASE_SHIFT           (0),
    .STARTUP_WAIT          ("FALSE"))
  dcm_sp_inst
    // Input clock
   (.CLKIN                 (clkin1),
    .CLKFB                 (clkfb_in_buf_out),
    // Output clocks
    .CLK0                  (clk0),
    .CLK90                 (),
    .CLK180                (),
    .CLK270                (),
    .CLK2X                 (),
    .CLK2X180              (),
    .CLKFX                 (),
    .CLKFX180              (),
    .CLKDV                 (),
    // Ports for dynamic phase shift
    .PSCLK                 (1'b0),
    .PSEN                  (1'b0),
    .PSINCDEC              (1'b0),
    .PSDONE                (),
    // Other control and status signals
    .LOCKED                (locked_int),
    .STATUS                (status_int),
 
    .RST                   (RESET),
    // Unused pin- tie low
    .DSSEN                 (1'b0));

    assign LOCKED = locked_int;

  // Output buffering
  //-----------------------------------
  wire clkfb_bufg_out;
  wire clkfb_bufg_out_n;
  wire clkfb_oddr_out;
  // Instantiate bufg on fbout
  BUFG clkfbout_bufg
   (.O  (clkfb_bufg_out),
    .I  (clk0));
  // Locally invert clkfb_bufg_out for use in ODDR2
  assign clkfb_bufg_out_n = ~clkfb_bufg_out;

  // Forward the feedback clock off-chip
  ODDR2 clkfbout_oddr
   (.Q  (clkfb_oddr_out),
    .C0 (clkfb_bufg_out),
    .C1 (clkfb_bufg_out_n),
    .CE (1'b1),
    .D0 (1'b1),
    .D1 (1'b0),
    .R  (1'b0),
    .S  (1'b0));

  assign CLKFB_OUT = clkfb_oddr_out;
  BUFG clkout1_buf
   (.O   (CLK_OUT1),
    .I   (clk0));




endmodule
