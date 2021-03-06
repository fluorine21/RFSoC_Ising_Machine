module experiment_top_level_wrapper
(
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire clk, 
	
	input wire rst,
	
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire [31:0] gpio_in,
	
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire [31:0] gpio_out_bus,
	
	
	//Outputs to DACs/////////////////
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire [255:0] m0_axis_tdata, //A
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire m0_axis_tvalid,
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire m0_axis_tready,
	
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire [255:0] m1_axis_tdata, //B
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire m1_axis_tvalid,
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire m1_axis_tready,
	
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire [255:0] m2_axis_tdata, //C
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire m2_axis_tvalid,
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire m2_axis_tready,
	
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire [255:0] m3_axis_tdata, //A NL output
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire m3_axis_tvalid,
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire m3_axis_tready,
	
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire [255:0] m4_axis_tdata, //Phi LO
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire m4_axis_tvalid,
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire m4_axis_tready,
	
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire [255:0] m5_axis_tdata, //Phi
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire m5_axis_tvalid,
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire m5_axis_tready,
	
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire [255:0] m6_axis_tdata, //"a" output (see gordo doc)
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire m6_axis_tvalid,
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire m6_axis_tready,
	
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire [255:0] m7_axis_tdata, //"a_nl" output (see gordo doc)
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire m7_axis_tvalid,
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire m7_axis_tready,
	
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire [255:0] m8_axis_tdata, //"phi_nl" output (see gordo doc)
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire m8_axis_tvalid,
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire m8_axis_tready,
	//////////////////////////////////
	
	//Inputs from ADCs////////////////
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire [127:0] s0_axis_tdata, //MAC
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire s0_axis_tvalid,
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire s0_axis_tready,
	
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire [127:0] s1_axis_tdata, //NL
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire s1_axis_tvalid,
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire s1_axis_tready,
	//////////////////////////////////
	
	//Input from CPU over DMA/////////
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire [15:0] s2_axis_tdata, 
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) input wire s2_axis_tvalid,
	(* X_INTERFACE_PARAMETER = "FREQ_HZ 250000000"*) output wire s2_axis_tready
	//////////////////////////////////
	
);


experiment_top_level ex_top_level_inst_in_wrapper
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
	
	m3_axis_tdata, //A NL
	m3_axis_tvalid,
	m3_axis_tready,
	
	m4_axis_tdata, 
	m4_axis_tvalid,
	m4_axis_tready,
	
	m5_axis_tdata, 
	m5_axis_tvalid,
	m5_axis_tready,
	
	m6_axis_tdata, 
	m6_axis_tvalid,
	m6_axis_tready,
	
	m7_axis_tdata, 
	m7_axis_tvalid,
	m7_axis_tready,
	
	m8_axis_tdata, 
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

);



endmodule