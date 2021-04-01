


package rfsoc_config;

parameter gpio_w_clk_bit = 24;
parameter gpio_addr_start = 015
parameter gpio_addr_end = 0;
parameter gpio_data_start = 23;
parameter gpio_data_end = 16;

parameter adc_buffer_len = 256;


//Address table for configuration registers (0 to 65535)
parameter mac_input_scaler_base_addr = 0;
parameter nl_input_scaler_base_addr = 256;



endpackage