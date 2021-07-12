
module axis_selector
#(parameter width = 16)
(
	input wire [width-1:0] s0_axis_tdata,
	input wire s0_axis_tvalid,
	output reg s0_axis_tready,
	
	output reg [width-1:0] m0_axis_tdata,
	output reg m0_axis_tvalid,
	input wire m0_axis_tready,
	
	output reg [width-1:0] m1_axis_tdata,
	output reg m1_axis_tvalid,
	input wire m1_axis_tready,
	
	input wire sel
	
);

assign m1_axis_tdata = s0_axis_tdata;
assign m0_axis_tdata = s0_axis_tdata;

always @ * begin

	if(sel) begin
		s0_axis_tready <= m1_axis_tready;
		m1_axis_tvalid <= s0_axis_tvalid;
		
		m0_axis_tvalid <= 0;
	end
	else begin
		s0_axis_tready <= m0_axis_tready;
		m0_axis_tvalid <= s0_axis_tvalid;
		
		m1_axis_tvalid <= 0;
	end
end





endmodule