`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: MoySys, LLC
// Engineer: Michael Moy
//
// Create Date: 09/28/2020 07:07:55 PM
// Design Name:
// Module Name: stream_sha256
// Project Name:
// Target Devices:
// Tool Versions:
// Description:  Device to take one or more 512 bit blocks and calculates
//               the sha256sum on the set of blocks given.
//
//               This object requires one, or more, 512bit input blocks.
//               The padding operation is already included in the block data.
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


module stream_sha256(
	input clk,
	input rst_n,
	input [511:0] block_in,
	input [63:0] tot_len,				// in bits
	output reg [255:0] sha256_out,
	output reg sha256_rdy,
	output reg sha256_active,
	input sha256_first,
	input sha256_next,
	input sha256_last
	);



//----------------------------------------------------------------
// Internal constant and parameter definitions.
//----------------------------------------------------------------
parameter DEBUG = 0;

parameter CLK_HALF_PERIOD = 2;
parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;

// The address map.
parameter ADDR_NAME0       = 8'h00;
parameter ADDR_NAME1       = 8'h01;
parameter ADDR_VERSION     = 8'h02;

parameter ADDR_CTRL        = 8'h08;
parameter CTRL_INIT_VALUE  = 8'h01;
parameter CTRL_NEXT_VALUE  = 8'h02;
parameter CTRL_MODE_VALUE  = 8'h04;

parameter ADDR_STATUS      = 8'h09;
parameter STATUS_READY_BIT = 0;
parameter STATUS_VALID_BIT = 1;

parameter ADDR_BLOCK0    = 8'h10;
parameter ADDR_BLOCK1    = 8'h11;
parameter ADDR_BLOCK2    = 8'h12;
parameter ADDR_BLOCK3    = 8'h13;
parameter ADDR_BLOCK4    = 8'h14;
parameter ADDR_BLOCK5    = 8'h15;
parameter ADDR_BLOCK6    = 8'h16;
parameter ADDR_BLOCK7    = 8'h17;
parameter ADDR_BLOCK8    = 8'h18;
parameter ADDR_BLOCK9    = 8'h19;
parameter ADDR_BLOCK10   = 8'h1a;
parameter ADDR_BLOCK11   = 8'h1b;
parameter ADDR_BLOCK12   = 8'h1c;
parameter ADDR_BLOCK13   = 8'h1d;
parameter ADDR_BLOCK14   = 8'h1e;
parameter ADDR_BLOCK15   = 8'h1f;

parameter ADDR_DIGEST0   = 8'h20;
parameter ADDR_DIGEST1   = 8'h21;
parameter ADDR_DIGEST2   = 8'h22;
parameter ADDR_DIGEST3   = 8'h23;
parameter ADDR_DIGEST4   = 8'h24;
parameter ADDR_DIGEST5   = 8'h25;
parameter ADDR_DIGEST6   = 8'h26;
parameter ADDR_DIGEST7   = 8'h27;

parameter SHA224_MODE    = 0;
parameter SHA256_MODE    = 1;

parameter STATE_IDLE             = 0;
parameter STATE_WR_BLOCK         = 1;
parameter STATE_CTRL_INIT        = 3;
parameter STATE_CTRL_INIT_NEXT   = 4;
parameter STATE_WAIT_READY       = 5;
parameter STATE_WAIT_READY_X     = 10;
parameter STATE_WAIT_READY_Y     = 11;
parameter STATE_READ_DIGEST      = 7;
parameter STATE_DISP_SHA         = 9;


//----------------------------------------------------------------
// Register and Wire declarations.
//----------------------------------------------------------------
reg           tb_cs;
reg           tb_we;
reg [27:0]    tb_address;
reg [31:0]    tb_write_data;
wire [31:0]   tb_read_data;
wire          tb_error;

reg [255:0]   digest_data;
reg [3:0]     state;
reg [511:0]   block_int;
reg [7:0]     blk_cnt;
reg [63:0]    tot_bits;

//----------------------------------------------------------------
// the Device that does a 512 bit block
//----------------------------------------------------------------
sha256 sha256_calc_engine(
		.clk(clk),
		.reset_n(rst_n),
		.cs(tb_cs),
		.we(tb_we),
		.address(tb_address),
		.write_data(tb_write_data),
		.read_data(tb_read_data),
		.error(tb_error)
		);

// the state machine that puts together multiple 512 bit blocks and
// feeds them to the sha256 calculator engine
always @(posedge clk or negedge rst_n) begin
	if(rst_n == 0) begin
		state <= STATE_IDLE;
		tb_cs <= 0;
		tb_we <= 0;
		tb_address <= 26'h0; // MOY 6'h0;
		tb_write_data <= 32'h0;
		block_int <= block_in;
		sha256_rdy <= 0;
		sha256_active <= 0;
		tot_bits <= 0;
		end
	else begin

		case(state)
			STATE_IDLE: begin
				sha256_rdy <= 0;
				if( sha256_first == 1 ) begin
					state <= STATE_WR_BLOCK;
					tb_address <= ADDR_BLOCK0;
					tb_write_data <= block_int[511 : 480];
					tb_cs <= 1;
					tb_we <= 1;
					blk_cnt <= 0;
					digest_data <= 0 ;
					sha256_active <= 1;
					end
				else begin
					block_int <= block_in;
					end
				end
			STATE_WR_BLOCK: begin
				if( blk_cnt == 15 ) begin
					state <= STATE_CTRL_INIT;
					tb_address <= ADDR_CTRL;
					if(tot_bits == 0)
						tb_write_data <= (CTRL_MODE_VALUE + CTRL_INIT_VALUE);
					else
						tb_write_data <= (CTRL_MODE_VALUE + CTRL_NEXT_VALUE);
					end
				else begin
					block_int <= block_int << 32 ;
					tb_address <= tb_address + 1;
					tb_write_data <= block_int[479 : 448];
					blk_cnt <= blk_cnt + 1;
					end
				end
			STATE_CTRL_INIT: begin
				state <= STATE_CTRL_INIT_NEXT;
				tb_cs <= 0;
				tb_we <= 0;
				end
			STATE_CTRL_INIT_NEXT: begin
				state <= STATE_WAIT_READY_X;
				tb_cs <= 1;
				tb_we <= 0;
				tb_address <= ADDR_STATUS;
				tot_bits <= tot_bits + 512;
				end
			STATE_WAIT_READY_X: begin
				state <= STATE_WAIT_READY_Y;
				end
			STATE_WAIT_READY_Y: begin
				state <= STATE_WAIT_READY;
				end
			STATE_WAIT_READY: begin
				if( tb_read_data != 3 )
					state <= STATE_WAIT_READY;
				else begin
					if( tot_bits == tot_len ) begin
						state <= STATE_READ_DIGEST;
						tb_address <= ADDR_DIGEST0;
						blk_cnt <= 0;
						digest_data <= 0;
						end
					else begin
						state <= STATE_IDLE;
						block_int <= block_in;
						end
					end
				end
			STATE_READ_DIGEST: begin
				if( blk_cnt == 8 ) begin
					state <= STATE_DISP_SHA;
					end
				else begin
					tb_address <= tb_address + 1;
					digest_data[31 : 0] <= tb_read_data;
					digest_data[255:32] <= digest_data[223:0];
					blk_cnt <= blk_cnt + 1;
					end
				end
			STATE_DISP_SHA: begin
				sha256_out <= digest_data;
				sha256_rdy <= 1;
				if( sha256_first == 0 ) begin
					state <= STATE_IDLE;
					sha256_active <= 0;
		block_int <= block_in;
					end
				end
			default: begin
				state <= STATE_IDLE;
			end

		endcase

		end
	end


endmodule
