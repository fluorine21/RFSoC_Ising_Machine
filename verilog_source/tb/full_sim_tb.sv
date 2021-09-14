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


int a_del_mac_res, a_del_nl_res, bc_del_mac_res, bc_del_nl_res;


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
	
	//Set up all of the internal registers
	init_registers();
	
	//Write all the luts
	load_luts();

	//Do a delay calibration measurement
	del_cal();
	
	
	
 
end

task init_registers();
begin

	automatic reg [255:0] a_wave;
	automatic reg [255:0] a_nl_wave;
	automatic reg [255:0] phi_nl_wave;
	
	//Get the MAC and NL cal states
	automatic mac_cal_state mcs = cal_mac_chip();
	automatic nl_cal_state nlcs = cal_nl_chip();
	
	//Set phi_lo, phi, and phi_nl and the "alpha" modulators
	automatic reg [15:0] phi_lo_val = mcs.V_LO_max*dac_scale_fac;
	automatic reg [15:0] phi_val = mcs.V_phi_max*dac_scale_fac;
	automatic reg [15:0] phi_nl_val = nlcs.V_LO_max*dac_scale_fac;
	
	automatic reg [15:0] a_mac_val = mcs.V_alpha_max*dac_scale_fac;
	automatic reg [15:0] a_nl_val = nlcs.V_a_max*dac_scale_fac;

	//Neet to also get full waves for a_mac, a_nl, and phi_nl

	gpio_write(phi_lo_start_reg, phi_lo_val[15:8]);
	gpio_write(phi_lo_start_reg, phi_lo_val[7:0]);
	gpio_write(phi_start_reg, phi_val[15:8]);
	gpio_write(phi_start_reg, phi_val[7:0]);
	
	//Just start setting the shite out of everything
	gpio_write(run_trig_reg, 0);
	gpio_write(del_trig_reg, 0);
	gpio_write(halt_reg, 0);
	gpio_write(del_meas_val_reg, 127);
	gpio_write(del_meas_thresh_reg, 10);
	gpio_write(adc_run_reg, 0);
	//The shift should be 0 and we'll write the correct pulse position back
	gpio_write(mac_driver_shift_amt_reg_base_addr, 0);
	gpio_write(nl_driver_shift_amt_reg_base_addr, 0);

	//Set the shift amounts for the DACs
	set_dac_shift_amts();
	
	//Set up the ADC variables
	gpio_write(mac_sample_selector_reg, 3);
	gpio_write(nl_sample_selector_reg, 3);
	
	
	//Set up the waveforms for a, a_nl, and phi_nl (where a is the modulator at the very beginning
	a_wave = get_wave(a_mac_val);
	a_nl_wave = get_wave(a_nl_val);
	phi_nl_wave = get_wave(phi_nl_val);
	
	for(i = 16; i < 256; i = i + 16) begin
		gpio_write(a_output_reg, a_wave[i+:16]);
		gpio_write(a_nl_output_reg, a_nl_wave[i+:16]);
		gpio_write(phi_nl_output_reg, phi_nl_wave[i+:16]);
	end
	
	

end
endtask


task set_dac_shift_amts();
begin

	//Start with A MAC's output first
	automatic reg [15:0] wave_val = 16'(22000);
	//Get the right waveform
	automatic reg [255:0] a_wave = get_wave(wave_val);
	
	//Set up the MUX correctly
	gpio_write(a_dac_mux_sel_reg_base_addr, 1);
	
	//Write it to the static wave register
	for(i = 0; i < 256; i = i + 16) begin
		gpio_write(a_static_output_reg_base_addr, a_wave[i+:16]);
	end
	
	//Now look at the actual DAC output and change the shift amount until both the target sample and the sample on either side are the correct value
	j = 0;
	while(1) begin
	
		gpio_write(a_shift_amt_reg_base_addr, j);
		repeat(10) clk_cycle();
	
		if(m0_axis_tdata[(wave_pos*16)+:16] == wave_val && 
		   m0_axis_tdata[((wave_pos+1)*16)+:16] == wave_val &&
		   m0_axis_tdata[((wave_pos-1)*16)+:16] == wave_val) begin
			break;
		end
		
		
		if(j > 10) begin
			$fatal("Unable to perform shift calibration");
		end
		else begin
			j = j + 1;
		end
	end
	
	//Onto B MAC
	gpio_write(b_dac_mux_sel_reg_base_addr, 1);
	for(i = 0; i < 256; i = i + 16) begin
		gpio_write(b_static_output_reg_base_addr, a_wave[i+:16]);
	end
	
	j = 0;
	while(1) begin
	
		gpio_write(b_shift_amt_reg_base_addr, j);
		repeat(10) clk_cycle();
	
		if(m1_axis_tdata[(wave_pos*16)+:16] == wave_val && 
		   m1_axis_tdata[((wave_pos+1)*16)+:16] == wave_val &&
		   m1_axis_tdata[((wave_pos-1)*16)+:16] == wave_val) begin
			break;
		end
		
		
		if(j > 10) begin
			$fatal("Unable to perform shift calibration");
		end
		else begin
			j = j + 1;
		end
	end
	
	//Onto C MAC
	gpio_write(c_dac_mux_sel_reg_base_addr, 1);
	for(i = 0; i < 256; i = i + 16) begin
		gpio_write(c_static_output_reg_base_addr, a_wave[i+:16]);
	end
	
	j = 0;
	while(1) begin
	
		gpio_write(c_shift_amt_reg_base_addr, j);
		repeat(10) clk_cycle();
	
		if(m2_axis_tdata[(wave_pos*16)+:16] == wave_val && 
		   m2_axis_tdata[((wave_pos+1)*16)+:16] == wave_val &&
		   m2_axis_tdata[((wave_pos-1)*16)+:16] == wave_val) begin
			break;
		end
		
		
		if(j > 10) begin
			$fatal("Unable to perform shift calibration");
		end
		else begin
			j = j + 1;
		end
	end
	
	//Onto A NL
	gpio_write(a_nl_dac_mux_sel_reg_base_addr, 1);
	for(i = 0; i < 256; i = i + 16) begin
		gpio_write(a_nl_static_output_reg_base_addr, a_wave[i+:16]);
	end
	
	j = 0;
	while(1) begin
	
		gpio_write(a_nl_shift_amt_reg_base_addr, j);
		repeat(10) clk_cycle();
	
		if(m3_axis_tdata[(wave_pos*16)+:16] == wave_val && 
		   m3_axis_tdata[((wave_pos+1)*16)+:16] == wave_val &&
		   m3_axis_tdata[((wave_pos-1)*16)+:16] == wave_val) begin
			break;
		end
		
		
		if(j > 10) begin
			$fatal("Unable to perform shift calibration");
		end
		else begin
			j = j + 1;
		end
	end
