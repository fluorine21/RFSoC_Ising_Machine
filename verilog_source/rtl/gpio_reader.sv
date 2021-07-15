

//Allows CPU to readback A and C fifos along with status stuff over gpio

import ising_config::*;

module gpio_reader
(
	input wire clk, rst,
	
	input wire [31:0] gpio_in,
	
	output reg [31:0] gpio_out,
	
	output wire valid,//1 if read was successful (if data was available in the a/c fifo)

	//Inputs to be read out over gpio
	input wire [15:0] del_meas_mac_result_in, del_meas_nl_result_in,
	
	input wire [num_bits-1:0] a_data,
	input wire a_valid,
	output reg a_ready,
	
	input wire [num_bits-1:0] c_data,
	input wire c_valid,
	output reg c_ready,
	
	input wire [127:0] mac_adc_data,
	input wire mac_adc_valid,
	output reg mac_adc_ready,
	
	input wire [127:0] nl_adc_data,
	input wire nl_adc_valid,
	output reg nl_adc_ready,
	
	input wire [31:0] instr_count, b_count,
	
	input wire [2:0] ex_state
);


wire w_clk = gpio_in[gpio_w_clk_bit];
wire [gpio_addr_width-1:0] gpio_addr = gpio_in[gpio_addr_start:gpio_addr_end];

reg [31:0] ac_reg;
reg ac_valid;
wire a_data_wide = { {(32-num_bits){1'b0}}, a_data}; 
wire c_data_wide = { {(32-num_bits){1'b0}}, c_data}; 

wire reg_access = (gpio_addr == a_read_reg) || 
				  (gpio_addr == c_read_reg) || 
				  (gpio_addr == mac_adc_read_reg) || 
				  (gpio_addr == nl_adc_read_reg);
assign valid = reg_access ? ac_valid : 1;//Always valid if not accessing an axis bus

reg [2:0] mac_adc_cnt, nl_adc_cnt;
reg state;

task reset();
begin
	ac_reg <= 0;
	ac_valid <= 0;
	state <= 0;
	a_ready <= 0;
	c_ready <= 0;
	mac_adc_ready <= 0;
	nl_adc_ready <= 0;
end
endtask

initial begin
	reset();
end

//fsm for reading ac back over 2 cycles
always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		reset();
	end
	else begin
		if(!state) begin
			if(w_clk) begin//Read a
				state <= 1;//Always need to wait on w_clk rst after this
				if(gpio_addr == a_read_reg && a_valid) begin
					ac_reg <= a_data_wide;
					a_ready <= 1;
					ac_valid <= 1;
				end//Read c
				else if(gpio_addr == c_read_reg && c_valid) begin
					ac_reg <= c_data_wide;
					c_ready <= 1;
					ac_valid <= 1;
				end
				else if(gpio_addr == mac_adc_read_reg && mac_adc_valid) begin
					//If this is the last read of the word
					if(mac_adc_cnt == 3'b111) begin
						mac_adc_ready <= 1;
					end
					ac_reg <= mac_adc_data[(mac_adc_cnt*32)+:32];
					mac_adc_cnt <= mac_adc_cnt + 1;
					ac_valid <= 1;
				end
				else if(gpio_addr == nl_adc_read_reg && nl_adc_valid) begin
					//If this is the last read of the word
					if(nl_adc_cnt == 3'b111) begin
						nl_adc_ready <= 1;
					end
					ac_reg <= nl_adc_data[(nl_adc_cnt*32)+:32];
					nl_adc_cnt <= nl_adc_cnt + 1;
					ac_valid <= 1;
				end
			end
		end
		else begin//Reset everything and hold valid high until write goes low
			a_ready <= 0;
			c_ready <= 0;
			mac_adc_ready <= 0;
			nl_adc_ready <= 0;
			if(!w_clk) begin
				state <= 0;
				ac_valid <= 0;
			end
		end
	end
end

//Combo logic for selecting data
always @ * begin

	case(gpio_addr)
	
		a_read_reg: begin
			gpio_out <= ac_reg;
		end
		c_read_reg: begin
			gpio_out <= ac_reg;
		end
		
		del_meas_mac_result: begin
			gpio_out <= del_meas_mac_result_in;
		end
		del_meas_nl_result: begin
			gpio_out <= del_meas_nl_result_in;
		end
		
		instr_count_reg: begin
			gpio_out <= instr_count;
		end
		b_count_reg: begin
			gpio_out <= b_count;
		end
		
		ex_state_reg: begin
			gpio_out <= {{(32-3){1'b0}}, ex_state};
		end
		
		default begin
			gpio_out <= 0;
		end
	
	endcase
end

endmodule