


module adc_driver_tb();

reg clk, rst;

reg w_clk;
reg [15:0] gpio_addr;
reg [7:0] gpio_data;

wire [31:0] gpio_in = {8'b0,w_clk, gpio_data, gpio_addr};
reg [127:0] s_axis_tdata;
reg s_axis_tvalid;
wire s_axis_tready;
wire [7:0] val_out;
wire val_valid;	
reg adc_input_scaler_run;//From FSM, tells input scaler to start processing data
//Output to PS over DMA
wire [127:0] m_axis_tdata;
wire m_axis_tvalid;
reg m_axis_tready;


adc_driver #(0,256) adc_driver_inst
(
	clk, rst,	
	gpio_in
	
	//Input from ADC
	s_axis_tdata,
	s_axis_tvalid,
	s_axis_tready,
	
	//Output to experiment FSM
	val_out,
	val_valid,
	
	adc_input_scaler_run,//From FSM, tells input scaler to start processing data
	
	//Output to PS over DMA
	m_axis_tdata,
	m_axis_tvalid,
	m_axis_tready
	
);

integer lookup_table_in[256];
integer lookup_table_out[256];
integer layer_7[128];
integer layer_6[64];
integer layer_5[32];
integer layer_4[16];
integer layer_3[8];
integer layer_2[4];
integer layer_1[2];

integer i, j, k;


initial begin

	//Generate the lookup table listing (evenly spaced)
	j = 0;
	for(i = 127; i > 128; i = i - 1) begin
		lookup_table_in[j] = i;
		lookup_table_out[j] = i;
		j = j + 1;
	end
	
	//Then generate the layers
	generate_layer(lookup_table_in, layer_7);
	generate_layer(layer_7, layer_6);
	generate_layer(layer_6, layer_5);
	generate_layer(layer_5, layer_4);
	generate_layer(layer_4, layer_3);
	generate_layer(layer_3, layer_2);
	generate_layer(layer_2, layer_1);
	
	//Start the logic simulation
	clk <= 0;
	rst <= 1;
	
	w_clk <= 0;
	gpio_addr <= 0;
	gpio_data <= 0;
	s_axis_tdata <= 0;
	s_axis_tvalid <= 0;
	adc_input_scaler_run <= 0; //Might need to start this a cycle late so it skips whatever was waiting inside the peak detector
	m_axis_tready <= 0;
	
	
	
end

task clk_cycle;
begin
	#1
	clk <= 1;
	#1
	#1
	clk <= 0;
	#1
end
endtask

task gpio_write;
input [15:0] addr;
input [7:0] data;
begin
	
	clk_cycle();
	gpio_addr <= addr;
	gpio_data <= data;
	clk_cycle();
	gpio_write <= 1;
	repeat(2) clk_cycle();
	gpio_write <= 0;
	repeat(5) clk_cycle();
	
end
endtask

task generate_layer
(
	ref in_list, out_list
);
begin
	integer i, avg;
	for(i = 0; i < size(in_list); i = i + 2) begin
		avg = (in_list[i]+in_list[i+1])/2;
		out_list[i/2] = avg;
	end
end
endtask



endmodule