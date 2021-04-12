


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

reg del_trig;

adc_driver #(0, 1, 2) adc_driver_inst
(
	clk, rst,	
	gpio_in,
	
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
	m_axis_tready,
	
	del_trig
	
);



integer i, j, k, num_errs;

//External lookup tables used to generate internal lookup table
integer lookup_table_in[256];
integer lookup_table_out[256];


initial begin

	//Generate the lookup table listing (evenly spaced)
	j = 0;
	for(i = 127; i > -129; i = i - 1) begin
		lookup_table_in[j] = i * 8;
		lookup_table_out[j] = i;
		j = j + 1;
	end
	
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
	del_trig <= 0;
	
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
	adc_input_scaler_run <= 1;
	for(i = 0; i < 256; i = i + 1) begin
		
		//Set the current data and cycle the clock
		s_axis_tdata <= {{1{16'b0}}, 16'(unsigned'(lookup_table_in[i])), {6{16'b0}}};
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
	
	adc_input_scaler_run <= 0;
	
	$display("\nADC decode test complete, num errs: %x\n", num_errs);
	
	
	//Reset everything 
	repeat(10) clk_cycle();
	rst <= 0;
	repeat(10) clk_cycle();
	rst <= 1;
	repeat(20) clk_cycle();
	
	//Start the ADC readback
	del_trig <= 1;
	
	
	for(i = 0; i < 1024; i = i + 1) begin
		//Set the current data and cycle the clock
		s_axis_tdata <= {{4{16'b0}}, i, {3{16'b0}}};
		clk_cycle();
	end
	
	//Stop the adc readback
	del_trig <= 0;
	
	//Start reading out the adc
	m_axis_tready <= 1;
	
	repeat(1100) clk_cycle();
	
end

task clk_cycle();
begin
	#1
	clk <= 1;
	#1
	#1
	clk <= 0;
	#1
	clk <= 0;
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
	w_clk <= 1;
	repeat(2) clk_cycle();
	w_clk <= 0;
	repeat(5) clk_cycle();
	
end
endtask


task write_lookup_table
(
integer lut_in[], integer lut_out[]
);
begin
	//Internal lookup table generation
	integer lut_data[65536];
	integer p;
	integer signed m, n, midp, r;
	
	p = 0;
	n = 0;//in out counter
	
	for(m = 32767; m >= -32768; m = m - 1) begin
		p = 16'(unsigned'(m));
		lut_data[p] = lut_out[n];//Write this entry to the lookup table
		//If we're at the halfway point between the 0th and 1st entries
		midp = ((lut_in[n]+lut_in[n+1])/2);
		if(n < 255 && m <= midp) begin
			n = n + 1;
		end
	end
	
	//Writing the lookup table
	gpio_write(0, 0);
	gpio_write(0, 0);
	for(r = 0; r < 65536; r = r + 1) begin
		gpio_write(1, 0);
		gpio_write(1, 8'(lut_data[r]));
	end

end
endtask


endmodule