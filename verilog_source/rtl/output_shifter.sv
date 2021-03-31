//Buffers output to DACs to implement single sample shifts



module output_shifter
(
	input wire clk, rst, 
	
	input wire [3:0] shift_amt,//Number of samples to shift by
	
	input wire [255:0] dac_word_in,
	
	output wire [255:0] dac_word_out
	
);


reg [511:0] dword_reg;

wire [7:0] sample_index_offset = {shift_amt, 4'b0};

assign dac_word_out <= dword_reg[shift_amt+:256]; //Set the output as a particular section of the last two dac words

always @(posedge clk or negedge rst) begin
	if(!rst) begin
		dword_reg <= 0;
	end
	else begin//Update the internal registe state
		dword_reg[511:256] <= dword_reg[255:0];
		dword_reg[255:0] <= dac_word_in;
	end
end



endmodule


