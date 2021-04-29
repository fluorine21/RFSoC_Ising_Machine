
import ising_config::*;

module dac_driver_tb();

reg clk, rst;

//GPIO definition
reg w_clk;
reg [15:0] gpio_addr;
reg [7:0] gpio_data;
wire [31:0] gpio_in = {8'b0,w_clk, gpio_data, gpio_addr};
	

reg [num_bits-1:0] fsm_val_in;
	
reg	[255:0] static_word;
reg	fsm_in_valid;
	
reg	del_trig;
	
wire [255:0] dac_out;


dac_driver
#(0,1,2,3,4) dut
(
	clk, rst,
	
	gpio_in,
	
	fsm_val_in,
	fsm_in_valid,
	
	del_trig,
	
	dac_out
);

integer i, j, num_errs;
reg [255:0] t;

initial begin

	clk <= 0;
	rst <= 0;
	
	w_clk <= 0;
	gpio_addr <= 0;
	gpio_data <= 0;
	
	fsm_in_valid <= 0;
	fsm_val_in <= 0;
	
	del_trig <= 0;

	//Reset everything 
	repeat(10) clk_cycle();
	rst <= 0;
	repeat(10) clk_cycle();
	rst <= 1;
	repeat(20) clk_cycle();
	
	//Write the lookup table
	write_lookup_table();
	
	//Set the static word
	static_word <= { {1{16'b0}}, {{8{16'hffff}}}, {7{16'b0}} };
	
	//32 bytes in 16 16 bit words :)
	for(i = 0; i < 32; i = i + 1) begin
		gpio_write(2, static_word[(i*8)+:16]); 
	end
	
	//Set the mux to 1
	gpio_write(3, 1);
	repeat(100) clk_cycle();
	
	//Set the mux to 2
	gpio_write(3, 2);
	repeat(100) clk_cycle();
	
	//Triger
	del_trig <= 1;
	clk_cycle();
	repeat(1000);
	
	//Stop triggering
	del_trig <= 0;
	
	//set the mux to 0
	gpio_write(3, 0);
	
	repeat(100) clk_cycle();
	
	//Start the test
	
	fsm_in_valid <= 1;
	for(i = 0; i <= 2**num_bits-1; i = i + 1) begin
	
			fsm_val_in <= num_bits'(i);
			
			t = { {1{16'b0}}, {{8{16'((i-1)*-1)}}}, {7{16'b0}} };
			if(i) begin//Skip the first cycle
				if(dac_out != t) begin
					num_errs = num_errs + 1;
				end
			end
	end
	
	$display("DAC driver test complete, num_errs = %i", num_errs);
	
	repeat(100) clk_cycle();
	
	
	//Test the shift
	repeat(100) clk_cycle();
	
	for(i = 0; i < 256; i = i + 1) begin
		//TODO
		
		//Write new shift value
		
		//Give it a few cycles
		
		//Check
	
	end

end


task write_lookup_table();
begin
	
	gpio_write(0, 0);
	gpio_write(0, 0);
	
	for(i = 0; i < 2**16; i = i + 1) begin
		gpio_write(1, (~i)+1);
	end

end
endtask


task clk_cycle;
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



endmodule