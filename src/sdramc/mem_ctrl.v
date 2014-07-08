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

module mem_ctrl (
	// -- Clock & Reset
	input   sdram_clk,
	input   sdram_rst_,

	// -- dwrite
    	input	       	wr_req,
    	output         	wr_valid,
    	input	[31:0]  wr_addr,
    	input  	[15:0]  wr_data,

	// -- dread
	input		rd_req,
	output		rd_valid,
	input	[31:0]	rd_addr,
	output		rd_rdy,
	output	[15:0]	rd_data,

	output		sd_init_done,
    
	// -- SDRAM Signals
	output  [12:0]  sdram_addr,
	output  [1:0]   sdram_ba, 
	inout   [15:0]  sdram_dq,
	output          sdram_ras_,
	output          sdram_cas_,
	output          sdram_we_,
	output  	 		 sdram_dqml,
	output			 sdram_dqmh,
	output          sdram_cke,
	output          sdram_cs_
);

// --
// internal signals definition
// --
wire	[15:0]	sdram_dqo;
wire	[15:0]	sdram_dqi;
wire	[15:0]	sdram_dq_oe;

wire            STOP_CLK;
wire            PAA;
wire            SET_MODE;
wire    [2:0]   BLK_SIZE;           // Burst Length
                                    // 3'b000: 1,   3'b001: 2,  3'b010: 4,  3'b011: 8
                                    // if IS_SEQ == 1'b0, 3'b111: full page
wire            IS_SEQ;             // Burst Type
                                    // 1'b0: Sequential,    1'b1: Interleaved
wire            MODULE_BK_NUM;      // Not Used
wire    [1:0]   ROW_SIZE;           // 2'b00 : A0-A10,   2'b01 : A0-A11, 2'b10 : A0-A12
wire    [1:0]   BIT_SIZE;           // 2'b00 : 4,        2'b01 : 8,      2'b10 : 16,      2'b11 : 32
wire            BK_SIZE;            // 1'b0  : B0,       1'b1 : B0-B1
wire    [2:0]   COL_SIZE;           // 3'b000: A0-A7     3'b001: A0-A8   3'b010: A0-A9
                                    // 3'b011: A0-A9,A11 3'b100: A0-A9, A11, A12
wire    [1:0]   tRCD;
wire    [1:0]   tCAS;
wire    [1:0]   tRP;
wire    [2:0]   tRAS;
wire    [11:0]  tREF;
wire    [3:0]   tRC;

wire	[31:0]	sys_addr;
wire		sys_rd;
wire		sys_wr;
wire	[15:0]	sys_wdata;
wire	[15:0]	sys_rdata;
wire		sys_rd_rdy;
wire		sys_burst_rdy;

wire	[12:0]  isdram_addr;
wire	[1:0]   isdram_ba; 
wire	[15:0]  isdram_dqi;
wire	[15:0]  isdram_dqo;
wire          isdram_dq_oe;
wire	        isdram_ras_;
wire	        isdram_cas_;
wire	        isdram_we_;
wire			  isdram_dqm;
wire	        isdram_cke;
wire	        isdram_cs_;

assign sd_init_done = PAA;

// -- 
// dwrite/dread access mux
// --
assign sys_addr = wr_req ? wr_addr : rd_addr;
assign sys_rd = rd_req;
assign sys_wr = wr_req;
assign sys_wdata = wr_data;
assign rd_data = sys_rdata;
assign wr_valid = wr_req & sys_burst_rdy;
assign rd_valid = rd_req & sys_burst_rdy;
assign rd_rdy = sys_rd_rdy;

// --
// sdram_clk output
// --
assign sdram_dq[0]     = sdram_dq_oe[0] ? sdram_dqo[0] : 1'Hz;
assign sdram_dq[1]     = sdram_dq_oe[1] ? sdram_dqo[1] : 1'Hz;
assign sdram_dq[2]     = sdram_dq_oe[2] ? sdram_dqo[2] : 1'Hz;
assign sdram_dq[3]     = sdram_dq_oe[3] ? sdram_dqo[3] : 1'Hz;
assign sdram_dq[4]     = sdram_dq_oe[4] ? sdram_dqo[4] : 1'Hz;
assign sdram_dq[5]     = sdram_dq_oe[5] ? sdram_dqo[5] : 1'Hz;
assign sdram_dq[6]     = sdram_dq_oe[6] ? sdram_dqo[6] : 1'Hz;
assign sdram_dq[7]     = sdram_dq_oe[7] ? sdram_dqo[7] : 1'Hz;
assign sdram_dq[8]     = sdram_dq_oe[8] ? sdram_dqo[8] : 1'Hz;
assign sdram_dq[9]     = sdram_dq_oe[9] ? sdram_dqo[9] : 1'Hz;
assign sdram_dq[10]     = sdram_dq_oe[10] ? sdram_dqo[10] : 1'Hz;
assign sdram_dq[11]     = sdram_dq_oe[11] ? sdram_dqo[11] : 1'Hz;
assign sdram_dq[12]     = sdram_dq_oe[12] ? sdram_dqo[12] : 1'Hz;
assign sdram_dq[13]     = sdram_dq_oe[13] ? sdram_dqo[13] : 1'Hz;
assign sdram_dq[14]     = sdram_dq_oe[14] ? sdram_dqo[14] : 1'Hz;
assign sdram_dq[15]     = sdram_dq_oe[15] ? sdram_dqo[15] : 1'Hz;
assign sdram_dqi = sdram_dq;

