


package ising_config;

//GPIO bus definitions
parameter instr_b_sw = 25;//Tells AXIS mux where to write incomming axis word
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
//Address table for configuration registers (0 to 65535)
parameter mac_input_scaler_addr_reg = 16'h0002;
parameter mac_input_scaler_data_reg = 16'h0003;
parameter nl_input_scaler_addr_reg = 16'h0004;
parameter nl_input_scaler_data_reg = 16'h0005;
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




endpackage