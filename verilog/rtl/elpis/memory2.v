/*
*
* This file is part of the Elpis processor project.
*
* Copyright © 2020-present. All rights reserved.
* Authors: Aurora Tomas and Rodrigo Huerta.
*
* This file is licensed under both the BSD-3 license for individual/non-commercial
* use. Full text of both licenses can be found in LICENSE file.
*/

`default_nettype none


module memory2
	#(parameter MEMORY_FILE = 0)
	(
`ifdef USE_POWER_PINS
	inout vdda1,        // User area 1 3.3V supply
	inout vdda2,        // User area 2 3.3V supply
	inout vssa1,        // User area 1 analog ground
	inout vssa2,        // User area 2 analog ground
	inout vccd1,        // User area 1 1.8V supply
	inout vccd2,        // User area 2 1.8v supply
	inout vssd1,        // User area 1 digital ground
	inout vssd2,        // User area 2 digital ground
`endif
	input clk,
	input reset,
	input we,
	input[19:0] addr_in,
	input[127:0] wr_data,
	input requested,
	input reset_mem_req,
	output reg[127:0] rd_data_out,
	// output[127:0] rd_data_out,
	output ready,
	input is_loading_memory_into_core,
	input[19:0] addr_to_core_mem,
	input[31:0] data_to_core_mem
);
	wire[19:0] addr_output_mem;
	wire[7:0] first_bit_out_current;
	reg[7:0] first_bit_out_previous;
	wire[31:0] auxiliar_mem_out;

	reg[$clog2(5):0] cycles;
	
	assign ready = cycles == 0;

	assign addr_output_mem = addr_in + (cycles % 3'd4);
	assign first_bit_out_current = 6'd32 * (cycles % 3'd4);

	integer i;
	always@(posedge clk) begin
		if(reset) begin 
			cycles <= 0;
		end else if (reset_mem_req) begin
			cycles <= 0;
		end else if ((ready && requested))begin
			cycles <= 5;
		end else if(cycles!=0) begin
			cycles <= cycles-1'b1 ;
		end

		first_bit_out_previous <= first_bit_out_current;
		rd_data_out[first_bit_out_previous +:32] <= auxiliar_mem_out;
	end

	wire[31:0] dummy_out;

	reg[19:0] addr_to_sram;

	always@(*) begin
		if (we && requested && !is_loading_memory_into_core) begin
			if(cycles == 4)
				addr_to_sram <= addr_in;
			else if (cycles == 3) begin
				addr_to_sram <= addr_in+1;
			end else if (cycles == 2) begin
				addr_to_sram <= addr_in+2;
			end else if (cycles == 1) begin
				addr_to_sram <= addr_in+3;
			end 
		end else if(is_loading_memory_into_core) begin
			addr_to_sram <= addr_to_core_mem;
		end else begin
			addr_to_sram <= addr_output_mem;
		end
	end

	reg[31:0] data_to_sram;
	always@(*) begin
		if (we && requested && !is_loading_memory_into_core) begin
			if(cycles == 4)
				data_to_sram <= wr_data[31:0];
			else if (cycles == 3) begin
				data_to_sram <= wr_data[63:32];
			end else if (cycles == 2) begin
				data_to_sram <= wr_data[95:64];
			end else if (cycles == 1) begin
				data_to_sram <= wr_data[127:96];
			end 
		end else if(is_loading_memory_into_core) begin
			data_to_sram <= data_to_core_mem;
		end else begin
			data_to_sram <= 32'b0;
		end
	end
	

	sram_32_32_sky130 CPURAM(
		`ifdef USE_POWER_PINS
		.vccd1(vccd1),
		.vssd1(vssd1),
		`endif
		.clk0(clk),
		.csb0(1'b0),
		.web0(!we),
		.spare_wen0(1'b0),
		.addr0(addr_to_sram[5:0]),
		.din0(data_to_sram), 
		.dout0(auxiliar_mem_out)
	);
	
endmodule
