import ising_config::*;


//Takes two writes to do a single write to the a or c fifos
module gpio_axis_writer
#(parameter a_addr = 0, parameter c_addr = 1)
(
	input wire clk, rst,
	
	input wire [31:0] gpio_in,
	
	output wire [num_bits-1:0] a_data_out,
	output reg a_valid,
	input wire a_rdy,
	
	output wire [num_bits-1:0] c_data_out,
	output reg c_valid,
	input wire c_rdy
);

//GPIO bus definitions
wire w_clk = gpio_in[gpio_w_clk_bit];
wire [gpio_addr_width-1:0] gpio_addr = gpio_in[gpio_addr_start:gpio_addr_end];
wire [gpio_data_width-1:0] gpio_data = gpio_in[gpio_data_start:gpio_data_end];

reg a_cnt, c_cnt;
reg [15:0] a_data, c_data;
assign a_data_out = a_data[num_bits-1:0];
assign c_data_out = c_data[num_bits-1:0];
reg state;

task reset();
begin
	a_data <= 0;
	a_valid <= 0;
	c_data <= 0;
	c_valid <= 0;
	a_cnt <= 0;
	c_cnt <= 0;
	state <= 0;
end
endtask

initial begin
	reset();
end

always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		reset();
	end
	else begin
		if(state == 0) begin
			if(gpio_addr == a_addr && w_clk) begin
				//Update the register and move to the next state
				a_data <= {a_data[7:0], gpio_data};
				state <= 1;
				if(a_cnt) begin//If this is the second cycle
					a_cnt <= 0;
					a_valid <= 1;
				end
				else begin
					a_cnt <= 1;
				end
			end
			else if(gpio_addr == c_addr && w_clk) begin
				//Update the register and move to the next state
				c_data <= {c_data[7:0], gpio_data};
				state <= 1;
				if(c_cnt) begin//If this is the second cycle
					c_cnt <= 0;
					c_valid <= 1;
				end
				else begin
					c_cnt <= 1;
				end
			end
		end
		else begin
			//Reset the write lines
			a_valid <= 0;
			c_valid <= 0;
			if(!w_clk) begin
				state <= 0;
			end
		end
	end
end




endmodule


