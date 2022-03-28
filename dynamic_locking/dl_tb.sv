import ising_config::*;


module dl_tb();


initial begin

	test_mzi_sim();

end




function void test_mzi_sim();

	//$display("Running MZI test");
	automatic int outfile = $fopen("mzi_test_results.csv", "w");
	real p, res, p_max;
	p_max = 20*2*pi;
	$fwrite(outfile, "p, res\n");
	
	for(p = -1*p_max; p < p_max; p = p + 0.01) begin
		res = run_mzi_sim(p, 0);
		$fwrite(outfile, "%f, %f\n", p, res);
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

endmodule