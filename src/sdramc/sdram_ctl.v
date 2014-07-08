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

module sdram_ctl(
    CLK, RST_,
                                // REG interface
    STOP_CLK, PAA, SET_MODE, BLK_SIZE, IS_SEQ, 
    MODULE_BK_NUM, ROW_SIZE, COL_SIZE, BK_SIZE, BIT_SIZE, 
    tRCD, tCAS, tRAS, tRP,
    tREF, tRC,  //note: tRC minus 1
    				// from/to host side    				
    ADDR, RD, WR, DAT_I, DAT_O,
    RD_DAT_RDY, BURST_RDY, RW, 
    CPU_GNT_, MUX_EN,
    				// from/to DIMM
    CKE, CS_,
    RAS_, CAS_, WE_, DQM,
    BA,  DIMM_ADDR,    
    DQ_I, DQ_O, DQ_OE );

input CLK, RST_;

input  STOP_CLK, PAA, SET_MODE;
input  [2:0] BLK_SIZE;
input        IS_SEQ, MODULE_BK_NUM;
input  [1:0] ROW_SIZE,  // 2'b00 : A0-A10,   2'b01 : A0-A11, 2'b10 : A0-A12
             BIT_SIZE;  // 2'b00 : 4,        2'b01 : 8,      2'b10 : 16,      2'b11 : 32
input        BK_SIZE;   // 1'b0  : B0,        1'b1 : B0-B1
input  [1:0] COL_SIZE;  // 3'b000: A0-A7     3'b001: A0-A8   3'b010: A0-A9
                         // 3'b011: A0-A9,A11 3'b100: A0-A9, A11, A12
input   [1:0] tRCD, tCAS, tRP;
input   [2:0] tRAS;
input  [11:0] tREF;
input   [3:0] tRC;

input  [31:0] ADDR;
input  RD, WR;
input  [15:0] DAT_I;
output [15:0] DAT_O;
output RD_DAT_RDY, BURST_RDY;
output RW;
input  CPU_GNT_;
output MUX_EN;


output  CKE, RAS_, CAS_, WE_;
output  CS_;
output  DQM;
output  [1:0] BA;
output [12:0] DIMM_ADDR;
input  [15:0] DQ_I;
output [15:0] DQ_O;
output DQ_OE;

/*=============================================================
 +    Parameters definition
 +=============================================================*/
//parameter SD_IDLE       = 0,  SD_SET_MODE   = 12,
////        SD_SELF_REF   = 2,  SD_POWER_DOWN = 4,
//          SD_AUTO_REF   = 3,  SD_ROW_ACTIVE = 9,
//          SD_READ       = 8,  SD_WRITE      = 1,
//          SD_BURST_TERM = 13, SD_PRECHARGE  = 11,
//          SD_RD2PRECH   = 10;
//          
//reg [3:0] D_SD, Q_SD;
parameter SD_IDLE       = 9'b000000001;
parameter SD_SET_MODE   = 9'b000000010;
parameter SD_AUTO_REF   = 9'b000000100;
parameter SD_ROW_ACTIVE = 9'b000001000;
parameter SD_READ       = 9'b000010000;
parameter SD_WRITE      = 9'b000100000;
parameter SD_BURST_TERM = 9'b001000000;
parameter SD_PRECHARGE  = 9'b010000000;
parameter SD_RD2PRECH   = 9'b100000000;
          
reg [8:0] D_SD, Q_SD;
/*=============================================================
 +    Z variables of main state machine
 +=============================================================*/
reg  q_precharge, q_idle, q_burst_term,     
     q_rd,        q_wr,   q_auto_ref, q_row_active,
     q_set_mode,  q_rd2prech;
reg  d_precharge, d_idle, d_set_mode, d_burst_term,
     d_auto_ref;
     
wire q_rw = q_rd | q_wr;
wire d_wr = (D_SD == SD_WRITE);
//wire d_wr         = D_SD[5];
wire d_row_active = (D_SD == SD_ROW_ACTIVE); 
/*=============================================================
 +    init_finished
 +=============================================================*/
reg init_finished = 1'b0, d_init_finished;
reg q_init_cnt = 1'b0,    d_init_cnt;
wire RC_CNT_EQ_0;
always @(posedge CLK)
    q_init_cnt <= `D d_init_cnt;

always @( q_init_cnt or init_finished or q_auto_ref or RC_CNT_EQ_0 ) begin
    d_init_cnt = q_init_cnt;
    if( !init_finished & q_auto_ref & RC_CNT_EQ_0 ) d_init_cnt = 1;
end
    
always @(posedge CLK)
    init_finished <= `D d_init_finished;

