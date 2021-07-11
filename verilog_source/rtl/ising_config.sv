


package ising_config;

parameter gpio_w_clk_bit = 24;
parameter gpio_addr_start = 15;
parameter gpio_addr_end = 0;
parameter gpio_data_start = 23;
parameter gpio_data_end = 16;

parameter gpio_addr_width = 16;
parameter gpio_data_width = 8;

parameter adc_buffer_len = 256;

parameter num_bits = 8; //Bit precision to use for internal logic


//Address table for configuration registers (0 to 65535)
parameter mac_input_scaler_addr_reg = 0;
parameter mac_input_scaler_data_reg = 0;
parameter nl_input_scaler_addr_reg = 256;
parameter nl_input_scaler_data_reg = 256;



parameter var_fifo_depth = 12; //(2**12 = 4096)




//Config Reg Address table
parameter run_trig_reg = 16'h0000;
parameter del_trig_reg = 16'h0001;


endpackage