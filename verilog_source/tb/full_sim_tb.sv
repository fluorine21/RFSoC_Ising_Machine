import ising_config::*;

module full_sim();

//Filename for instruction listing and beta listing
string i_f_n = "";//todo
string b_f_n = "";//todo


reg clk, rst;

reg w_clk;
reg [15:0] gpio_addr;
reg [7:0] gpio_data;
wire [31:0] gpio_in = {8'b0,w_clk, gpio_data, gpio_addr};

wire [31:0] gpio_out_bus;


//Outputs to DACs/////////////////
wire [255:0] m0_axis_tdata; //A
wire m0_axis_tvalid;
wire m0_axis_tready = 1;

wire [255:0] m1_axis_tdata; //B
wire m1_axis_tvalid;
wire m1_axis_tready = 1;

wire [255:0] m2_axis_tdata; //C
wire m2_axis_tvalid;
wire m2_axis_tready = 1;

wire [255:0] m3_axis_tdata; //A NL output
wire m3_axis_tvalid;
wire m3_axis_tready = 1;

wire [255:0] m4_axis_tdata; //Phi LO
wire m4_axis_tvalid;
wire m4_axis_tready = 1;

wire [255:0] m5_axis_tdata; //Phi
wire m5_axis_tvalid;
wire m5_axis_tready = 1;

wire [255:0] m6_axis_tdata;
wire m6_axis_tvalid;
wire m6_axis_tready = 1;

wire [255:0] m7_axis_tdata;
wire m7_axis_tvalid;
wire m7_axis_tready = 1;

wire [255:0] m8_axis_tdata;
wire m8_axis_tvalid;
wire m8_axis_tready = 1;
//////////////////////////////////

//Inputs from ADCs////////////////
reg [127:0] s0_axis_tdata; //MAC
reg s0_axis_tvalid;
wire s0_axis_tready;

reg [127:0] s1_axis_tdata; //NL
reg s1_axis_tvalid;
wire s1_axis_tready;
//////////////////////////////////

//Input from CPU over DMA/////////
reg [15:0] s2_axis_tdata; 
reg s2_axis_tvalid;
wire s2_axis_tread;
//////////////////////////////////

integer i, j, k;


experiment_top_level_wrapper dut
(
	clk, 
	
	rst,
	
	gpio_in,
	
	gpio_out_bus,
	
	//Outputs to DACs/////////////////
	m0_axis_tdata, //A
	m0_axis_tvalid,
	m0_axis_tready,
	
	m1_axis_tdata, //B
	m1_axis_tvalid,
	m1_axis_tready,
	
	m2_axis_tdata, //C
	m2_axis_tvalid,
	m2_axis_tready,
	
	m3_axis_tdata, //A NL output
	m3_axis_tvalid,
	m3_axis_tready,
	
	m4_axis_tdata, //Phi LO
	m4_axis_tvalid,
	m4_axis_tready,
	
	m5_axis_tdata, //Phi
	m5_axis_tvalid,
	m5_axis_tready,
	
	m6_axis_tdata, //"a" (first modulator for mac)
	m6_axis_tvalid,
	m6_axis_tready,
	
	m7_axis_tdata, //"a_nl" (first modulator for nl)
	m7_axis_tvalid,
	m7_axis_tready,
	
	m8_axis_tdata, //"phi_nl"
	m8_axis_tvalid,
	m8_axis_tready,
	//////////////////////////////////
	
	//Inputs from ADCs////////////////
	s0_axis_tdata, //MAC
	s0_axis_tvalid,
	s0_axis_tready,
	
	s1_axis_tdata, //NL
	s1_axis_tvalid,
	s1_axis_tready,
	//////////////////////////////////
	
	//Input from CPU over DMA/////////
	s2_axis_tdata, 
	s2_axis_tvalid,
	s2_axis_tready
	//////////////////////////////////
	
);



initial begin
	
	//Initialize everything
	clk <= 0;
	rst <= 1;
	w_clk <= 0;
	gpio_addr <= 0;
	gpio_data <= 0;
	s0_axis_tdata <= 0;
	s0_axis_tvalid <= 1;
	s1_axis_tdata <= 0;
	s1_axis_tvalid <= 1;
	s2_axis_tdata <= 0;
	s2_axis_tvalid <= 0;
	
	//Reset everything
	repeat(10) clk_cycle();
	rst <= 0;
	repeat(10) clk_cycle();
	rst <= 1;
	repeat(10); clk_cycle();
	
	//Load the program
	//load_program(i_f_n, b_f_n);
	
	//Set up all of the internal registers
	
	
	//Write all the luts
	load_luts();

 
end

task load_luts();
begin
	//Load the DAC luts
	load_lut("lut_matlab_outputs\\lut_dac_a.csv", 0, a_output_scaler_addr_reg, a_output_scaler_data_reg);
	load_lut("lut_matlab_outputs\lut_dac_a_nl.csv", 0, a_nl_output_scaler_addr_reg, a_output_scaler_data_reg);
	load_lut("lut_matlab_outputs\lut_dac_b.csv", 0, b_output_scaler_addr_reg, b_output_scaler_data_reg);
	load_lut("lut_matlab_outputs\lut_dac_c.csv", 0, c_output_scaler_addr_reg, c_output_scaler_data_reg);
	//Then the ADC luts
	load_lut("lut_matlab_outputs\lut_adc_mac.csv", 1, mac_driver_addr_reg, mac_driver_data_reg);
	load_lut("lut_matlab_outputs\lut_adc_nl.csv", 1, nl_driver_addr_reg, nl_driver_data_reg);
end
endtask


task load_lut(string fn, int is_adc, input [15:0] addr_reg, data_reg);
begin

	automatic int fd = $fopen(fn, "r");
	automatic int fsm_val, dac_val;
	automatic int res1, res2;
	reg [15:0] fsm_cast, dac_cast;
	automatic string curr_line;
	while(!$feof(fd)) begin
		//Get the current line
		res1 = $fgets(curr_line, fd);
		//Extract the two values
		res2 = $sscanf(curr_line, "%d,%d",fsm_val, dac_val);
		//Check the fsm and DAC values
		if(fsm_val > 127) begin
			$display("Warning, found desired FSM LUT value out of range: %d", fsm_val);
			fsm_val = 127;
		end
		if(fsm_val < -128) begin
			$display("Warning, found desired FSM LUT value out of range: %d", fsm_val);
			fsm_val = -128;
		end
		if(dac_val > (65536/2)-1) begin
			$display("Warning, found desired DAC LUT value out of range: %d", dac_val);
			dac_val = (65536/2)-1;
		end
		if(dac_val < (65536/(-2))) begin
			$display("Warning, found desired DAC LUT value out of range: %d", dac_val);
			dac_val = (65536/(-2));
		end
		
		//Cast them to the correct type
		fsm_cast = 16'(fsm_val);
		dac_cast = 16'(dac_val);
		
		//Write them over GPIO
		if(!is_adc) begin
			gpio_write(addr_reg, fsm_val[15:8]);
			gpio_write(addr_reg, fsm_val[7:0]);
			gpio_write(data_reg, dac_val[15:8]);
			gpio_write(data_reg, dac_val[7:0]);
		end
		else begin//Other way around for adc
			gpio_write(addr_reg, dac_val[15:8]);
			gpio_write(addr_reg, dac_val[7:0]);
			gpio_write(data_reg, fsm_val[15:8]);
			gpio_write(data_reg, fsm_val[7:0]);
		end
		
	end
	$fclose(fd);

end
endtask


task load_program(string instr_filename, beta_filename);
begin
	//Load the instructions from disk
	integer instr_listing[];
	integer beta_listing[];
	instr_listing = {};
	$readmemh(instr_filename, instr_listing);
	if($size(instr_listing) > 2**instr_fifo_depth) begin
		$error("Error, instruction listing too long! Either change instr_fifo_depth in ising_config or have a smaller program you absolute gammon!");
	end
	
	//Load the beta values from disk
	beta_listing = {};
	$readmemh(beta_filename, beta_listing);
	if($size(beta_listing) > 2**instr_fifo_depth) begin
		$error("Error, beta listing too long! Either change instr_fifo_depth in ising_config or have a smaller beta listing you absolute gammon!");
	end
	
	//Write the instruction listing to the internal fifo
	gpio_write(instr_b_sel_reg, 0);
	s2_axis_tvalid <= 1;
	for(i = 0; i < $size(instr_listing); i = i + 1) begin
		s2_axis_tdata <= instr_listing[i];
		clk_cycle();
	end
	s2_axis_tvalid <= 0;
	
	//Write the beta listing to the internal fifo
	gpio_write(instr_b_sel_reg, 1);
	s2_axis_tvalid <= 1;
	for(i = 0; i < $size(beta_listing); i = i + 1) begin
		s2_axis_tdata <= beta_listing[i];
		clk_cycle();
	end
	s2_axis_tvalid <= 0;

end
endtask


task clk_cycle();
begin
	#1
	clk <= 1;
	#1
	#1
	clk <= 0;
	#1
	clk <= 0;
	
	update_chip_state();
end
endtask

task gpio_write;
input [15:0] addr;
input [7:0] data;
begin
	
	repeat(2) clk_cycle();
	gpio_addr <= addr;
	gpio_data <= data;
	clk_cycle();
	w_clk <= 1;
	repeat(2) clk_cycle();
	w_clk <= 0;
	
end
endtask


task update_chip_state();
begin

	//First we take the modulator 16-bit values for a, alpha, etc and turn them into floating point numbers

	automatic real alpha_v = dac_scale_fac * m0_axis_tdata[(wave_pos*16)+:16];
	automatic real beta_v = dac_scale_fac * m1_axis_tdata[(wave_pos*16)+:16];
	automatic real gamma_v = dac_scale_fac * m2_axis_tdata[(wave_pos*16)+:16];
	automatic real alpha_nl_v = dac_scale_fac * m3_axis_tdata[(wave_pos*16)+:16];
	automatic real phi_lo_v = dac_scale_fac * m4_axis_tdata[(wave_pos*16)+:16];
	automatic real phi_v = dac_scale_fac * m5_axis_tdata[(wave_pos*16)+:16];
	automatic real a_v = dac_scale_fac * m6_axis_tdata[(wave_pos*16)+:16];
	automatic real a_nl_v = dac_scale_fac * m7_axis_tdata[(wave_pos*16)+:16];
	automatic real phi_nl_v = dac_scale_fac * m8_axis_tdata[(wave_pos*16)+:16];
	
	//Compute the resulting currents
	automatic real I_N = I_NLA(E_in_d, a_nl_v, phi_nl_v, alpha_nl_v);
	automatic real I_M = I_MAC(E_in_d, a_v, phi_lo_v, alpha_v, beta_v, gamma_v, phi_v);
	
	//Convert the currents into results for the ADC and push them onto the bus
	automatic reg [15:0] I_N_D = I_N * adc_scale_fac;
	automatic reg [15:0] I_M_D = I_M * adc_scale_fac;
	
	s0_axis_tdata = { {3{16'b0}}, I_M_D, {4{16'b0}} };
	s1_axis_tdata = { {3{16'b0}}, I_N_D, {4{16'b0}} };

end
endtask

endmodule