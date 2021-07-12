

module axis_mux
#(parameter width = 16)
(
    input wire clk,
    input wire reset,
    
    //input 0
    input wire s0_axis_tvalid,
    output wire s0_axis_tready,
    input wire [width-1:0] s0_axis_tdata,
    
    //input 1
    input wire s1_axis_tvalid,
    output wire s1_axis_tready,
    input wire [width-1:0] s1_axis_tdata,
    
    input wire sel_in,
    
    //output
    output wire [width-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready 
    
);
    
    reg int_select;
    
    initial begin
        int_select <= 0;
    end
    
    
    always @ (posedge clk or negedge reset) begin
        if(!reset) begin
            int_select <= 0;
        end
        else begin
            int_select <= sel_in;
        end
    end
    
    
    assign m_axis_tdata = int_select ? s1_axis_tdata : s0_axis_tdata;
    assign m_axis_tvalid = int_select ? s1_axis_tvalid : s0_axis_tvalid;
    assign s1_axis_tready = int_select ? m_axis_tready : 1'b0;
    assign s0_axis_tready = int_select ? 1'b0 : m_axis_tready;
    
    
endmodule