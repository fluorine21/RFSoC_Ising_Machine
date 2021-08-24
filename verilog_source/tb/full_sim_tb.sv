

module full_sim();


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



endmodule