//Buffers output to DACs to implement single sample shifts



module shifter
#(
parameter num_stages = 16,
parameter stage_width = 256
)
(
	input wire clk, rst, 
	
	input wire [7:0] shift_amt,//Number of samples to shift by
	
	input wire [stage_width-1:0] dac_word_in,
	
	output wire [stage_width-1:0] dac_word_out
	
);

parameter num_samples_shifts_possible = num_stages*16;

initial begin
	if(num_stages*stage_width != 4096) begin
		$error("Number of stages times the stage width in bits must be 4096 to have 256 shift positions");
	end
end


reg [((num_stages)*stage_width)-1:0] total_reg;

wire [15:0] sample_index_offset = {4'b0, shift_amt, 4'b0};

assign dac_word_out = total_reg[sample_index_offset+:stage_width]; //Set the output as a particular section of the last two dac words

always @(posedge clk or negedge rst) begin
	if(!rst) begin
		total_reg <= 0;
	end
	else begin//Update the internal register state
		total_reg <= {total_reg[((num_stages-1)*stage_width)-1:0], dac_word_in};
	end
end



endmodule


