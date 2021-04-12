
import ising_config::*;

//Most significant byte first!

module config_reg
#(
parameter word_width = 8, //In bits
parameter num_words = 4,
parameter addr_width = 16, //In bits
parameter bus_addr = 0
)
(
	input wire clk, rst,
	
	input wire [31:0] gpio_in, //GPIO bus, 15:0 is addr, 23:16 is data, 24 is w_clk
	
	output reg [(num_words*word_width)-1:0] reg_out
);


wire w_clk = gpio_in[gpio_w_clk_bit];
wire [addr_width-1:0] gpio_addr = gpio_in[gpio_addr_start:gpio_addr_end];
wire [word_width-1:0] gpio_data = gpio_in[gpio_data_start:gpio_data_end];

reg state;

always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		state <= 0;
		reg_out <= 0;
	end
	else begin
		if(state) begin
			//If we have an incomming write
			if(w_clk && gpio_addr == bus_addr) begin
				reg_out <= {reg_out[0+:((num_words-1)*word_width)], gpio_data};//Append the incomming byte to the end of the register and discard the most significant byte
				state <= 1;//Wait for w_clk to reset
			end
		end
		else begin
			//If the write clock has been reset
			if(!w_clk) begin
				state <= 0; //go back to the initial state
			end
		end
	end
end

endmodule