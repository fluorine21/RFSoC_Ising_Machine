

module full_sim();

//Filename for instruction listing and beta listing
string i_f_n;//todo
string b_f_n;//todo


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
	
	m6_axis_tdata, //"a"
	m6_axis_tvalid,
	m6_axis_tready,
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

	//Load the program
	load_program(i_f_n, b_f_n);
	
	//Set up all of the internal registers
	
	
	//Write the output lookup tables
	
	
	//Write the input lookup tables


end



task load_program(string inst_filename, beta_filename);

	//Load the instructions from disk
	integer instr_listing[];
	instr_listing = {};
	$readmemh(instr_filename, instr_listing);
	if($size(instr_listing) > 2**instr_fifo_depth) begin
		$error("Error, instruction listing too long! Either change instr_fifo_depth in ising_config or have a smaller program you absolute gammon!");
	end
	//Load the beta values from disk
	integer beta_listing[];
	beta_listing = {};
	$readmemh(beta_filename, beta_listing);
	if($size(beta_listing) > 2**instr_fifo_depth) begin
		$error("Error, beta listing too long! Either change instr_fifo_depth in ising_config or have a smaller beta listing you absolute gammon!");
	end
	
	//Write the instruction listing to the internal fifo
	gpio_write(instr_b_sel_reg, 0)
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

begin


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

	real alpha_v = scale_fac * m0_axis_tdata[(wave_pos*16):+16];
	real beta_v = scale_fac * m1_axis_tdata[(wave_pos*16):+16];
	real gamma_v = scale_fac * m2_axis_tdata[(wave_pos*16):+16];
	real alpha_nl_v = scale_fac * m3_axis_tdata[(wave_pos*16):+16];
	real phi_lo_v = scale_fac * m4_axis_tdata[(wave_pos*16):+16];
	real phi_v = scale_fac * m5_axis_tdata[(wave_pos*16):+16];
	real a_v = scale_fac * m6_axis_tdata[(wave_pos*16):+16];
	real a_nl_v = scale_fac * m7_axis_tdata[(wave_pos*16):+16];
	real phi_nl_v = scale_fac * m8_axis_tdata[(wave_pos*16):+16];
	
	//Compute the resulting currents
	real I_N = I_NLA(E_in, a_nl_v, phi_nl_v, alpha_nl_v);
	real I_M = I_MAC(E_in, a_v, phi_lo_v, alpha_v, beta_v, gamma_v, phi_v);
	
	//Convert the currents into results for the ADC and push them onto the bus
	reg [15:0] I_N_D = I_N * adc_scale_fac;
	reg [15:0] I_M_D = I_M * adc_scale_fac;
	
	s0_axis_tdata = { {3{16'b0}}, I_M_D, {4{16'b0}} };
	s1_axis_tdata = { {3{16'b0}}, I_N_D, {4{16'b0}} };

end
endtask

endmodule