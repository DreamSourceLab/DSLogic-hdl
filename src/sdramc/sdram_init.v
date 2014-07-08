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

`timescale 1ns/10ps

module sdram_init (
    // -- Clock & Reset
    input       sdram_clk,
    input       sdram_rst_,
    // -- CKE
//    input       CKE_IN,
//    output  reg CKE_OUT,
    // -- init output signals
    output  reg PAA = 0,
    output  reg SET_MODE
);

parameter
    INIT_CNT        = 16'h4000,
    INIT_HALF_CNT   = INIT_CNT >> 1;
    
/********************************************************/
// --  Internal Signals                                   

reg     [15:0]  init_counter;
wire    init_counter_done;
//wire    init_counter_half_done;
assign init_counter_done = (init_counter == INIT_CNT);
//assign init_counter_half_done = (init_counter > INIT_HALF_CNT);
always @(posedge sdram_clk) begin
    if (!sdram_rst_)
        init_counter <= 'b0;
    else if (!init_counter_done)
        init_counter <= init_counter + 1'b1;
end

// -- Generate CKE_OUT
//always @(negedge sdram_clk or negedge sdram_rst_) begin
//    if (!sdram_rst_)
//        CKE_OUT <= 1'b0;
//    else
//        CKE_OUT <= CKE_IN && init_counter_half_done;
//end
        
// -- Generate PAA
// -- Wait at least 100us after providing stable sdram CLOCK signal
always @(posedge sdram_clk) begin
        PAA <= init_counter_done;
end        

// -- Generate SET_MODE
always @(posedge sdram_clk) begin
        SET_MODE <= 1'b1;
end

        
endmodule /* module sdram_init (*/
