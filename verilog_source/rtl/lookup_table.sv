
import ising_config::*;


//Takes two gpio writes for addr and data
module lookup_table 
#(
//GPIO bus addresses
parameter addr_reg = 0,
parameter data_reg = 1,
parameter in_bits = 16,
parameter out_bits = 16
)
(
	input wire clk, rst,
	input wire [31:0] gpio_in,
	
	input wire [in_bits-1:0] val_in,
	input wire val_in_valid,
	
	output reg [out_bits-1:0] val_out,
	output reg val_out_valid
);

//Lookup table memory
reg [out_bits-1:0] lut_mem[0:(2**in_bits)-1];

//GPIO bus definitions
wire w_clk = gpio_in[gpio_w_clk_bit];
wire [gpio_addr_width-1:0] gpio_addr = gpio_in[gpio_addr_start:gpio_addr_end];
wire [gpio_data_width-1:0] gpio_data = gpio_in[gpio_data_start:gpio_data_end];

//Input scaler address and data registers
reg [15:0] i_scaler_addr;
reg [7:0] i_scaler_data;
reg addr_state;
reg wr_cnt;

wire [15:0] lut_next_word = {i_scaler_data, gpio_data};

wire [in_bits-1:0] eff_addr = i_scaler_addr[in_bits-1:0];


always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		i_scaler_addr <= 0;
		addr_state <= 0;
		wr_cnt <= 0;
		i_scaler_data <= 0;
	end
	else begin
		case(addr_state)

		0: begin
			if(gpio_addr == addr_reg && w_clk) begin
				//update the address
				i_scaler_addr <= {i_scaler_addr[7:0], gpio_data};
				//Go to wait state
				addr_state <= 1;
			end
			//If we're writing data to the lookup table
			else if(gpio_addr == data_reg && w_clk) begin
				addr_state <= 1;
				
				//If this is the first time we're writing the data register
				if(wr_cnt == 0) begin
					i_scaler_data <= gpio_data;
					wr_cnt <= 1;
				end
				//Otherwise write to memory
				else begin
					lut_mem[eff_addr] <= lut_next_word[out_bits-1:0];//Select the lowest bits if we're working on an output word smaller than 8 bits
					wr_cnt <= 0;
					//Increment the address
					i_scaler_addr <= i_scaler_addr + 1;
				end
			end
		end
		
		1: begin
			if(!w_clk) begin
				addr_state <= 0;
			end
		end
		
		endcase
	end
end

//Readback block
always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		val_out <= 0;
		val_out_valid <= 0;
	end
	else begin
		if(val_in_valid) begin
			val_out <= lut_mem[val_in];
			val_out_valid <= 1;
		end
		else begin
			val_out_valid <= 0;
		end
	end

end


endmodule