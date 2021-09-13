

import ising_config::*;

module chip_cal_alg();





function real cmp_num_test();

	//Try adding
	
	automatic cmp_num res = cmp_add('{1,0}, '{0,1});
	automatic real r1;
	if(res.r != 1 || res.i != 1) begin
		$display("Complex add failed!");
	end
	
	//Try multiplying
	res = cmp_mul('{1,1}, '{2,2});
	if(res.r != 0 || res.i != 4) begin
		$display("Complex mul failed!");
	end
	
	//Try exponentiating
	res = cmp_exp('{0,pi/2});
	if(check_val(res.r, 0) || check_val(res.i, 1))begin
		$display("Complex exp failed!");
	end
	
	//Try inverting
	res = cmp_inv('{0,1});
	if(res.r != 0 || res.i != -1) begin
		$display("Complex inv failed!");
	end
	
	//Try the square magnitude
	r1 = cmp_sqr_mag('{3,4});
	if(r1 != 25) begin
		$display("Complex magnitude failed");
	end
	
	//Try sech
	res = cmp_sech('{1,1});
	if(check_val(res.r, 0.498337) || check_val(res.i, -0.591084)) begin
		$display("Complex sech failed");
	end

	return 0;

endfunction


function real check_val(real v1, v2);
	automatic real err = v1-v2;
	if(err < 0) begin
		err = v2-v1;
	end

	if(err < 0.00001) begin
		return 0;
	end
	else begin
		return 1;
	end
endfunction

function void test_nl_cal();

	automatic int outfile;
	automatic real v_in, res1, res2;
	
	outfile = $fopen("nl_test_results.csv", "w");
	$fwrite(outfile, "v_alpha, I_out_I, I_out_Q\n");
	//We're going to set a to the optimal value we found and sweep alpha to see what we get
	for(v_in = -28; v_in < 28; v_in += 0.01) begin
		res1 = I_NLA(1, 4, 0, v_in);
		res2 = I_NLA(1, 4, 7, v_in);//Try other quadrature here
		$fwrite(outfile, "%f, %f, %f\n", v_in, res1, res2);
	end
	$display("NL test finished");
	$fclose(outfile);
endfunction


function void test_mac_cal();

	automatic int outfile;
	automatic real v_in1, v_in2, res1, res2;
	
	outfile = $fopen("mac_mul_test_results.csv", "w");
	$fwrite(outfile, "v_beta, v_gamma, I_out_I, I_out_Q\n");
	
	for(v_in1 = -14; v_in1 <= 14; v_in1 += 0.05) begin
		for(v_in2 = -14; v_in2 <= 14; v_in2 += 0.05) begin
			res1 = I_MAC(1, 4, 0, 7, v_in1, v_in2, 0);
			res2 = I_MAC(1, 4, 7, 7, v_in1, v_in2, 0);
			$fwrite(outfile, "%f, %f, %f, %f\n", v_in1, v_in2, res1, res2);
		end
	end
	$display("MAC mul test finished");
	$fclose(outfile);
	
	
	outfile = $fopen("mac_add_test_results.csv", "w");
	$fwrite(outfile, "v_beta, v_gamma, I_out_I, I_out_Q\n");
	for(v_in1 = -14; v_in1 <= 14; v_in1 += 0.05) begin
		for(v_in2 = -14; v_in2 <= 14; v_in2 += 0.05) begin
			res1 = I_MAC(1, 4, 0, v_in1, v_in2, 0, 14);
			res2 = I_MAC(1, 4, 7, v_in1, v_in2, 0, 14);
			$fwrite(outfile, "%f, %f, %f, %f\n", v_in1, v_in2, res1, res2);
		end
	end
	$display("MAC add test finished");
	$fclose(outfile);
	
	
	//Single add comparisons
	outfile = $fopen("mac_add_comp_results.csv", "w");
	$fwrite(outfile, "v_in, I_a, I_b\n");
	for(v_in1 = -28; v_in1 <= 28; v_in1 += 0.1) begin
		res1 = I_MAC(1, 4, 0, v_in1, 7, 0, 14);
		res2 = I_MAC(1, 4, 0, 7, v_in1, 0, 14);
		$fwrite(outfile, "%f, %f, %f\n", v_in1, res1, res2);
	end
	$display("MAC add comp finished");
	$fclose(outfile);
	
endfunction 





function void sech_test();

	automatic int outfile;
	automatic real	x, y;
	automatic cmp_num res;
	outfile = $fopen("sech_results.csv", "w");
	$fwrite(outfile, "x, y\n");
	for(x = -4; x <= 4; x += 0.1) begin
		res = cmp_sech('{$cos(x),0});
		y = res.r;
		$fwrite(outfile, "%f, %f\n", x, y);
	end
	$fclose(outfile);
	$display("Sech test finished");

endfunction




initial begin

	//automatic real r = cmp_num_test();
	//automatic nl_cal_state nl_state = cal_nl_chip();
	//gen_nl_lut(nl_state);
	automatic mac_cal_state mac_state = cal_mac_chip();
	gen_mac_lut(mac_state);
	//test_nl_cal();
	//test_mac_cal();
	//sech_test();
end


endmodule 


