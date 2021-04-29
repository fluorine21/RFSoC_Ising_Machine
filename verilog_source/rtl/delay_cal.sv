

module delay_cal
(
	input wire clk, rst,
	
	input wire trig,
	
	input wire [255:0] static_word,
	output reg [255:0] word_out
);

reg state;
always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		state <= 0;
		word_out <= 0;
	end
	else begin
		if(!state) begin
			word_out <= 0;
			if(trig) begin
				word_out <= static_word;
				state <= 1;
			end
		end
		else begin
			word_out <= 0;
			if(!trig) begin
				state <= 0;
			end
		
		end
	end
end

endmodule