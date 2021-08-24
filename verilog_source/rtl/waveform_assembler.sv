


module waveform_assembler
(
	input wire [15:0] val_in;
	output wire [255:0] val_out;
);

wire [15:0] val_inv = (~val_in) + 1; 
assign val_out = {{8{val_in}}, {8{val_inv}}};

endmodule