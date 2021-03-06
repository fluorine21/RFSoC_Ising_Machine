

//Takes an 8-bit input and returns a 256-bit dac word with a 2ns pulse in the middle each cycle
//Basically the lookup table but it also puts the DAC word together correctly

import ising_config::*;


module output_scaler
#(
//GPIO addresses for writing lookup table
parameter addr_reg = 0, 
parameter data_reg = 1
)
(
	input wire clk, rst,
	
	input wire [num_bits-1:0] val_in,
	input wire val_in_valid,
	
	
	input wire [31:0] gpio_in, //GPIO bus, 15:0 is addr, 23:16 is data, 24 is w_clk
	
	output reg [255:0] dac_word_out
);

wire [15:0] val_out;
wire [15:0] val_out_inv = (~val_out)+1;
wire val_out_valid;
lookup_table #(addr_reg,data_reg,num_bits,16) output_lookup_table_inst
( 
	clk, rst, gpio_in, val_in, val_in_valid, val_out, val_out_valid
);

//output process
always @ * begin//Combo logic
	if(!rst) begin
		dac_word_out <= 0;
	end
	else begin
		if(val_out_valid) begin
			dac_word_out <= {{8{val_out}}, {8{val_out_inv}}};
		end
		else begin
			dac_word_out <= 0;
		end
	end
end


endmodule