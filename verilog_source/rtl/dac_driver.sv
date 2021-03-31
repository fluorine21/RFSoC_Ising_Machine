
import ising_config::*;

module dac_driver
#(
parameter output_scaler_base_addr = 0,
parameter static_output_reg_base_addr = 0,
parameter dac_mux_sel_reg_base_addr = 0,
parameter shift_amt_reg_base_addr = 0
)
(
	input wire clk, rst,
	
	input wire [31:0] gpio_in,
	
	input wire fsm_val_in,//assumed to always be valid
	
	output wire [255:0] dac_out
	
);


//output scaler instantiation
wire [255:0] dac_scaler_out;
output_scaler #(output_scaler_base_addr) output_scaler_inst
(
	clk, rst,
	
	fsm_val_in,
	
	gpio_in,
	
	dac_scaler_out
);

//Static DAC output reg instantiation
wire [255:0] static_dac_word;
config_reg #(8,32,16,static_output_reg_base_addr) static_dac_output_reg_inst
(
	clk, rst,
	
	gpio_in, //GPIO bus, 15:0 is addr, 23:16 is data, 24 is w_clk
	
	static_dac_word
);


//DAC mux sel register
wire [7:0] dac_mux_sel;
config_reg #(8,1,16,dac_mux_sel_reg_base_addr) dac_mux_sel_reg_inst
(
	clk, rst,
	
	gpio_in, //GPIO bus, 15:0 is addr, 23:16 is data, 24 is w_clk
	
	dac_mux_sel
);


//DAC mux
wire [255:0] shifter_input = dac_mux_sel[0] ? static_dac_word : dac_scaler_out;

//Shift ammount register
wire [7:0] shift_amt;
config_reg #(8,1,16,shift_amt_reg_base_addr) dac_mux_sel_reg_inst
(
	clk, rst,
	
	gpio_in, //GPIO bus, 15:0 is addr, 23:16 is data, 24 is w_clk
	
	shift_amt
);

//Shifter instantiation
module output_shifter
(
	clk, rst, 
	shift_amt[3:0],//Number of samples to shift by
	shifter_input,
	dac_out
);


endmodule