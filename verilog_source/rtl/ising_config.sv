


package ising_config;

//GPIO bus definitions
parameter gpio_w_clk_bit = 24;
parameter gpio_addr_start = 15;
parameter gpio_addr_end = 0;
parameter gpio_data_start = 23;
parameter gpio_data_end = 16;
parameter gpio_addr_width = 16;
parameter gpio_data_width = 8;

//How many words the ADC can record
parameter adc_buffer_len = 256;

parameter num_bits = 8; //Bit precision to use for internal logic


parameter var_fifo_depth = 12; //(2**12 = 4096)
parameter instr_fifo_depth = 16;




//Config Reg Address table
parameter run_trig_reg = 16'h0000;
parameter del_trig_reg = 16'h0001;
parameter halt_reg = 16'h0002;
parameter del_meas_val_reg = 16'h0003;
parameter del_meas_thresh_reg = 16'h0004;
parameter adc_run_reg = 17'h0005;
//Address table for configuration registers (0 to 65535)
//parameter mac_input_scaler_addr_reg = 16'h0002;
//parameter mac_input_scaler_data_reg = 16'h0003;
//parameter nl_input_scaler_addr_reg = 16'h0004;
//parameter nl_input_scaler_data_reg = 16'h0005;
parameter mac_driver_addr_reg = 16'h000C;
parameter mac_driver_data_reg = 16'h000D;
parameter mac_driver_shift_amt_reg_base_addr = 16'h000E;
parameter nl_driver_addr_reg = 16'h000F;
parameter nl_driver_data_reg = 16'h0010;
parameter nl_driver_shift_amt_reg_base_addr = 16'h0011;

//Readback registers
parameter del_meas_mac_result = 16'h0006;
parameter del_meas_nl_result = 16'h0007;
parameter a_read_reg = 16'h0008;
parameter c_read_reg = 16'h0009;
parameter mac_adc_read_reg = 16'h000A;
parameter nl_adc_read_reg = 16'h000B;
parameter instr_count_reg = 16'h0012;
parameter b_count_reg = 16'h0013;
parameter ex_state_reg = 16'h0014;


parameter a_output_scaler_addr_reg = 16'h0015;
parameter a_output_scaler_data_reg = 16'h0016;
parameter a_static_output_reg_base_addr = 16'h0017;//Static dac word to output
parameter a_dac_mux_sel_reg_base_addr = 16'h0018;//Selects between input from output scaler, static word, or delay cal
parameter a_shift_amt_reg_base_addr = 16'h0019;//Selects how much to shift output by

parameter b_output_scaler_addr_reg = 16'h001A;
parameter b_output_scaler_data_reg = 16'h001B;
parameter b_static_output_reg_base_addr = 16'h001C;//Static dac word to output
parameter b_dac_mux_sel_reg_base_addr = 16'h001D;//Selects between input from output scaler, static word, or delay cal
parameter b_shift_amt_reg_base_addr = 16'h001E;//Selects how much to shift output by

parameter c_output_scaler_addr_reg = 16'h001F;
parameter c_output_scaler_data_reg = 16'h0020;
parameter c_static_output_reg_base_addr = 16'h0021;//Static dac word to output
parameter c_dac_mux_sel_reg_base_addr = 16'h0022;//Selects between input from output scaler, static word, or delay cal
parameter c_shift_amt_reg_base_addr = 16'h0023;//Selects how much to shift output by

parameter a_write_reg = 16'h0024;
parameter c_write_reg = 16'h0025;

parameter instr_b_sel_reg = 16'h0026;





integer program_1[] = 
{
	
	16'h0030,//Add 0 to a, c
	16'h0007,//Remove a, b, c
	16'h0007,//Remove a, b, c
	16'h0007,//Remove a, b, c
	16'h0007,//Remove a, b, c
	16'h0007,//Remove a, b, c
	16'h0007,//Remove a, b, c
	16'h0007,//Remove a, b, c
	16'h0007 //Remove a, b, c

};



endpackage