// --
// sdram parameter
// --
assign STOP_CLK         = 1'b0;     // Never Stop Clock
assign BLK_SIZE         = 3'b000;   // Burst length = 8   
assign IS_SEQ           = 1'b0;     // Sequential                                 
assign MODULE_BK_NUM    = 1'b1;     
assign ROW_SIZE         = 2'b10;    // A0-A12
assign BIT_SIZE         = 2'b10;    // 16
assign BK_SIZE          = 1'b1;     // B0-B1
assign COL_SIZE         = 3'b001;   // A0-A8
assign tRCD             = 2'b10;    // tRCD - 1
assign tCAS             = 2'b11;
assign tRP              = 2'b11;
assign tRAS             = 3'b110;
assign tREF             = 12'd257;
assign tRC              = 4'b1000;

// --
// instant
// --
sdram_init  sdram_init_x(
    .sdram_clk(sdram_clk),    .sdram_rst_(sdram_rst_),
    //.CKE_IN(CKE),       .CKE_OUT(CKE_OUT),
    .PAA(PAA),          .SET_MODE(SET_MODE)
);

sdram_ctl sdram_ctl(
    .CLK(sdram_clk),  .RST_(sdram_rst_),
                                
    // REG interface
    .STOP_CLK(STOP_CLK), .PAA(PAA), .SET_MODE(SET_MODE), .BLK_SIZE(BLK_SIZE), .IS_SEQ(IS_SEQ), 
    .MODULE_BK_NUM(MODULE_BK_NUM), .ROW_SIZE(ROW_SIZE), .COL_SIZE(COL_SIZE[1:0]), .BK_SIZE(BK_SIZE), .BIT_SIZE(BIT_SIZE), 
    .tRCD(tRCD), .tCAS(tCAS), .tRAS(tRAS), .tRP(tRP),
    .tREF(tREF), .tRC(tRC),  //note: tRC minus 1
    
    // from/to host side    				
    .ADDR(sys_addr), .RD(sys_rd), .WR(sys_wr), .DAT_I(sys_wdata), .DAT_O(sys_rdata),
    .RD_DAT_RDY(sys_rd_rdy), .BURST_RDY(sys_burst_rdy), .RW(),
    .CPU_GNT_(1'b0), .MUX_EN(),
    
    // from/to DIMM
    .CKE(isdram_cke), .CS_(isdram_cs_),
    .RAS_(isdram_ras_), .CAS_(isdram_cas_), .WE_(isdram_we_), .DQM(isdram_dqm),
    .BA(isdram_ba),  .DIMM_ADDR(isdram_addr),    
    .DQ_I(isdram_dqi), .DQ_O(isdram_dqo), .DQ_OE(isdram_dq_oe)
//    .CKE(sdram_cke), .CS_(sdram_cs_),
//    .RAS_(sdram_ras_), .CAS_(sdram_cas_), .WE_(sdram_we_), .DQM(sdram_dqm),
//    .BA(sdram_ba),  .DIMM_ADDR(sdram_addr),    
//    .DQ_I(sdram_dqi), .DQ_O(sdram_dqo), .DQ_OE(sdram_dq_oe)
);

sdram_io sdram_io(
    // -- Clock
    .sdram_clk(sdram_clk),

    // -- From/to Internal Signals
    .sdram_addr(isdram_addr), .sdram_ba(isdram_ba), .sdram_dqo(isdram_dqo),
    .sdram_dqi(isdram_dqi), .sdram_dq_oe(isdram_dq_oe), .sdram_ras_(isdram_ras_),
    .sdram_cas_(isdram_cas_), .sdram_we_(isdram_we_), .sdram_dqm(isdram_dqm), 
	 .sdram_cke(isdram_cke), .sdram_cs_(isdram_cs_),

    // -- From/to SDRAM Signals
    .pad_addr(sdram_addr), .pad_ba(sdram_ba), .pad_dqo(sdram_dqo), 
	 .pad_dqi(sdram_dqi), .pad_dq_oe(sdram_dq_oe), .pad_ras_(sdram_ras_), 
	 .pad_cas_(sdram_cas_), .pad_we_(sdram_we_), .pad_dqml(sdram_dqml), .pad_dqmh(sdram_dqmh),
    .pad_cke(sdram_cke), .pad_cs_(sdram_cs_)
);

endmodule /* module mem_ctrl (*/
