
//Sits between ADC and rest of FPGA logicware to translate ADC voltage to 8-bit value
import ising_config::*;


//Needs to take input from peak detector
module input_scaler
#(parameter start_addr = 0)
(
	input wire clk, rst,
	input wire [31:0] gpio_in,
	
	//Input from peak detector
	input wire [15:0] peak_in, //Assumed to always be valid
	input wire peak_in_valid,
	
	output reg [7:0] out_val,
	output reg out_valid
);


wire [((16*2)-1):0] layer_1_data;
wire [(2-1):0] layer_1_valid;

wire [((16*4)-1):0] layer_2_data;
wire [(2-1):0] layer_2_valid;

wire [((16*8)-1):0] layer_3_data;
wire [(2-1):0] layer_3_valid;

wire [((16*16)-1):0] layer_4_data;
wire [(2-1):0] layer_4_valid;

wire [((16*32)-1):0] layer_5_data;
wire [(2-1):0] layer_5_valid;

wire [((16*64)-1):0] layer_6_data;
wire [(2-1):0] layer_6_valid;

wire [((16*128)-1):0] layer_7_data;
wire [(2-1):0] layer_7_valid;

wire [(8*128)-1:0] output_data;
wire [127:0] output_valid;

//First layer
scaler_node #(start_addr) input_node
(
	clk, rst, gpio_in,
	peak_in, peak_in_valid,
	layer_1_data[16+:16], layer_1_data[0+:16],
	layer_1_valid[1], layer_1_valid[0]
);


genvar i, j, node_cnt, output_val_cnt;
node_cnt = 0;
output_val_cnt = -128;
//this tree layer
for(i = 1; i < 7; i = i + 1) begin
	//This node in the tree
	for(j = 0; j < 2**i; j = j + 1) begin
		node_cnt <= node_cnt + 1;
		case(i)
		
		1: begin
			scaler_node #(start_addr + node_cnt) l1_node
			(
				clk, rst, gpio_in,
				layer_1_data[(j*16)+:16], layer_1_valid[j],
				layer_2_data[(((2*j)+1)*16)+:16], layer_2_data[(((2*j)+0)*16)+:16],
				layer_2_valid[(2*j)+1], layer_2_valid[(2*j)]
			);
		end
		
		2: begin
			scaler_node #(start_addr + node_cnt) l2_node
			(
				clk, rst, gpio_in,
				layer_2_data[(j*16)+:16], layer_2_valid[j],
				layer_3_data[(((2*j)+1)*16)+:16], layer_3_data[(((2*j)+0)*16)+:16],
				layer_3_valid[(2*j)+1], layer_3_valid[(2*j)]
			);
		end
		
		3: begin
			scaler_node #(start_addr + node_cnt) l3_node
			(
				clk, rst, gpio_in,
				layer_3_data[(j*16)+:16], layer_3_valid[j],
				layer_4_data[(((2*j)+1)*16)+:16], layer_4_data[(((2*j)+0)*16)+:16],
				layer_4_valid[(2*j)+1], layer_4_valid[(2*j)]
			);
		end
		
		4: begin
			scaler_node #(start_addr + node_cnt) l4_node
			(
				clk, rst, gpio_in,
				layer_4_data[(j*16)+:16], layer_4_valid[j],
				layer_5_data[(((2*j)+1)*16)+:16], layer_5_data[(((2*j)+0)*16)+:16],
				layer_5_valid[(2*j)+1], layer_5_valid[(2*j)]
			);
		end
		
		5: begin
			scaler_node #(start_addr + node_cnt) l5_node
			(
				clk, rst, gpio_in,
				layer_5_data[(j*16)+:16], layer_5_valid[j],
				layer_6_data[(((2*j)+1)*16)+:16], layer_6_data[(((2*j)+0)*16)+:16],
				layer_6_valid[(2*j)+1], layer_6_valid[(2*j)]
			);
		end
		
		6: begin
			scaler_node #(start_addr + node_cnt) l6_node
			(
				clk, rst, gpio_in,
				layer_6_data[(j*16)+:16], layer_6_valid[j],
				layer_7_data[(((2*j)+1)*16)+:16], layer_7_data[(((2*j)+0)*16)+:16],
				layer_7_valid[(2*j)+1], layer_7_valid[(2*j)]
			);
		end
		
		7: begin
			scaler_output #(output_val_cnt+1, output_val_cnt, start_addr + node_cnt) output_node
			(
				clk, rst, gpio_in,
				layer_7_data[(j*16)+:16], layer_7_valid[j],
				output_data[(j*8)+:8],
				output_valid[j*8]
			);
			
			output_val_cnt += 2;
		end

		endcase
	end
