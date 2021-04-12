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

reg [(num_stages*stage_width)-1:0] dword_reg;
wire [((num_stages+1)*stage_width)-1:0] total_reg = {dword_reg, dac_word_in};

wire [15:0] sample_index_offset = {4'b0, shift_amt, 4'b0};

assign dac_word_out = total_reg[shift_amt+:stage_width]; //Set the output as a particular section of the last two dac words

integer i;
always @(posedge clk or negedge rst) begin
	if(!rst) begin
		dword_reg <= 0;
	end
	else begin//Update the internal register state
		
		for(i = 0; i < num_stages; i = i + 1) begin
			if(i == 0) begin
				dword_reg[0+:stage_width] <= dac_word_in;
			end
			else begin
				dword_reg[(i*stage_width)+:stage_width] <=dword_reg[((i-1)*stage_width)+:stage_width];
			end
		end
		
	end
end



endmodule


