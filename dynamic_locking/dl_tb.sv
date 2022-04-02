import ising_config::*;


module dl_tb();

reg clk, rst;
reg w_clk;
reg [15:0] gpio_addr;
reg [7:0] gpio_data;
wire [31:0] gpio_in = {8'b0,w_clk, gpio_data, gpio_addr};

reg [127:0] adc_data_in;

reg lock_sig_active, trig_lock;

wire lock_done;
wire [15:0] setpt_out_ext;//Setpoint


//scale factor
real dl_to_mzi_scale_fac = 0.01;
real mzi_to_dl_scale_fac = 100;
reg [15:0] mzi_res;
real setpt_cast;

dl #(0) dut
(
	clk, rst, 
	gpio_in,
	
	//Incomming ADC data
	adc_data_in,
	
	lock_sig_active,//if 1, a calibration pulse is currently being read back and must be locked to
	trig_lock,//if 1, we're actively running the fsm and trying to lock
	lock_done,//If 1, this module is not in the process of locking
	
	setpt_out_ext//Setpoint output of the lockbox
);

reg [63:0] step_num;


initial begin

	test_mzi_sim();
	
	clk <= 0;
	rst <= 1;
	gpio_addr <= 0;
	gpio_data <= 0;
	w_clk <= 0;
	adc_data_in <= 0;
	lock_sig_active <= 0;
	trig_lock <= 0;
	
	repeat(10) clk_cycle();
	rst <= 0;
	repeat(10) clk_cycle();
	rst <= 1;
	repeat(10) clk_cycle();
	
	
	//Write the max_pos_tol
	gpio_write_word(0,0, 2);
	//write setpt_in;
	gpio_write_word(1, 1000, 2);
	//write the initial expected value exp_val_in
	gpio_write_word(2, 500, 2);
	//write the tolerance
	gpio_write_word(3, 10, 2);
	//write the number of averages to take 
	gpio_write_word(4, 2, 2);//this is 4 averages
	gpio_write_word(5, 2, 2);//lock signal pos
	gpio_write_word(6, 1, 2);//Setpt step
	
	repeat(10) clk_cycle();//Delay before locking cycle start
	trig_lock <= 1;
	lock_sig_active <= 1;
	
	repeat (100000) step_dl_sim();
	
end





task step_dl_sim();
begin
	real pn;
	//Evaluate the current MZI result and feed it into the buffer
	setpt_cast = real'(setpt_out_ext*dl_to_mzi_scale_fac);
	get_noise(pn);
	mzi_res = int'(run_mzi_sim(setpt_cast, pn)*mzi_to_dl_scale_fac)&16'hffff;
	//Update the ADC register going into dl
	adc_data_in <= { {1{16'h0}}, mzi_res, {6{16'h0}}};
	// cycle the clock
	clk_cycle();

end
endtask



task get_noise(output real phase);
begin
	phase = 0;
	step_num <= step_num + 1;
end
endtask






function void test_mzi_sim();

	//$display("Running MZI test");
	automatic int outfile = $fopen("mzi_test_results.csv", "w");
	real p, res, p_max;
	p_max = 65535;
	$fwrite(outfile, "p, res\n");
	
	for(p = -1*p_max; p < p_max; p = p + 1) begin
		res = run_mzi_sim(p*dl_to_mzi_scale_fac, 0);
		$fwrite(outfile, "%f, %f\n", p, res*mzi_to_dl_scale_fac);
	end
	$display("MZI test finished!");
	$fclose(outfile);
	

endfunction





function real run_mzi_sim(input real phase1, phase2);

	automatic cmp_num E0, E1, E2, E3, E4, E5;
	automatic real sf, r_fac;

	//Define the starting electric field
	E0 = '{1,0};
	
	//first beamsplitter
	E1 = cmp_mul(E0, '{1/$sqrt(2), 0});
	E2 = cmp_mul(E0, '{0, 1/$sqrt(2)});
	
	//Phase propagation
	E3 = cmp_mul(E1, cmp_exp('{0,phase1}));
	E4 = cmp_mul(E2, cmp_exp('{0,phase2}));
	
	//Second beamsplitter first output
	E5 = cmp_add(cmp_mul(E3, '{1/$sqrt(2), 0}), cmp_mul(E4, '{0, 1/$sqrt(2)}));
	
	//multiply final output intensity by exp(|x|^2) rolloff
	sf = -1/(2*pi*10);//10 wavelengths or so
	r_fac = abs(phase1-phase2)*abs(phase1-phase2)*sf;
	
	return cmp_sqr_mag(cmp_mul(E5, cmp_exp('{r_fac, 0})));

endfunction



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


task gpio_write_word;
input [15:0] addr;
input int data;
input int num_bytes;
begin
	int k;
	for(k = 0; k < num_bytes; k = k + 1) begin
		gpio_write(addr, (data >> (8*(num_bytes-k-1)))&8'hff);
	end
end
endtask

endmodule

