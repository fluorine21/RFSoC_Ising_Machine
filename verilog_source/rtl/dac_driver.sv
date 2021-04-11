
import ising_config::*;

module dac_driver
#(
parameter output_scaler_addr_reg = 0,
parameter output_scaler_data_reg = 1,
parameter static_output_reg_base_addr = 2,//Static dac word to output
parameter dac_mux_sel_reg_base_addr = 3,//Selects between input from output scaler, static word, or delay cal
parameter shift_amt_reg_base_addr = 4//Selects how much to shift output by
)
(
	input wire clk, rst,
	
	input wire [31:0] gpio_in,
	
	input wire [255:0] fsm_val_in,
	input wire fsm_in_valid,
	
	input wire del_trig,
	
	output wire [255:0] dac_out
	
);


//output scaler instantiation
wire [255:0] dac_scaler_out;
output_scaler #(output_scaler_addr_reg, output_scaler_data_reg) output_scaler_inst
(
	clk, rst,
	
	fsm_val_in,
	fsm_in_valid,
	
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

//DAC delay calibration driver
wire [255:0] delay_cal_dac_word;
del_cal del_cal_inst(clk, rst, del_trig, static_dac_word delay_cal_dac_word);


//DAC mux
reg [255:0] shifter_input;
always @ * begin
	if(dac_mux_sel == 2) begin
		shifter_input <= delay_cal_dac_word;
	end
	else if (dac_mux_sel == 1) begin
		shifter_input <= static_dac_word;
	end
	else begin
		shifter_input <= dac_scaler_out;
	end
end

//Shift ammount register
wire [7:0] shift_amt;
config_reg #(8,1,16,shift_amt_reg_base_addr) dac_mux_sel_reg_inst
(
	clk, rst,
	
	gpio_in, //GPIO bus, 15:0 is addr, 23:16 is data, 24 is w_clk
	
	shift_amt
);

//Shifter instantiation
shifter #(16, 256) output_shifter_inst
(
	clk, rst, 
	shift_amt,//Number of samples to shift by
	shifter_input,
	dac_out
);


endmodule