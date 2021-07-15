



module counter_fifo
#(parameter width = 16, parameter mem_width = 16)
(
	input wire clk, rst,
	
	input wire [width-1:0] s_axis_tdata,
	input wire s_axis_tvalid,
	output wire s_axis_tready,
	
	output wire [width-1:0] m_axis_tdata,
	output wire m_axis_tvalid,
	input wire m_axis_tready,
	
	output reg [31:0] count
);

axis_sync_fifo #(mem_width,width) fifo_inst
(

	rst,
	clk,

    s_axis_tvalid,
    s_axis_tready,
    s_axis_tdata,
    
    m_axis_tdata,
    m_axis_tvalid,
    m_axis_tready 
);

wire s_t = s_axis_tvalid & s_axis_tready;
wire m_t = m_axis_tvalid & s_axis_tready;

initial begin count <= 0; end

always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		count <= 0;
	end
	else begin
		if(s_t & m_t) begin
			count <= count;
		end
		else if(s_t) begin
			count <= count + 1;
		end
		else if(m_t) begin
			count <= count - 1;
		end
		else begin
			count <= count;
		end
	end
end


endmodule