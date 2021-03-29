

//Takes an 8-bit input and returns a 256-bit dac word with a 2ns pulse in the middle each cycle

import ising_config::*;


module output_scaler
#(
parameter mem_base_addr = 0 //Corresponds to GPIO bus addr at which this lookup table starts
)
(
	input wire clk, rst,
	
	input wire [7:0] value_in,
	
	input wire [31:0] gpio_in, //GPIO bus, 15:0 is addr, 23:16 is data, 24 is w_clk
	
	output reg [255:0] dac_word_out
);

//GPIO bus definitions
wire w_clk = gpio_in[gpio_w_clk_bit]
wire [addr_width-1:0] gpio_addr = gpio_in[gpio_addr_start:gpio_addr_end];
wire [word_width-1:0] gpio_data = gpio_in[gpio_data_start:gpio_data_end];


reg [15:0] lut [0:255];
reg [7:0] msb_temp;

//Write process
reg [1:0] write_state;
localparam [1:0] state_idle = 0, state_wait_1 = 1, state_wait_2 = 2, state_wait_end = 3;
always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		msb_temp <= 0;
		state <= state_idle;
	end
	else begin
		case(write_state) 
	
		state_idle:
			//If we have an incomming write and the address is in the right range
			if(w_clk && gpio_addr >= mem_base_addr && gpio_addr < mem_base_addr + 256)
				//Save this MSB
				msb_temp <= gpio_data;
				//Go to the next state
				state <= state_wait_1;
			end
		end
		
		state_wait_1: begin
			if(!w_clk) begin
				state <= state_wait_2;
			end
		end
		
		state_wait_2: begin
			//If we have an incomming write and the address is in the right range
			if(w_clk && gpio_addr >= mem_base_addr && gpio_addr < mem_base_addr + 256)
				//Execute the write
				lut[gpio_addr[7:0]] <= {msb_temp, gpio_data};
				//Go to the next state
				state <= state_wait_end;
			end
		end
		
		state_wait_end: begin
			if(!w_clk) begin
				state <= state_idle;
			end
		end
		
		endcase
	end


end


//Read process
always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		dac_word_out <= 0;
	end
	else begin
		dac_word_out <= {{4{16'b0}}, {8{lut[value_in]}}, {4{16'b0}}};
	end
end


endmodule