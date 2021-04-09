


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


adc_driver #(0, 1, 2) adc_driver_inst
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



integer i, j, k, num_errs;

//External lookup tables used to generate internal lookup table
integer lookup_table_in[256];
integer lookup_table_out[256];


initial begin

	//Generate the lookup table listing (evenly spaced)
	j = 0;
	for(i = 127; i > -128; i = i - 1) begin
		lookup_table_in[j] = i * 8;
		lookup_table_out[j] = i;
		j = j + 1;
	end
	
	//Generate the internal lookup table
	
	
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
	
	//reset cycle
	repeat(10) clk_cycle();
	rst <= 0;
	repeat(10) clk_cycle();
	rst <= 1;
	repeat(20) clk_cycle();
	
	//Load the lookup table
	write_lookup_table(lookup_table_in, lookup_table_out);

	
	j = 0;//Output val counter
	num_errs = 0;
	//Start writing values to ADC driver
	s_axis_tvalid <= 1;
	for(i = 0; i < 256; i = i + 1) begin
		
		//Set the current data and cycle the clock
		s_axis_tdata <= {{4{16'b0}}, lookup_table_in[i], {3{16'b0}}};
		clk_cycle();
		
		//If there's something coming out the other end
		if(val_valid) begin
			//See if we got the correct value out
			if(val_out != lookup_table_out[j]) begin
				num_errs = num_errs + 1;
			end
			j = j + 1;
		
		end
	end
	
	$display("\nADC decode test complete, num errs: %x\n", num_errs);
	
	
	//Reset everything 
	repeat(10) clk_cycle();
	rst <= 0;
	repeat(10) clk_cycle();
	rst <= 1;
	repeat(20) clk_cycle();
	
	//Start the ADC readback
	gpio_write(2, 1);
	
	
	for(i = 0; i < 1024; i = i + 1) begin
		//Set the current data and cycle the clock
		s_axis_tdata <= {{4{16'b0}}, i, {3{16'b0}}};
		clk_cycle();
	end
	
	//Stop the adc readback
	gpio_write(256, 0);
	
	//Start reading out the adc
	s_axis_tready <= 1;
	
	repeat(1100) clk_cycle();
	
	$finish
	
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
	ref integer in_list[], out_list[]
);
begin
	integer i, avg;
	for(i = 0; i < size(in_list); i = i + 2) begin
		avg = (in_list[i]+in_list[i+1])/2;
		out_list[i/2] = avg;
	end
end
endtask


task write_lookup_table
(
integer lut_in[], integer lut_out[], integer addr_reg, integer data_reg
);
begin
	//Internal lookup table generation
	integer lut_data[65536];
	integer signed i, j;
	reg [15:0] k;
	j = 0;//in out counter
	for(i = 32767, i >= -32768; i = i - 1) begin
		k = unsigned'(i);
		lut_data[k] = lut_out[j];//Write this entry to the lookup table
		//If we're at the halfway point between the 0th and 1st entries
		if(i < lut_in[j] - ((lut_in[j]-lut_in[j+1])/2) && j < 255) begin
			j = j + 1;
		end
	end
	
	//Writing the lookup table
	gpio_write(0, 0);
	gpio_write(0, 0);
	for(i = 0; i < 65536; i = i + 1) begin
		gpio_write(0, 1);
		gpio_write(0, 8'(lut_data[i]));
	end

end
endtask


endmodule