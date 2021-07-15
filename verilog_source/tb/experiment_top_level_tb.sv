
import ising_config::*;


module experiment_top_level_tb();


reg clk, rst;

reg w_clk;
reg [15:0] gpio_addr;
reg [7:0] gpio_data;
wire [31:0] gpio_in = {8'b0,w_clk, gpio_data, gpio_addr};

wire [31:0] gpio_out_bus;

wire [255:0] m0_axis_tdata, m1_axis_tdata, m2_axis_tdata;
wire m0_axis_tvalid, m1_axis_tvalid, m2_axis_tvalid;
reg m0_axis_tready, m1_axis_tready, m2_axis_tready;



reg [127:0] s0_axis_tdata, s1_axis_tdata;
reg s0_axis_tvalid, s1_axis_tvalid, s2_axis_tvalid;
wire s0_axis_tready, s1_axis_tready, s2_axis_tready;
reg [15:0]  s2_axis_tdata;

experiment_top_level dut
(
	clk, rst,
	
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

integer i, j, num_errs;

initial begin

	//Reset everything
	clk <= 0;
	rst <= 1;
	gpio_addr <= 0;
	gpio_data <= 0;
	w_clk <= 0;
	m0_axis_tready <= 1;
	m1_axis_tready <= 1;
	m2_axis_tready <= 1;

	s0_axis_tvalid <= 1;
	s1_axis_tvalid <= 1;
	s2_axis_tvalid <= 0;
	s0_axis_tdata <= 0;
	s1_axis_tdata <= 0;
	s2_axis_tdata <= 0;
	
	repeat(10) clk_cycle();
	rst <= 0;
	repeat(10) clk_cycle();
	rst <= 1;
	repeat(10) clk_cycle();
	
	//Write the lookup tables for input and output
	gpio_write(a_output_scaler_addr_reg, 0);
	gpio_write(a_output_scaler_addr_reg, 0);
	
	for(i = 0; i < 256; i = i + 1) begin
		gpio_write(a_output_scaler_data_reg, -1*8'(i));
		gpio_write(a_output_scaler_data_reg, -1*8'(i));
	end
	
	gpio_write(b_output_scaler_addr_reg, 0);
	gpio_write(b_output_scaler_addr_reg, 0);
	
	for(i = 0; i < 256; i = i + 1) begin
		gpio_write(b_output_scaler_data_reg, 1*8'(i));
		gpio_write(b_output_scaler_data_reg, -1*8'(i));
	end
	
	gpio_write(c_output_scaler_addr_reg, 0);
	gpio_write(c_output_scaler_addr_reg, 0);
	
	for(i = 0; i < 256; i = i + 1) begin
		gpio_write(c_output_scaler_data_reg, 1*8'(i));
		gpio_write(c_output_scaler_data_reg, 1*8'(i));
	end
	
	//Write lookup tables for inputs
	
	gpio_write(mac_driver_addr_reg, 0);
	gpio_write(mac_driver_addr_reg, 0);
	
	for(i = 0; i < 65536; i = i + 1) begin
		gpio_write(mac_driver_data_reg, i);
		gpio_write(mac_driver_data_reg, i);
	end
	
	gpio_write(nl_driver_addr_reg, 0);
	gpio_write(nl_driver_addr_reg, 0);
	
	for(i = 0; i < 65536; i = i + 1) begin
		gpio_write(nl_driver_data_reg, i);
		gpio_write(nl_driver_data_reg, i);
	end
	
	
	
	//Write to A
	for(i = 0; i < 16; i = i + 1) begin
		gpio_write(a_write_reg, 0);
		gpio_write(a_write_reg, i);
	end
	
	//Write to C
	for(i = 16; i < 32; i = i + 1) begin
		gpio_write(c_write_reg, 0);
		gpio_write(c_write_reg, i);
	end

	//Read from A
	num_errs = 0;
	for(i = 0; i < 16; i = i + 1) begin
		gpio_write(a_read_reg, 0);
		if(gpio_out_bus[15:0] != 16'(i)) begin
			num_errs = num_errs + 1;
		end
	end
	$display("A read test complete, num errs: %x\n", num_errs);
	
	//Read from C
	num_errs = 0;
	for(i = 16; i < 32; i = i + 1) begin
		gpio_write(c_read_reg, 0);
		if(gpio_out_bus[15:0] != 16'(i)) begin
			num_errs = num_errs + 1;
		end
	end
	$display("C read test complete, num errs: %x\n", num_errs);
	
	
	
	
	//Set gpio write to instr
	gpio_write(instr_b_sel_reg, 0);
	//Write the instructions
	for(i = 0; i < $size(program_1); i = i + 1) begin
		//Set the valid and data lines
		s2_axis_tdata <= program_1[i];
		s2_axis_tvalid <= 1;
		clk_cycle();
	end
	
	s2_axis_tvalid <= 0;
	
	//Switch to b
	gpio_write(instr_b_sel_reg, 1);
	//Write in 9 values
	for(i = 0; i < 8; i = i + 1) begin
		s2_axis_tdata <= i;
		s2_axis_tvalid <= 1;
		clk_cycle();
	end
	//Finish off that last write with something special
	s2_axis_tdata <= 8'hFF;
	clk_cycle();
	s2_axis_tvalid <= 0;
	
	//Write to A
	for(i = 0; i < 16; i = i + 1) begin
		gpio_write(a_write_reg, 0);
		gpio_write(a_write_reg, i);
	end
	
	//Write to C
	for(i = 16; i < 32; i = i + 1) begin
		gpio_write(c_write_reg, 0);
		gpio_write(c_write_reg, i);
	end
	
	//Tell the thing to run
	gpio_write(run_trig_reg, 1);
	
	clk_cycle();
	
	//Make sure it isn;t in the idle state
	gpio_write(ex_state_reg, 0);
	if(gpio_out_bus == 0) begin
		$display("Error, FSM did not go to run state on run command!");
	end
	
	//Check outputs here :)
	//TODO
	
	//Wait 100 cycles
	repeat(100) clk_cycle();
	
	//Should be in run state here
	if(gpio_out_bus != 3) begin
		$display("Error, FSM left run state early");
	end
	
	gpio_write(halt_reg, 1);
	clk_cycle();
	
	//Make sure we're in the wait rst state
	if(gpio_out_bus != 4) begin
		$display("Error, FSM was not in wait rst state!");
	end
	
	gpio_write(halt_reg, 0);
	gpio_write(run_trig_reg, 0);
	clk_cycle();
	
	if(gpio_out_bus != 0) begin
		$display("Error, FSM did not return to idle state");
	end
	
	
	
	
	
	
	

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
	
	repeat(2) clk_cycle();
	gpio_addr <= addr;
	gpio_data <= data;
	clk_cycle();
	w_clk <= 1;
	repeat(2) clk_cycle();
	w_clk <= 0;
	
end
endtask



endmodule