always @(init_finished or q_init_cnt or q_auto_ref or RC_CNT_EQ_0 ) begin
    d_init_finished = init_finished;
    if( q_init_cnt & q_auto_ref & RC_CNT_EQ_0 ) d_init_finished = 1;
end

/*=============================================================
 +    set_mode_finished
 +=============================================================*/
reg set_mode_finished = 1'b0;
always  @(posedge CLK)
	if(q_set_mode) set_mode_finished <= 1;

/*=============================================================
 +    Counters
 +=============================================================*/
wire start_ref_timing;
reg  inhibit_new_cmd_reg = 1'b0;
wire inhibit_new_cmd = inhibit_new_cmd_reg;
assign RW =  RD | WR;

reg  D_RW = 1'b0;
wire D_RWt = D_RW;
wire st_break_rw = !RW & D_RWt;
always @(posedge CLK)
    D_RW <= RW;

reg  break_rw = 1'b0;
always @(posedge CLK)
    if( q_row_active & st_break_rw )          break_rw <= 1;
    else if( d_idle | q_precharge & d_row_active ) break_rw <= 0;   // q_idle -->d_idle

wire RP_CNT_EQ_0;

reg  [1:0] TIMING_CNT = 2'b0;
wire [1:0] TIMING_CNT_DEC_1 = (TIMING_CNT - 1'b1);
wire       TIMING_CNT_EQ_0  = (TIMING_CNT == 2'b0);
wire       TIMING_CNT_EQ_1  = (TIMING_CNT == 2'd1);
wire start_row_active = ( q_idle | q_precharge & RP_CNT_EQ_0 ) & !inhibit_new_cmd & RW;
always @(posedge CLK)
    if(start_row_active) TIMING_CNT <= tRCD;   // tRCD - 1
    else if(!TIMING_CNT_EQ_0) TIMING_CNT <= TIMING_CNT_DEC_1;

reg  S_PAA = 1'b0;
wire start_init_prech = PAA & !S_PAA;
always @( posedge CLK ) S_PAA <= `D PAA;
    
reg  [1:0] RP_CNT = 2'b0;
wire [1:0] RP_CNT_DEC_1 = (RP_CNT - 1'b1);
assign     RP_CNT_EQ_0  = (RP_CNT == 2'b0);
wire start_norm_precharge  = ( q_rd | q_burst_term | q_row_active | q_rd2prech ) & d_precharge;
wire start_precharge  = start_init_prech | start_norm_precharge;
always @(posedge CLK)
    if(!RST_)	               RP_CNT <= 2'h3;
    else if(start_precharge) RP_CNT <= tRP;    // tRP - 1
    else if(!RP_CNT_EQ_0)    RP_CNT <= RP_CNT_DEC_1;

reg  [3:0] RC_CNT = 4'b0;
wire [3:0] RC_CNT_DEC_1 = (RC_CNT - 1'b1);
assign  RC_CNT_EQ_0  = (RC_CNT == 4'b0);
always @( posedge CLK)
    if(start_ref_timing) RC_CNT <= tRC;
    else if( !RC_CNT_EQ_0 )   RC_CNT <= RC_CNT_DEC_1;

reg  [2:0] RAS_CNT = 3'b0;
wire [2:0] RAS_CNT_DEC_1 = (RAS_CNT - 1'b1);
wire       RAS_CNT_EQ_0  = (RAS_CNT == 3'b0);
wire   PRECHARGE_EN = RAS_CNT_EQ_0;
always @(posedge CLK)
	if(start_row_active) RAS_CNT <= tRAS;
	else if(!RAS_CNT_EQ_0) 	  RAS_CNT <= RAS_CNT_DEC_1;

//reg  [1:0] CAS_CNT;
//wire [1:0] CAS_CNT_DEC_1 = CAS_CNT - 1;
//wire       CAS_CNT_EQ_0  = CAS_CNT == 0;
//wire       CAS_CNT_EQ_1  = CAS_CNT == 1;
//wire start_fst_rd = RD & TIMING_CNT_EQ_0 & q_row_active & !break_rw;
//wire start_fst_wr = WR & TIMING_CNT_EQ_0 & q_row_active & !break_rw;
//always @(posedge CLK)
//    if( !RST_ )              CAS_CNT <= 0;
//    else if( start_fst_rd )  CAS_CNT <= tCAS;
//    else if( !CAS_CNT_EQ_0 ) CAS_CNT <= CAS_CNT_DEC_1;

reg  [2:0] CAS_CNT = 3'b0;
wire [2:0] CAS_CNT_DEC_1 = (CAS_CNT - 1'b1);
wire       CAS_CNT_EQ_0  = (CAS_CNT == 3'd0);
wire       CAS_CNT_EQ_1  = (CAS_CNT == 3'd1);
wire start_fst_rd = RD & TIMING_CNT_EQ_0 & q_row_active & !break_rw;
wire start_fst_wr = WR & TIMING_CNT_EQ_0 & q_row_active & !break_rw;
always @(posedge CLK)
    if( start_fst_rd )  CAS_CNT <= tCAS + 2'b10;
    else if( !CAS_CNT_EQ_0 ) CAS_CNT <= CAS_CNT_DEC_1;        

reg  [11:0] REF_CNT = 12'b0;
wire [11:0] REF_CNTt = REF_CNT;
wire [11:0] REF_CNT_DEC_1 = (REF_CNT - 1'b1);
//wire REF_CNT_EQ_0  = (REF_CNT == 12'b0);
reg  REF_CNT_EQ_0 = 1'b0;
always @(posedge CLK)
    if(REF_CNT == 12'b0) REF_CNT_EQ_0 <= `D 1'b1;
	 else if (d_auto_ref) REF_CNT_EQ_0 <= `D 1'b0;
	 
//assign start_ref_timing = REF_CNT_EQ_0 | !init_finished & q_idle & d_auto_ref;
assign start_ref_timing = (REF_CNT_EQ_0 & d_auto_ref) | (!init_finished & q_idle & d_auto_ref);

always @( posedge CLK)
    if( !PAA )         REF_CNT <= `D 12'hFFF;
    else if( REF_CNT_EQ_0 ) REF_CNT <= `D tREF;
    else                    REF_CNT <= `D REF_CNT_DEC_1;

always @( posedge CLK)
    if( REF_CNTt == 10 ) inhibit_new_cmd_reg <= 1;
    //else if( REF_CNT_EQ_0 )   inhibit_new_cmd_reg <= 0;
    else if( REF_CNTt == (tREF - 3) )   inhibit_new_cmd_reg <= 0;
        
reg inhibit_rw_reg = 1'b0;
wire inhibit_rw = inhibit_rw_reg;
always @(posedge CLK)
    if( q_rw & inhibit_new_cmd ) inhibit_rw_reg <= 1'b1;
    else                              inhibit_rw_reg <= 1'b0;

reg s_init_finished = 1'b0;
wire st_init_finished = !s_init_finished & init_finished;
always @( posedge CLK ) 
    s_init_finished <= `D init_finished;

reg [5:0] M_CNT;
wire M_CNT_EQ_0 = M_CNT == 0;
wire MUX_EN = M_CNT_EQ_0 & q_idle;
always @( posedge CLK)
    if( !RST_ )                 M_CNT <= `D 6'h2F;
    else if( st_init_finished ) M_CNT <= `D 6'h00;
    else if( REF_CNT == 32)     M_CNT <= `D 6'h2F;
    else if(  !M_CNT_EQ_0 )     M_CNT <= `D (M_CNT - 1'b1);
    
/*=============================================================
 +    BURST_CNT :  BURST_CNT
 +=============================================================*/
wire [2:0] BLK_LENGTH = BLK_SIZE == 3'b000 ? 0 :
                        BLK_SIZE == 3'b001 ? 1 :
                        BLK_SIZE == 3'b010 ? 3 : 7;
wire [2:0] blk_addr  =  BLK_SIZE == 3'b000 ? 0         :
                        BLK_SIZE == 3'b001 ? ADDR[2]   :
                        BLK_SIZE == 3'b010 ? ADDR[3:2] : ADDR[4:2];
wire FULL_PAGE = BLK_SIZE == 3'b111;

wire page_boundary;
reg [2:0] BURST_CNT = 3'b0;
wire start_burst = ((tRCD == 0) & start_row_active) | 
                   ((tRCD == 1 | tRCD == 2) & TIMING_CNT_EQ_1 & q_row_active );
wire [2:0] BURST_CNT_DEC_1 = (BURST_CNT - 1'b1);
wire BURST_CNT_EQ_0 = (BURST_CNT == 3'd0);
wire BURST_CNT_EQ_1 = (BURST_CNT == 3'd1);
wire last_blk_word = BURST_CNT_EQ_0 & !FULL_PAGE;
always @( posedge CLK)
    if( q_row_active & TIMING_CNT_EQ_0 | RW & BURST_CNT_EQ_0 & q_rw )
                BURST_CNT <= BLK_LENGTH - blk_addr;
    else if( !BURST_CNT_EQ_0 & BURST_RDY & !FULL_PAGE ) 
                BURST_CNT <= BURST_CNT_DEC_1;

reg d_page_boundary;
always @( ADDR or COL_SIZE or CPU_GNT_ ) begin
    case( COL_SIZE )    // synopsys parallel_case full_case
    //2'b00: d_page_boundary = CPU_GNT_ & ( ADDR[ 9:2] ==  8'hFF );
    //2'b01: d_page_boundary = CPU_GNT_ & ( ADDR[10:2] ==  9'h1FF );
    //2'b10: d_page_boundary = CPU_GNT_ & ( ADDR[11:2] == 10'h3FF );
    //2'b11: d_page_boundary = CPU_GNT_ & ( ADDR[12:2] == 11'h7FF );
        2'b00: d_page_boundary = ( ADDR[ 9:2] ==  8'hFF );              // add by dengshan 2009-8-11
        2'b01: d_page_boundary = ( ADDR[10:2] ==  9'h1FF );
        2'b10: d_page_boundary = ( ADDR[11:2] == 10'h3FF );
        2'b11: d_page_boundary = ( ADDR[12:2] == 11'h7FF );    
    endcase
end

reg page_boundary_reg = 1'b0;
assign page_boundary = page_boundary_reg;
always @(posedge CLK)
    if( BURST_RDY & d_page_boundary ) page_boundary_reg <= 1;
    else                              page_boundary_reg <= 0;

wire start_nxt_rd = RD & BURST_CNT_EQ_0 & !page_boundary & 
                        !inhibit_rw & q_rd;
wire start_nxt_wr = WR & BURST_CNT_EQ_0 & !page_boundary & 
                        !inhibit_rw & q_wr;
/*=============================================================
 +    BURST_RDY,  RD_DAT_RDY
 +=============================================================*/
reg  BURST_RDY_D = 1'b0;
wire BURST_RDY = RW & BURST_RDY_D ;
always @(posedge CLK)
    if( start_burst & !( st_break_rw | break_rw ) )
                   BURST_RDY_D <= 1'b1;
    else if( !RW | q_rw & inhibit_new_cmd | d_page_boundary ) 
                   BURST_RDY_D <= 1'b0;
		
reg  DQ_OE = 1'b0;
wire BURST_RDYt = BURST_RDY;
always @(posedge CLK)
	if( q_row_active & d_wr ) DQ_OE <= `D 1'b1;
	else if( q_wr & d_burst_term ) DQ_OE <= `D 1'b0;

//reg  [1:0] last_dat_cnt;
//wire       last_dat_cnt_EQ_0  = last_dat_cnt == 0;
//wire       last_dat_cnt_EQ_1  = last_dat_cnt == 1;
//wire [1:0] last_dat_cnt_dec_1 = last_dat_cnt  - 1;
//wire lst_rd = q_rd & ( !RD | page_boundary | inhibit_rw );            // added 1110
//reg  lst_rd_d;                                                            // added 1110
//wire st_lst_rd = lst_rd & !lst_rd_d;                                      // added 1110
////always @(posedge CLK) lst_rd_d <= lst_rd;                                 // added 1110
//always @(posedge CLK) lst_rd_d <= lst_rd;                                 // added 1110
//
//always @(posedge CLK)
//    if(!RST_)                   last_dat_cnt <= 0;
//    else if(st_lst_rd)    	     last_dat_cnt <= tCAS;// + 2'b10;   // start_lst_rd --> st_lst_rd  @ 1110
//    else if(!last_dat_cnt_EQ_0) last_dat_cnt <= last_dat_cnt_dec_1;

reg  [2:0] last_dat_cnt = 3'b0;
wire       last_dat_cnt_EQ_0  = (last_dat_cnt == 3'b0);
wire       last_dat_cnt_EQ_1  = (last_dat_cnt == 3'd1);
wire [2:0] last_dat_cnt_dec_1 = (last_dat_cnt  - 1'b1);
wire lst_rd = q_rd & ( !RD | page_boundary | inhibit_rw );            // added 1110
reg  lst_rd_d = 1'b0;                                                            // added 1110
wire st_lst_rd = lst_rd & !lst_rd_d;                                      // added 1110
always @(posedge CLK)
    lst_rd_d <= lst_rd;                                 // added 1110

always @(posedge CLK)
    if(st_lst_rd)    	     last_dat_cnt <= tCAS + 2'b10;   // start_lst_rd --> st_lst_rd  @ 1110
    else if(!last_dat_cnt_EQ_0) last_dat_cnt <= last_dat_cnt_dec_1;
        
reg Q_DAT_RDY = 1'b0;
wire DAT_RDY = Q_DAT_RDY;
always @(posedge CLK)
    if(last_dat_cnt_EQ_1) Q_DAT_RDY <= 1'b0;
    else if(CAS_CNT_EQ_1)      Q_DAT_RDY <= 1'b1;

reg  Q_RD_DAT_RDY = 1'b0;
wire RD_DAT_RDY = Q_RD_DAT_RDY;
always @(posedge CLK) Q_RD_DAT_RDY <= DAT_RDY; 
/*=============================================================
 +    [15:0] DAT       :    Data Output to Master/DIMM
 +=============================================================*/
reg  [15:0] DAT = 16'b0;
wire [15:0] DAT_O = DAT;
wire [15:0] DQ_O = DAT;
always @(posedge CLK)
    if( DAT_RDY )     DAT <= `D DQ_I;
    else if( d_wr | q_wr ) DAT <= `D DAT_I;

/*=============================================================
 +    CKE : Clock Enable
 +=============================================================*/
reg CKE = 1'b0;
always @(posedge CLK) begin
    if(!RST_ )                  CKE <= 1;
    else if(STOP_CLK  & q_idle) CKE <= 0;
end

/*=============================================================
 +           RAS_         :    Row Address Select
 +=============================================================*/
reg Q_RAS_, D_RAS_;
wire RAS_ = Q_RAS_;
wire start_burst_term = d_burst_term & !q_burst_term;
wire start_rd = start_fst_rd | start_nxt_rd;
wire start_wr = start_fst_wr | start_nxt_wr;
wire start_rw = start_rd | start_wr;
						
always @( Q_RAS_ or start_precharge or start_ref_timing or
	      start_rw or start_row_active or d_set_mode  or start_burst_term ) begin
    D_RAS_ = Q_RAS_;
    if(start_precharge  | start_ref_timing |
  	   start_row_active |  d_set_mode )       D_RAS_ = 1'b0;
    else if(start_rw | start_burst_term )     D_RAS_ = 1'b1;
end

wire D_RASt_ = D_RAS_;
always @(posedge CLK)
    if(!RST_) Q_RAS_ <= `D 1'b1;
    else      Q_RAS_ <= `D D_RASt_;

/*=============================================================
 +           CAS_         :    Column Address Select
 +=============================================================*/
reg Q_CAS_, D_CAS_;
wire CAS_ = Q_CAS_;
always @( Q_CAS_ or start_precharge or start_ref_timing or
	      start_rw or start_row_active or  d_set_mode or start_burst_term ) begin
    D_CAS_ = Q_CAS_;
    if( start_ref_timing |
        		start_rw | d_set_mode ) D_CAS_ = 1'b0;
    else if( start_precharge | start_row_active |
		        start_burst_term )      D_CAS_ = 1'b1;
end

wire D_CASt_ = D_CAS_;
always @(posedge CLK)
    if(!RST_) Q_CAS_ <= `D 1;
    else      Q_CAS_ <= `D D_CASt_;
/*=============================================================
 +           WE_          :    Write Enable
 +=============================================================*/
reg Q_WE_, D_WE_;
wire WE_ = Q_WE_;
always @( Q_WE_ or start_precharge or start_ref_timing  or
  	   start_rd or start_wr or start_row_active or d_idle or d_set_mode or start_burst_term ) begin
     D_WE_ = Q_WE_;
    if(start_precharge | start_wr | d_set_mode | start_burst_term)                   D_WE_ = 1'b0;
    else if(start_ref_timing  | start_row_active | start_rd | d_idle) D_WE_ = 1'b1;
end

wire D_WEt_ = D_WE_;
always @(posedge CLK)
    if(!RST_) Q_WE_ <= `D 1'b1;
    else      Q_WE_ <= `D D_WEt_;
  
/*=============================================================
 +     [3:0] DQM          :    Data I/O Mask
 +=============================================================*/
reg  Q_DQM;
wire DQM = Q_DQM;
always @(posedge CLK)
    if( !RST_ )             Q_DQM <= `D 1;
    else if( d_row_active ) Q_DQM <= `D 0;

/*=============================================================
 +    [12:0] DIMM_ADDR     :    DIMM Row/Column Address
 +           MODULE_BK_NUM :    Module banks number
 +           CS_           :    Chip Select
 +     [1:0] BA            :    Bank Address
 + [1:0] ROW_SIZE  2'b00   : A0-A10,            2'b01 : A0-A11
 +                 2'b10   : A0-A12
 + [1:0] BIT_SIZE  2'b00   : 4,                 2'b01 : 8
 +                 2'b10   : 16(not supported), 2'b11 : 32(not supported) 
 +       BK_SIZE   2'b0    : BA0,               2'b1  : BA0-BA1
 + [1:0] COL_SIZE  2'b00  : A0-A7               3'b01: A0-A8
 +                 2'b10  : A0-A9               3'b11: A0-A9,A11
 +=============================================================*/
reg  [12:0] Q_DIMM_ADDR = 13'b0, D_DIMM_ADDR;
reg   Q_CS_ = 1'b0, D_CS_;
reg   [1:0] Q_BA = 2'b0, D_BA;

assign DIMM_ADDR = Q_DIMM_ADDR;
assign CS_ = Q_CS_;
assign BA = Q_BA;
always @(posedge CLK) begin
	Q_DIMM_ADDR <= `D D_DIMM_ADDR;
	Q_CS_ <= `D D_CS_;
	Q_BA <= `D D_BA;
end
		
always @(Q_BA     or Q_CS_      or Q_DIMM_ADDR      or PAA                   or
         BK_SIZE  or ROW_SIZE   or start_row_active or start_init_prech      or
         BIT_SIZE or d_set_mode or start_precharge  or 
         start_ref_timing       or start_rw         or  start_norm_precharge or
         ADDR     or COL_SIZE   or start_burst_term or tCAS                  or
         IS_SEQ   or BLK_SIZE) begin
    D_DIMM_ADDR = Q_DIMM_ADDR;
    D_CS_  = Q_CS_;     D_BA = Q_BA;    
    case({BK_SIZE,ROW_SIZE,COL_SIZE,BIT_SIZE}) //synopsys parallel_case full_case
        //8'b1_01_01_01: begin  // 4 X 4K X 512 X 8
        //    if(start_init_prech | start_norm_precharge | d_set_mode | start_ref_timing | !PAA)
        //          D_CS_ = 1'b0;
        //    else if( start_row_active | start_rw | start_burst_term )
        //          D_CS_ = 1'b0;
        //    else  D_CS_ = 1'b1;

        //    if( start_row_active | start_rw ) D_BA = ADDR[24:23];

        //    casex({start_row_active, start_rw, d_set_mode, start_precharge})
        //        4'b0001:  D_DIMM_ADDR[10] = 1'b1;
        //        4'b001x:  D_DIMM_ADDR ={ 6'b0, 1'b0, tCAS, IS_SEQ, BLK_SIZE };
        //        4'b01xx:  D_DIMM_ADDR = ADDR[10:2];
        //        default:  D_DIMM_ADDR = ADDR[22:11];
        //    endcase

        //end                               
        //8'b1_01_10_00: begin  // 4 X 4K X 1K X 4
        //    if(start_init_prech | start_norm_precharge | d_set_mode | start_ref_timing | !PAA)
        //          D_CS_ = 1'b0;
        //    else if( start_row_active | start_rw |	start_burst_term )
        //          D_CS_ = 1'b0;
        //    else  D_CS_ = 1'b1;

        //    if( start_row_active | start_rw ) D_BA = ADDR[25:24];

        //    casex({start_row_active, start_rw, d_set_mode, start_precharge})
        //        4'b0001:  D_DIMM_ADDR[10] = 1'b1;
        //        4'b001x:  D_DIMM_ADDR ={ 6'b0, 1'b0, tCAS, IS_SEQ, BLK_SIZE };
        //        4'b01xx:  D_DIMM_ADDR = ADDR[11:2];
        //        default:  D_DIMM_ADDR = ADDR[23:12];
        //    endcase
        //        
        //end                               
        //8'b1_01_10_01: begin  // 4 X 4K X 1K X 8
        //    if(start_init_prech | start_norm_precharge | d_set_mode | start_ref_timing | !PAA)
        //          D_CS_ = 1'b0;
        //    else if( start_row_active | start_rw |	start_burst_term )
        //          D_CS_ = 1'b0;
        //    else  D_CS_ = 1'b1;

        //    if( start_row_active | start_rw ) D_BA = ADDR[25:24];

        //    casex({start_row_active, start_rw, d_set_mode, start_precharge})
        //        4'b0001:  D_DIMM_ADDR[10] = 1'b1;
        //        4'b001x:  D_DIMM_ADDR ={ 6'b0, 1'b0, tCAS, IS_SEQ, BLK_SIZE };
        //        4'b01xx:  D_DIMM_ADDR = ADDR[11:2];
        //        default:  D_DIMM_ADDR = ADDR[23:12];
        //    endcase                
        //    
        //end
        //8'b1_01_11_01: begin  // 4 X 4K X 2K X 4
        //    if(start_init_prech | start_norm_precharge | d_set_mode | start_ref_timing | !PAA)
        //          D_CS_ = 1'b0;
        //    else if( start_row_active | start_rw | start_burst_term ) 
        //          D_CS_ = 1'b0;
        //    else  D_CS_ = 1'b1;

        //    if( start_row_active | start_rw ) D_BA = ADDR[26:25];
        //        
        //    casex({start_row_active, start_rw, d_set_mode, start_precharge})
        //        4'b0001:  D_DIMM_ADDR[10] = 1'b1;
        //        4'b001x:  D_DIMM_ADDR ={ 6'b0, 1'b0, tCAS, IS_SEQ, BLK_SIZE };
        //        4'b01xx:  D_DIMM_ADDR = {ADDR[12], 1'b0, ADDR[11:2]};
        //        default:  D_DIMM_ADDR = ADDR[24:13];
        //    endcase
        //                    
        //end

        //8'b1_10_01_10: begin  // 4 X 8K X 512 X 16
        //    if(start_init_prech | start_norm_precharge | d_set_mode | start_ref_timing | !PAA)
        //          D_CS_ = 1'b0;
        //    else if( start_row_active | start_rw | start_burst_term ) 
        //          D_CS_ = 1'b0;
        //    else  D_CS_ = 1'b1;

        //    if( start_row_active | start_rw ) D_BA = ADDR[25:24];

        //    casex({start_row_active, start_rw, d_set_mode, start_precharge})
        //        4'b0001:  D_DIMM_ADDR[10] = 1'b1;
        //        4'b001x:  D_DIMM_ADDR ={ 6'b0, 1'b0, tCAS, IS_SEQ, BLK_SIZE };
        //        4'b01xx:  D_DIMM_ADDR = ADDR[10: 2];
        //        default:  D_DIMM_ADDR = ADDR[23:11];
        //    endcase
        //end


        //8'b1_10_10_01: begin  // 4 X 8K X 1K X 8
        //    if(start_init_prech | start_norm_precharge | d_set_mode | start_ref_timing | !PAA)
        //          D_CS_ = 1'b0;
        //    else if( start_row_active | start_rw | start_burst_term ) 
        //          D_CS_ = 1'b0;
        //    else  D_CS_ = 1'b1;

        //    if( start_row_active | start_rw ) D_BA = ADDR[26:25];

        //    casex({start_row_active, start_rw, d_set_mode, start_precharge})
        //        4'b0001:  D_DIMM_ADDR[10] = 1'b1;
        //        4'b001x:  D_DIMM_ADDR ={ 6'b0, 1'b0, tCAS, IS_SEQ, BLK_SIZE };
        //        4'b01xx:  D_DIMM_ADDR = ADDR[11:2];
        //        default:  D_DIMM_ADDR = {1'b0, ADDR[24:12]};
        //    endcase             
        //    
        //end
        //8'b1_10_11_00: begin  // 4 X 8K X 2K X 4
        //    if(start_init_prech | start_norm_precharge | d_set_mode | start_ref_timing | !PAA)
        //          D_CS_ = 1'b0;
        //    else if( start_row_active | start_rw | start_burst_term )
        //          D_CS_ = 1'b0;
        //    else  D_CS_ = 1'b1;

        //    if( start_row_active | start_rw ) D_BA = ADDR[27:26];

        //    casex({start_row_active, start_rw, d_set_mode, start_precharge})
        //        4'b0001:  D_DIMM_ADDR[10] = 1'b1;
        //        4'b001x:  D_DIMM_ADDR ={ 6'b0, 1'b0, tCAS, IS_SEQ, BLK_SIZE };
        //        4'b01xx:  D_DIMM_ADDR = {ADDR[12], 1'b0, ADDR[11:2]};
        //        default:  D_DIMM_ADDR = ADDR[25:13];
        //    endcase
        //                    
        //end
        //8'b1_00_00_11: begin
        //    if( start_init_prech | start_norm_precharge | d_set_mode | start_ref_timing | !PAA)
        //          D_CS_ = 1'b0;
        //    else if( start_row_active | start_rw | start_burst_term )
        //          D_CS_ = 1'b0;
        //    else  D_CS_ = 1'b1;

        //    if( start_row_active | start_rw ) D_BA = ADDR[22:21];

        //    casex({start_row_active, start_rw, d_set_mode, start_precharge})
        //        4'b0001:  D_DIMM_ADDR[10] = 1'b1;
        //        4'b001x:  D_DIMM_ADDR ={ 6'b0, 1'b0, tCAS, IS_SEQ, BLK_SIZE };
        //        4'b01xx:  D_DIMM_ADDR = ADDR[9:2];
        //        default:  D_DIMM_ADDR = ADDR[20:10];
        //    endcase                
        //    
        //end

        default: begin
            if(start_init_prech | start_norm_precharge | d_set_mode | start_ref_timing | !PAA)
                  D_CS_ = 1'b0;
            else if( start_row_active | start_rw |	start_burst_term )
                  D_CS_ = 1'b0;
            else  D_CS_ = 1'b1;

            if( start_row_active | start_rw ) D_BA = ADDR[25:24];

            casex({start_row_active, start_rw, d_set_mode, start_precharge})
                4'b0001:  D_DIMM_ADDR[10] = 1'b1;
                4'b001x:  D_DIMM_ADDR ={ 6'b0, 1'b0, tCAS, IS_SEQ, BLK_SIZE };
                4'b01xx:  D_DIMM_ADDR = ADDR[10:2];
                default:  D_DIMM_ADDR = ADDR[23:11];
            endcase
                            
        end
    endcase
end


/*=============================================================
 +    Main State Machine(Mealy) of SDRAM Controller
 +=============================================================*/

always @( Q_SD     or init_finished      or start_init_prech or
          PAA      or SET_MODE           or RP_CNT_EQ_0      or
          WR       or TIMING_CNT_EQ_0    or page_boundary    or
          RD       or last_blk_word      or inhibit_new_cmd  or
          RW       or set_mode_finished  or REF_CNT_EQ_0     or
          break_rw or inhibit_rw or PRECHARGE_EN or RC_CNT_EQ_0 ) begin
    q_idle       = 0;
    q_rd       = 0;     q_precharge  = 0;
    q_wr       = 0;     q_row_active = 0;
    q_auto_ref = 0;     q_burst_term = 0;
    q_set_mode = 0;     q_rd2prech   = 0;

    d_idle     = 0;     d_precharge  = 0;
    d_set_mode = 0;     d_burst_term = 0;
    d_auto_ref = 0;
    D_SD = Q_SD;
    case (Q_SD)                 // synthesis parallel_case
        SD_IDLE: begin
            q_idle = 1;
            if( start_init_prech ) begin
                d_precharge = 1;
                D_SD = SD_PRECHARGE;
            end
            else if( REF_CNT_EQ_0 & set_mode_finished | PAA & !init_finished ) begin
            		d_auto_ref = 1;
                D_SD = SD_AUTO_REF;
            end
            else if(SET_MODE & init_finished & !set_mode_finished) begin
                d_set_mode = 1;
                D_SD = SD_SET_MODE;
            end			
            else if(RW & !inhibit_new_cmd) begin
                D_SD = SD_ROW_ACTIVE;
            end
        end
        SD_SET_MODE: begin
            q_set_mode = 1;
            d_idle     = 1;
            D_SD = SD_IDLE;
        end

        SD_AUTO_REF: begin
            q_auto_ref = 1;
            if( RC_CNT_EQ_0 )  begin
                d_idle = 1;
                D_SD = SD_IDLE;
            end
        end
        SD_ROW_ACTIVE: begin
            q_row_active = 1;
            if( TIMING_CNT_EQ_0 ) begin
                if( RD & !break_rw )      D_SD = SD_READ;
                else if( WR & !break_rw ) D_SD = SD_WRITE;
                else if( break_rw & PRECHARGE_EN ) begin
                    d_precharge = 1;                       // add by jzhang 1010
                    D_SD = SD_PRECHARGE;                   // For RD/WR signal by jzhang @ 1109
                end
            end
        end
        SD_READ: begin
            q_rd = 1;
            if( last_blk_word & ( !RD | inhibit_rw )	| page_boundary  ) begin
                if( PRECHARGE_EN ) begin
                    d_precharge = 1;
                    D_SD = SD_PRECHARGE;
                end
                else D_SD = SD_RD2PRECH;
            end
            else if(!RD | inhibit_rw ) begin
                d_burst_term = 1;
                D_SD = SD_BURST_TERM;
            end
        end
        SD_WRITE: begin
            q_wr = 1;
            if( page_boundary |!WR | inhibit_rw ) begin //tWR > 1
                d_burst_term = 1;
                D_SD = SD_BURST_TERM;
            end
        end
        SD_BURST_TERM: begin
            q_burst_term = 1;
            d_precharge  = 1;
            D_SD = SD_PRECHARGE;
	end
	SD_RD2PRECH : begin
            q_rd2prech   = 1;
	    if( PRECHARGE_EN ) begin
                d_precharge = 1;
                D_SD = SD_PRECHARGE;
	    end
	end
        SD_PRECHARGE: begin							  
            q_precharge = 1;
            if( RP_CNT_EQ_0 ) begin
                if(RW & !inhibit_new_cmd)  begin
                    D_SD = SD_ROW_ACTIVE;
                end
                else begin
                    d_idle = 1;
                    D_SD = SD_IDLE;
                end
            end
        end
        default: begin
            d_idle = 1;
            D_SD = SD_IDLE;
        end
    endcase
end

wire [8:0] D_SDt = D_SD;
always @(posedge CLK) begin
    if(!RST_) Q_SD <= `D SD_IDLE;
    else      Q_SD <= `D D_SDt;
end		  
endmodule
