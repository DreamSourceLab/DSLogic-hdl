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

module sdram_io (
    // -- Clock
    input               sdram_clk,
    // -- From/to Internal Signals
    input       [12:0]  sdram_addr,
    input       [1:0]   sdram_ba, 
    input       [15:0]  sdram_dqo,
    output  reg [15:0]  sdram_dqi,
    input               sdram_dq_oe,
    input               sdram_ras_,
    input               sdram_cas_,
    input               sdram_we_,
	 input					sdram_dqm,
    input               sdram_cke,
    input               sdram_cs_,
    // -- From/to SDRAM Signals
    output      [12:0]  pad_addr,
    output      [1:0]   pad_ba, 
    output      [15:0]  pad_dqo,
    input       [15:0]  pad_dqi,
    output      [15:0]  pad_dq_oe,
    output              pad_ras_,
    output              pad_cas_,
    output              pad_we_,
	 output					pad_dqml,
	 output					pad_dqmh,
    output              pad_cke,
    output              pad_cs_
);

/********************************************************/
// --  Internal Signals                                   

reg     [12:0]  iob_addr;
reg     [1:0]   iob_ba;
reg     [15:0]  iob_dqo;
wire    [15:0]  iob_dqi;
reg     [15:0]  iob_dq_oe;
reg             iob_ras_;
reg             iob_cas_;
reg             iob_we_;
reg				 iob_dqml;
reg				 iob_dqmh;
reg             iob_cke;
reg             iob_cs_;

assign pad_dqo = iob_dqo;
assign pad_dq_oe = iob_dq_oe;
assign iob_dqi = pad_dqi;

always @(posedge sdram_clk) begin
    iob_addr    <= #5 sdram_addr;
    iob_ba      <= #5 sdram_ba;
    //sdram_dqi   <= #5 iob_dqi;
    iob_dqo     <= #5 sdram_dqo;
    iob_ras_    <= #5 sdram_ras_;
    iob_cas_    <= #5 sdram_cas_;
    iob_we_     <= #5 sdram_we_;
	 iob_dqml	 <= #5 sdram_dqm;
	 iob_dqmh	 <= #5 sdram_dqm;
    iob_cke     <= #5 sdram_cke;
    iob_cs_     <= #5 sdram_cs_;
end

always @(posedge sdram_clk) begin
    iob_dq_oe   <= #5 {16{sdram_dq_oe}};
end
always @(posedge sdram_clk) begin
	sdram_dqi	 <= #5 iob_dqi;
end
    
OBUF    addr0_obuf (.I(iob_addr[0]), .O(pad_addr[0]));
OBUF    addr1_obuf (.I(iob_addr[1]), .O(pad_addr[1]));
OBUF    addr2_obuf (.I(iob_addr[2]), .O(pad_addr[2]));
OBUF    addr3_obuf (.I(iob_addr[3]), .O(pad_addr[3]));
OBUF    addr4_obuf (.I(iob_addr[4]), .O(pad_addr[4]));
OBUF    addr5_obuf (.I(iob_addr[5]), .O(pad_addr[5]));
OBUF    addr6_obuf (.I(iob_addr[6]), .O(pad_addr[6]));
OBUF    addr7_obuf (.I(iob_addr[7]), .O(pad_addr[7]));
OBUF    addr8_obuf (.I(iob_addr[8]), .O(pad_addr[8]));
OBUF    addr9_obuf (.I(iob_addr[9]), .O(pad_addr[9]));
OBUF    addr10_obuf (.I(iob_addr[10]), .O(pad_addr[10]));
OBUF    addr11_obuf (.I(iob_addr[11]), .O(pad_addr[11]));
OBUF    addr12_obuf (.I(iob_addr[12]), .O(pad_addr[12]));

OBUF    ba0_obuf (.I(iob_ba[0]), .O(pad_ba[0]));
OBUF    ba1_obuf (.I(iob_ba[1]), .O(pad_ba[1]));

OBUF    ras_obuf (.I(iob_ras_), .O(pad_ras_));
OBUF    cas_obuf (.I(iob_cas_), .O(pad_cas_));
OBUF    we_obuf (.I(iob_we_), .O(pad_we_));
OBUF    dqml_obuf (.I(iob_dqml), .O(pad_dqml));
OBUF    dqmh_obuf (.I(iob_dqmh), .O(pad_dqmh));
OBUF    cke_obuf (.I(iob_cke), .O(pad_cke));
OBUF    cs_obuf (.I(iob_cs_), .O(pad_cs_));
    
endmodule /* module sdram_io (*/
