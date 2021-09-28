

module sample_selector
#(parameter addr = 0)
(
	input wire clk, rst,
	
	input wire [31:0] gpio_in,
	
	input wire [127:0] adc_word_in,
	
	output wire [15:0] sample_out
);

wire [7:0] sample_num;
config_reg #(8,1,16,addr) samp_num_reg_inst (clk, rst, gpio_in,sample_num);
wire [2:0] sn_t = sample_num[2:0];

assign sample_out = adc_word_in[(sn_t*16)+:16];

endmodule