end


genvar k;

reg [(8*16)-1:0] decode_1_data;
reg [15:0] decode_1_valid;


//First layer decode
integer m;
for(k = 0; k < 15; k = k + 1) begin
	always @ (posedge clk or negedge rst) begin
		if(!rst) begin
			decode_1_valid[k] <= 0;
			decode_1_data[(k*8)+:8] <= 0; 
		end
		else begin
			//Default case
			decode_1_valid <= 0;
			for(m = 0; m < 8; m = m + 1) begin
				if(output_valid[(k*16)+m]) begin
					decode_1_valid[k] <= 1;
					decode_1_data[(k*8)+:8] <= output_data[((k*8)+m)*8+:8]
					break;
				end
			end
		end
	end
	
end

//Second layer decode
integer n;
always @(posedge clk or negedge rst) begin
	if(!rst) begin
		out_val <= 0;
		out_valid <= 0;
	end
	else begin
		//Default case
		out_valid <= 0;
		for(n = 0; n < 16; n = n + 1) begin
			if(decode_1_valid[n]) begin
				out_val <= decode_1_data[n*8+:8];
				out_valid <= 1;
				break;
			end
		end
	end
end


endmodule



//Primitive of the input scaler
module scaler_node #(parameter bus_addr = 0)
(
	input wire clk, rst,
	
	input wire [31:0] gpio_in,
	
	//Input from previous stage
	input wire signed [15:0] in_data,
	input wire in_valid,
	
	//Output to next two stages
	output reg signed [15:0] out_data_high, out_data_low,
	output reg out_high_valid, out_low_valid
	
);

wire signed [15:0] pivot_val;
config_reg #(8,1,16, bus_addr) pivot_val_reg
(
	clk, rst,
	gpio_in, 
	pivot_val
);


always @(posedge clk or negedge rst) begin
	if(!rst) begin
		out_data_low <= 0;
		out_data_high <= 0;
		out_low_valid <= 0;
		out_high_valid <= 0;
	end
	else begin
		//If there is an incoming value
		if(in_valid)
			if(in_data > pivot_val) begin
				out_data_high <= in_data;
				out_high_valid <= 1;
				out_low_valid <= 0;
			end
			else begin
				out_data_low <= in_data;
				out_low_valid <= 1;
				out_high_valid <= 0;
			end
		end
		else begin
			//Nothing is valid
			out_high_valid <= 0;
			out_low_valid <= 0;
		end
	end
end


endmodule


//Sits at the bottom of the tree and provides the actual 8-bit value instead of just passing it along
module scaler_output
#(
parameter bus_addr = 0,
parameter high_val = 1,
parameter low_val = 0
)
(
	input wire clk, rst,
	
	input wire [31:0] gpio_in,
	
	//Input from previous stage
	input wire signed [15:0] in_data,
	input wire in_valid,
	
	//Output to end
	output reg [7:0] out_data,
	output reg out_data_valid
);

wire signed [15:0] pivot_val;
config_reg #(8,1,16, bus_addr) pivot_val_reg
(
	clk, rst,
	gpio_in, 
	pivot_val
);

always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		out_data <= 0;
		out_data_valid <= 0;
	end
	else begin
		//If we have incomming data
		if(in_valid) begin
			//Output will be valid no matter what
			out_data_valid <= 1;
			if(in_data > pivot_val) begin
				out_data <= high_val;
			end
			else begin
				out_data <= low_val;
			end
		end
		else begin
			//Nothing is valid
			out_data_valid <= 0;
		end
	end
end

endmodule