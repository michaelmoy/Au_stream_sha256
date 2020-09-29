`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: MoySys, LLC
// Engineer: Michael Moy
//
// Create Date: 09/28/2020 09:22:00 PM
// Design Name:
// Module Name: top_stream_tb
// Project Name:
// Target Devices:
// Tool Versions:
// Description:  Top level Testbed for streaming 512 bit SHA256 calculations with
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


module top_stream_tb(

	);

reg clk;
wire rst_n;

reg rst;

assign rst_n = (~rst);


// free running counter
reg [64:0] counter;

reg [511:0] TestBlock1;
wire [63:0]  TestLen1;
wire [255:0] Answer;

wire sha_rdy;
wire sha_act;
reg sha_f;
reg sha_n;
reg sha_l;

assign		TestLen1 = 1024;

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
				end
		endcase

	end
end


	initial begin

		rst = 1;

		clk = 0;
		#50;
		clk = 1;
		#50;
		clk = 0;
		#50;
		clk = 1;
		#50;
		clk = 0;
		#50;
		clk = 1;
		#50;
		clk = 0;
		rst = 0;
		#50;
		clk = 1;
		#50;
		clk = 0;
		#50;


		repeat (1000) begin
			clk =  ! clk;
			#50;
		end

		#200;
		clk =  ! clk;
		end


endmodule