end
endtask

task del_cal();
begin

	//Start the "a" delay calibration going
	gpio_write(del_trig_reg, 1);
	gpio_write(del_trig_reg, 0);
	
	i = 0;
	while(1) begin
		
		if(i > 1000) begin
			$fatal("Error, a delay measurement took more than 1000 cycles, something is wrong");
		end
		gpio_write(ex_state_reg, 0);
		if(gpio_out_bus == 0) begin//Other
			break;
		end
		i = i + 1;
	end
	
	//Readback the result
	gpio_write(del_meas_mac_result, 0);
	a_del_mac_res = gpio_out_bus;
	gpio_write(del_meas_nl_result, 0);
	a_del_nl_res = gpio_out_bus;
	$display("A MAC delay: %0d, A NL delay: %0d", a_del_mac_res, a_del_nl_res);
	
	
	//Do the same thing for BC
	gpio_write(del_trig_reg, 2);
	gpio_write(del_trig_reg, 0);
	
	i = 0;
	while(1) begin
		
		if(i > 1000) begin
			$fatal("Error, bc delay measurement took more than 1000 cycles, something is wrong");
		end
		gpio_write(ex_state_reg, 0);
		if(gpio_out_bus == 0) begin//Other
			break;
		end
		i = i + 1;
	end
	
	//Readback the result
	gpio_write(del_meas_mac_result, 0);
	bc_del_mac_res = gpio_out_bus;
	gpio_write(del_meas_nl_result, 0);
	bc_del_nl_res = gpio_out_bus;
	$display("A MAC delay: %0d, A NL delay: %0d", a_del_mac_res, a_del_nl_res);
	
	

end
endtask

task load_luts();
begin
	//Load the DAC luts
	$display("Loading DAC LUTs...");
	load_lut("lut_matlab_outputs\\lut_dac_a.csv", 0, a_output_scaler_addr_reg, a_output_scaler_data_reg);
	load_lut("lut_matlab_outputs\\lut_dac_a_nl.csv", 0, a_nl_output_scaler_addr_reg, a_nl_output_scaler_data_reg);
	load_lut("lut_matlab_outputs\\lut_dac_b.csv", 0, b_output_scaler_addr_reg, b_output_scaler_data_reg);
	load_lut("lut_matlab_outputs\\lut_dac_c.csv", 0, c_output_scaler_addr_reg, c_output_scaler_data_reg);
	//Then the ADC luts
	$display("Loading MAC ADC LUT");
	load_lut("lut_matlab_outputs\\lut_adc_mac.csv", 1, mac_driver_addr_reg, mac_driver_data_reg);
	$display("Loading NL ADC LUT");
	load_lut("lut_matlab_outputs\\lut_adc_nl.csv", 1, nl_driver_addr_reg, nl_driver_data_reg);
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

	automatic real alpha_v = (1/dac_scale_fac) * m0_axis_tdata[(wave_pos*16)+:16];
	automatic real beta_v = (1/dac_scale_fac) * m1_axis_tdata[(wave_pos*16)+:16];
	automatic real gamma_v = (1/dac_scale_fac) * m2_axis_tdata[(wave_pos*16)+:16];
	automatic real alpha_nl_v = (1/dac_scale_fac) * m3_axis_tdata[(wave_pos*16)+:16];
	automatic real phi_lo_v = (1/dac_scale_fac) * m4_axis_tdata[(wave_pos*16)+:16];
	automatic real phi_v = (1/dac_scale_fac) * m5_axis_tdata[(wave_pos*16)+:16];
	automatic real a_v = (1/dac_scale_fac) * m6_axis_tdata[(wave_pos*16)+:16];
	automatic real a_nl_v = (1/dac_scale_fac) * m7_axis_tdata[(wave_pos*16)+:16];
	automatic real phi_nl_v = (1/dac_scale_fac) * m8_axis_tdata[(wave_pos*16)+:16];
	
	//Compute the resulting currents
	automatic real I_N = I_NLA(E_in_d, a_nl_v, phi_nl_v, alpha_nl_v);
	automatic real I_M = I_MAC(E_in_d, a_v, phi_lo_v, alpha_v, beta_v, gamma_v, phi_v);
	
	//Convert the currents into results for the ADC and push them onto the bus
	automatic reg [15:0] I_N_D = 16'(int'(I_N * adc_scale_fac));
	automatic reg [15:0] I_M_D = 16'(int'(I_M * adc_scale_fac));
	
	s0_axis_tdata = { {3{16'b0}}, I_M_D, {4{16'b0}} };
	s1_axis_tdata = { {3{16'b0}}, I_N_D, {4{16'b0}} };

end
endtask

endmodule