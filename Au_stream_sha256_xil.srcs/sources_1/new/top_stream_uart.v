`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: MoySys, LLC
// Engineer: Michael Moy
// 
// Create Date: 09/28/2020 06:48:11 PM
// Design Name: 
// Module Name: top_stream_uart
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:  Top level Project for streaming 512 bit SHA256 calculations with
//               the SHA256 output displayed on the 7-SEG displays of the Alchitry
//               Au-Io Board setup.
//
//               This project currently does two 512bit blocks.
//
// Dependencies:
//
// Revision 1.0 - 09/28/2020 MEM Original Art.
//
// Additional Comments:
//
// Author: Michael Moy
// Copyright (c) 2020, MoySys, LLC
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//
//////////////////////////////////////////////////////////////////////////////////


module top_stream_uart(
	input clk,
	input rst_n,
 //   input moyrx,
 //   output moytx,
	output [7:0] led,
	output [7:0] io_seg,
	output [3:0] io_sel
	);



// internal segment data. The Display Controller drives this
wire [7:0] io_seg_int;

// digit values to display
reg [3:0] val3;
reg [3:0] val2;
reg [3:0] val1;
reg [3:0] val0;

// digit enable flags
wire ena_3 = 1;
wire ena_2 = 1;
wire ena_1 = 1;
wire ena_0 = 1;

// free running counter
reg [64:0] counter;

reg [511:0] TestBlock1;
reg  [63:0]  TestLen1;
wire [255:0] Answer;


// load the Au LED's from the free running counter
assign led[7:4] = counter[27:24];
assign led[3:0] = state[3:0];

// wire up the segments as needed. Set DP off:1 for now
assign io_seg[0] = ~io_seg_int[6];
assign io_seg[1] = ~io_seg_int[5];
assign io_seg[2] = ~io_seg_int[4];
assign io_seg[3] = ~io_seg_int[3];
assign io_seg[4] = ~io_seg_int[2];
assign io_seg[5] = ~io_seg_int[1];
assign io_seg[6] = ~io_seg_int[0];
assign io_seg[7] = ~io_seg_int[7];

// wire up the Io Board 4 Digit 7seg Display Controller
IoBd_7segX4 IoBoard7segDisplay(
	.clk(clk),
	.reset(~rst_n),

	.seg3_hex(val3),
	.seg3_dp(0),
	.seg3_ena(ena_3),

	.seg2_hex(val2),
	.seg2_dp(0),
	.seg2_ena(ena_2),

	.seg1_hex(val1),
	.seg1_dp(0),
	.seg1_ena(ena_1),

	.seg0_hex(val0),
	.seg0_dp(0),
	.seg0_ena(ena_0),

	.bright(4'h4),
	.seg_data(io_seg_int),
	.seg_select(io_sel)
	);



stream_sha256 sha256_ctrl(
	.clk(clk),
	.rst_n(rst_n),
	.block_in(TestBlock1),
	.tot_len(TestLen1),
	.sha256_out(Answer),
	.sha256_rdy(sha_rdy),
	.sha256_active(sha_act),
	.sha256_first(sha_f),
	.sha256_next(sha_n),
	.sha256_last(sha_l)
	);

// keep a free running counter to use for Display Data
always @(posedge clk) begin
	if(rst_n == 0) begin
		counter <= 0;
		end
	else begin
		counter <= counter + 1;
		end
	end



wire sha_rdy;
wire sha_act;
reg sha_f;
reg sha_n;
reg sha_l;

reg [3:0] state;

// state machine
always @(posedge clk) begin
	if(rst_n == 0) begin
		state <= 0;
		sha_f <= 0;
		sha_n <= 0;
		sha_l <= 0;
		val3 <= 3;
		val2 <= 2;
		val1 <= 1;
		val0 <= 0;
		TestLen1 <= 1024;
		end
	else begin

		case(state)
			0: begin   
	    		TestBlock1 <= 512'h41414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141;
				state <= 1;
				end

			1: begin
				state <= 2;
				sha_f <= 1;
				end

			2: begin
				if( sha_act ) begin
					state <= 3;
					sha_f <= 0;         
	  				TestBlock1 <= 512'h80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200;
					end
				else begin
				    TestBlock1 <= 512'h80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200;
					end
				end

			3: begin
				if( sha_rdy == 0 ) begin
					sha_f <= 1;
					end
				else begin
					state <= 4;
					end
				end

			4: begin
					sha_f <= 0;
					if( counter[29:28] == 0 ) begin
						val3 <= Answer[255 : 252];
						val2 <= Answer[251 : 248];
						val1 <= Answer[247 : 244];
						val0 <= Answer[243 : 240];
						end
					else  if( counter[29:28] == 1 ) begin
						val3 <= Answer[239 : 236];
						val2 <= Answer[235 : 232];
						val1 <= Answer[231 : 228];
						val0 <= Answer[227 : 224];
						end
					else  if( counter[29:28] == 2 ) begin
						val3 <= Answer[223 : 220];
						val2 <= Answer[219 : 216];
						val1 <= Answer[215 : 212];
						val0 <= Answer[211 : 208];
						end
					else begin
						val3 <= Answer[207 : 204];
						val2 <= Answer[203 : 200];
						val1 <= Answer[199 : 196];
						val0 <= Answer[195 : 192];
						end
				end
		endcase

	end
end
	 



endmodule
