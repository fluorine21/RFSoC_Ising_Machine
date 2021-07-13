



module experiment_top_level_tb();


reg clk, rst;
reg [31:0] gpio_in;

wire [31:0] gpio_out_bus;

wire [255:0] m0_axis_tdata, m1_axis_tdata, m2_axis_tdata;
wire m0_axis_tvalid, m1_axis_tvalid, m2_axis_tvalid;
reg m0_axis_tready, m1_axis_tready, m2_axis_tready;

reg [127:0] s0_axis_tdata, s1_axis_tdata, s2_axis_tdata;
reg s0_axis_tvalid, s1_axis_tvalid, s2_axis_tvalid;
wire s0_axis_tready, s1_axis_tready, s2_axis_tready;

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
	s2_axis_tready,
	//////////////////////////////////
	
);

integer i, j, num_errs;

initial begin

	//Reset everything
	clk <= 0;
	rst <= 1;
	gpio_in <= 0;
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
	
	
	//Write to A
	for(i = 0; i < 16; i = i + 1) begin
		gpio_write(a_write_reg, 0);
		gpio_write(a_write_reg, i);
	end
	
	//Write to C
	for(i = 0; i < 16; i = i + 1) begin
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
	$display("A read test complete, num errs: %x\n");
	
	//Read from C
	num_errs = 0;
	for(i = 0; i < 16; i = i + 1) begin
		gpio_write(c_read_reg, 0);
		if(gpio_out_bus[15:0] != 16'(i)) begin
			num_errs = num_errs + 1;
		end
	end
	$display("C read test complete, num errs: %x\n");
	
	
	
	

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


integer program_listing[] = 
{
	

}






endmodule