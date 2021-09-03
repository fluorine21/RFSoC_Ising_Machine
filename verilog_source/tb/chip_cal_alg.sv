

import ising_config::*;

module chip_cal_alg();

//Generates the output lookup table for FSM->DAC->chip 
//and the input lookup table chip->ADC->FSM
function void gen_nl_lut(nl_cal_state cal_state);

	//First we sweep the alpha modulator from 0 to v_pi with the known a and phi_lo voltages
	
	automatic real V_in[] = {};
	automatic real I_out[] = {};
	automatic real res1, v;
	
	automatic int outfile = $fopen("nl_lut_gen_results.csv", "w");
	$fwrite(outfile, "v_alpha, I_out_I\n");
	
	for(v = 0; v <= V_pi*2; v = v + 0.001) begin
		V_in = {V_in, v};
		res1 = I_NLA(E_in_d, cal_state.V_a_max, cal_state.V_LO_max, v);
		//res1 = I_NLA(E_in_d, v, 0, 0);
		I_out = {I_out, res1}; 
		
		$fwrite(outfile, "%f, %f\n", v, res1);
	end
	$display("NL LUT gen finished!");
	$fclose(outfile);
	
endfunction



function void gen_mac_lut(mac_cal_state cal_state);

	

	//Generate a sweep of alpha with beta and gamma shut
	automatic real res1, v;
	
	automatic int outfile = $fopen("mac_as_bc_cc.csv", "w");
	$fwrite(outfile, "v_alpha, I_out_I\n");

	for(v = 0; v <= V_pi*2; v = v + 0.001) begin
		res1 = I_MAC(E_in_d, cal_state.V_alpha_max, cal_state.V_LO_max, v, cal_state.V_b_min, cal_state.V_c_min, cal_state.V_phi_max);
		$fwrite(outfile, "%f, %f\n", v, res1);
	end
	$fclose(outfile);
	
	//Generate a sweep of alpha with beta open, gamma open
	outfile = $fopen("mac_as_bo_co.csv", "w");
	$fwrite(outfile, "v_alpha, I_out_I\n");

	for(v = 0; v <= V_pi*2; v = v + 0.001) begin
		res1 = I_MAC(E_in_d, cal_state.V_alpha_max, cal_state.V_LO_max, v, cal_state.V_b_max, cal_state.V_c_max, cal_state.V_phi_max);
		$fwrite(outfile, "%f, %f\n", v, res1);
	end
	$fclose(outfile);
	
	
	//Generate a sweep of beta with gamma open, alpha shut
	outfile = $fopen("mac_ac_bs_co.csv", "w");
	$fwrite(outfile, "v_alpha, I_out_I\n");

	for(v = 0; v <= V_pi*2; v = v + 0.001) begin
		res1 = I_MAC(E_in_d, cal_state.V_alpha_max, cal_state.V_LO_max, cal_state.V_a_min, v, cal_state.V_c_max, cal_state.V_phi_max);
		$fwrite(outfile, "%f, %f\n", v, res1);
	end
	$fclose(outfile);
	
	//Generate a sweep of gamma with beta open, alpha shut
	outfile = $fopen("mac_ac_bo_cs.csv", "w");
	$fwrite(outfile, "v_alpha, I_out_I\n");

	for(v = 0; v <= V_pi*2; v = v + 0.001) begin
		res1 = I_MAC(E_in_d, cal_state.V_alpha_max, cal_state.V_LO_max, cal_state.V_a_min, cal_state.V_b_max, v, cal_state.V_phi_max);
		$fwrite(outfile, "%f, %f\n", v, res1);
	end
	$fclose(outfile);
	
	
endfunction


function nl_cal_state cal_nl_chip();

	automatic real v_in;
	automatic real res;


	//We start by sweeping the voltage applied to the a modulator to find it's min, max
	automatic real V_a_min = 0;
	automatic real V_a_max = 0;
	
	automatic real I_a_min = 9999999;
	automatic real I_a_max = 0;
	
	automatic real V_LO = 0;
	
	automatic real V_alpha_min = 0;
	automatic real V_alpha_max = 0;
	
	automatic real I_alpha_min = 9999999;
	automatic real I_alpha_max = 0;
	
	automatic real V_LO_min = 0;
	automatic real V_LO_max = 0;
	
	automatic real I_LO_min = 99999;
	automatic real I_LO_max = 0;
	
	//We're going to sweep 4 times with 0 to 7 for alpha and LO to give us the best chance of seeing something we can use to calibrate
	for (v_in = 0; v_in < 9; v_in += 0.01) begin
		res = abs(I_NLA(1, v_in, 0, 0));
		if(res > I_a_max) begin
			I_a_max = res;
			V_a_max = v_in;
		end
		if(res < I_a_min) begin
			I_a_min = res;
			V_a_min = v_in;
		end
	end
	
	//$display("I_NLA for V_a = 0 was %f", I_NLA(1, 0, 0, 0));
	for (v_in = 0; v_in < 9; v_in += 0.01) begin
		res = abs(I_NLA(1, v_in, 7, 0));
		if(res > I_a_max) begin
			I_a_max = res;
			V_a_max = v_in;
			V_LO = 7;
		end
		
		if(res < I_a_min) begin
			I_a_min = res;
			V_a_min = v_in;
		end
	end
	for (v_in = 0; v_in < 9; v_in += 0.01) begin
		res = abs(I_NLA(1, v_in, 0, 7));
		if(res > I_a_max) begin
			I_a_max = res;
			V_a_max = v_in;
			V_LO = 0;
		end
		
		if(res < I_a_min) begin
			I_a_min = res;
			V_a_min = v_in;
		end
	end
	for (v_in = 0; v_in < 9; v_in += 0.01) begin
		res = abs(I_NLA(1, v_in, 7, 7));
		if(res > I_a_max) begin
			I_a_max = res;
			V_a_max = v_in;
			V_LO = 7;
		end
		
		if(res < I_a_min) begin
			I_a_min = res;
			V_a_min = v_in;
		end
	end
	
	$display("V_a_max: %f, V_a_min: %f", V_a_max, V_a_min);
	
	//Now we have the bias points for the A modulator
	
	//We'll bias it all the way open and then sweep alpha here
	
	for (v_in = 0; v_in < 9; v_in += 0.01) begin
	
		res = abs(I_NLA(1, V_a_max, V_LO, v_in));
		
		if(res > I_alpha_max) begin
			I_alpha_max = res;
			V_alpha_max = v_in;
		end
		
		if(res < I_alpha_min) begin
			I_alpha_min = res;
			V_alpha_min = v_in;
		end
	
	end
	
	$display("V_alpha_max: %f, V_alpha_min: %f", V_alpha_max, V_alpha_min);
	
	//Now we know the bias points for a and alpha, so we'll sweep V_LO with a and alpha set to max to make sure we're measuring the correct quadrature. 
	
	for (v_in = 0; v_in < 9; v_in += 0.01) begin
	
		res = abs(I_NLA(1, V_a_max, v_in, V_alpha_max));
		
		if(res > I_LO_max) begin
			I_LO_max = res;
			V_LO_max = v_in;
		end
		
		if(res < I_LO_min) begin
			I_LO_min = res;
			V_LO_min = v_in;
		end
	
	end
	
	$display("V_LO_max: %f, V_LO_min: %f", V_LO_max, V_LO_min);
	$display("NL cal done");
	
	//And we're done! We have all of the bias points for the a, alpha, and LO modulators
	
	return '{V_a_min, V_a_max, V_alpha_min, V_alpha_max, V_LO_min, V_LO_max};
	
endfunction



function mac_cal_state cal_mac_chip();

	//First we sweep a with a combo of 4 different set points for b and c ( [0,0], [7,0], [0,7], [7,7])
	
	automatic real v_in;
	automatic real res;
	
	automatic real V_a_min = 0;
	automatic real V_a_max = 0;
	
	automatic real I_min = 99999;
	automatic real I_max = 0;
	
	automatic real V_b = 0; 
	automatic real V_c = 0;
	
	automatic real V_LO = 0;
	
	automatic real V_LO_min = 0;
	automatic real V_LO_max = 0;
	
	automatic real V_b_min = 0;
	automatic real V_b_max = 0;
	
	automatic real V_c_min = 0;
	automatic real V_c_max = 0;
	
	automatic real V_alpha_min = 0;
	automatic real V_alpha_max = 0;
	
	automatic real V_phi_min = 0;
	automatic real V_phi_max = 0;
	
	for(v_in = 0; v_in < 9; v_in += 0.01) begin
	
		//0, 0
		res = abs(I_MAC(1, v_in, 0, 0, 0, 0, 0));
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 0;
			V_c = 0;
		end
		//7, 0
		res = abs(I_MAC(1, v_in, 0, 0, 7, 0, 0));
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 7;
			V_c = 0;
		end
		//0, 7
		res = abs(I_MAC(1, v_in, 0, 0, 0, 7, 0));
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 0;
			V_c = 7;
		end
		//7, 7
		res = abs(I_MAC(1, v_in, 0, 0, 7, 7, 0));
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 7;
			V_c = 7;
		end
	
	end
	
	//Now we repeat the whole thing with a different V_LO and see if anything changes
	
	
	for(v_in = 0; v_in < 9; v_in += 0.01) begin
		//0, 0
		res = abs(I_MAC(1, v_in, 7, 0, 0, 0, 0));
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 0;
			V_c = 0;
			V_LO = 7;
		end
		//7, 0
		res = abs(I_MAC(1, v_in, 7, 0, 7, 0, 0));
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 7;
			V_c = 0;
			V_LO = 7;
		end
		//0, 7
		res = abs(I_MAC(1, v_in, 7, 0, 0, 7, 0));
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 0;
			V_c = 7;
			V_LO = 7;
		end
		//7, 7
		res = abs(I_MAC(1, v_in, 7, 0, 7, 7, 0));
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 7;
			V_c = 7;
			V_LO = 7;
		end
	end
	
	$display("After a cal: V_b: %f, V_c: %f, V_LO: %f", V_b, V_c, V_LO);
	
	//Now we know the bias points for A, we'll bias B and C to their more open points (either 0 or 7) and then find the right bias for V_LO_max
	
	I_min = 9999;
	I_max = 0;
	
	for(v_in = -9; v_in < 9; v_in += 0.01) begin
		res = abs(I_MAC(1, V_a_max, 0, 0, V_b, V_c, 0));
		if(res < I_min) begin
			I_min = res;
			V_LO_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_LO_max = v_in;
		end
	end
	
	//Now we have the bias points for a, phi_lo
	//We will now sweep B and C to find their bias points
	
	I_min = 99999;
	I_max = 0;
	
	for(v_in = 0; v_in < 9; v_in += 0.01) begin
		//Using whatever the higher transmittance value was for C here
		res = abs(I_MAC(1, V_a_max, V_LO_max, 0, v_in, V_c, 0));
		if(res < I_min) begin
			I_min = res;
			V_b_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_b_max = v_in;
		end
	end
	
	I_min = 99999;
	I_max = 0;
	
	for(v_in = 0; v_in < 9; v_in += 0.01) begin
		
		res = abs(I_MAC(1, V_a_max, V_LO_max, 0, V_b_max, v_in, 0));
		if(res < I_min) begin
			I_min = res;
			V_c_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_c_max = v_in;
		end
	end
	
	//Now we have the bias points for a, b, c, and phi_lo
	
	//Next we'll close the b/c path and sweep alpha and phi together to get a rough idea of their bias points
	
	I_min = 99999;
	I_max = 0;
	
	//Sweep once with phi set to 0
	for(v_in = 0; v_in < 9; v_in += 0.01) begin
		res = abs(I_MAC(1, V_a_max, V_LO_max, v_in, V_b_min, V_c_min, 0));
		if(res < I_min) begin
			I_min = res;
			V_alpha_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_alpha_max = v_in;
		end
	end
	
	//Do it again with a different phi
	for(v_in = 0; v_in < 9; v_in += 0.01) begin
		res = abs(I_MAC(1, V_a_max, V_LO_max, v_in, V_b_min, V_c_min, 7));
		if(res < I_min) begin
			I_min = res;
			V_alpha_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_alpha_max = v_in;
		end
	end
	
	//Now we know the bias points for alpha
	//When we calibrated phi_LO, we locked it to the quadrature produced by the BC path (the positive value)
	//Therefore, we will now sweep phi with the BC path closed and alpha open such that we can lock phi to phi_LO and therefore the bc path, finding the positive and negative values simultaniously
	
	I_min = 99999;
	I_max = 0;
	
	for(v_in = -9; v_in < 9; v_in += 0.01) begin
		res = abs(I_MAC(1, V_a_max, V_LO_max, V_alpha_max, V_b_min, V_c_min, v_in));
		if(res < I_min) begin
			I_min = res;
			V_phi_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_phi_max = v_in;
		end
	end
	
	$display("V_a_min: %f, V_a_max: %f\nV_b_min: %f, V_b_max: %f\nV_c_min: %f, V_c_max: %f\nV_alpha_min: %f, V_alpha_max: %f\nV_phi_min: %f, V_phi_max: %f\nV_LO_min: %f, V_LO_max: %f", V_a_min, V_a_max, V_b_min, V_b_max, V_c_min, V_c_max, V_alpha_min, V_alpha_max, V_phi_min, V_phi_max, V_LO_min, V_LO_max);
	$display("MAC cal done");
	
	//and now we've found everything so we're done!
	return '{V_a_min, V_a_max, V_b_min, V_b_max, V_c_min, V_c_max, V_alpha_min, V_alpha_max, V_phi_min, V_phi_max, V_LO_min, V_LO_max};

endfunction


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


function real abs(real val);
	if(val < 0) begin
		return -1*val;
	end
	else begin
		return val;
	end
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

//New mac cal alg
function mac_cal_state cal_mac_chip_neu();

	//First we sweep the input modulator (referred to as alpha here)
	automatic real i_min, i_max, v_min, v_max, v_in, res1, v2, v3;
	automatic real V_alpha_max, V_alpha_min;
	automatic real V_a_min, V_a_max, V_b_min, V_b_max, V_c_min, V_c_max;
	automatic real V_a_mi, V_a_ma, V_b_mi, V_b_ma, V_c_mi, V_c_ma;
	automatic real V_LO_max, V_LO_min, V_phi_max, V_phi_min;
	automatic real v_step = 0.1;
	automatic int outfile, j;
	
	i_min = 999999999;
	i_max = 0;
	v2 = 0;
	v3 = 0;
	while(1) begin
	
		outfile = $fopen("mac_cal_diag.csv", "w");
		$fwrite(outfile, "v, i\n");
		
		for(v_in = V_pi*-2; v_in <= V_pi*2; v_in = v_in + v_step) begin
			res1 = abs(I_MAC(E_in_d, v_in, v2, 0, 0, 0, v3));
			if(res1 > i_max) begin
				i_max = res1;
				V_alpha_max = v_in;
			end
			if(res1 < i_min) begin
				i_min = res1;
				V_alpha_min = v_in;
			end
			$fwrite(outfile, "%f, %f\n", v_in, res1);
		end
		//If the difference bewtween the min and max currents is too small
		if(i_max == 0 || (i_max-i_min)/i_max < 0.5) begin
			//We go to a different v2 and try again
			if(v2 == 14 && v3 == 14) begin
				$fatal("Error, could not find cal point for a modulator at beginning");
			end
			if(v2 == 14) begin
				v2 = 0;
				v3 = v3+(V_pi/2);
			end
			else begin
				v2 = v2+(V_pi/2);
			end
			$display("Trying V_LO = %f, V_phi = %f", v2, v3);
			$fclose(outfile);
			continue;
		end
		else begin
			$fclose(outfile);
			break;//Otherwise we've found the cal points for alpha
		end
		$fclose(outfile);
	end
	
	$display("V_alpha_max: %f, V_alpha_min: %f, V_phi_LO: %f", V_alpha_max, V_alpha_min, v2);
	
	
	//Now sweep Phi until we get the most positive signal
	i_min = 999999999;
	i_max = 0;
	//outfile = $fopen("mac_cal_diag.csv", "w");
	//$fwrite(outfile, "v, i\n");
	for(v_in = V_pi*-2; v_in <= V_pi*2; v_in = v_in + v_step) begin
		res1 = I_MAC(E_in_d, V_alpha_max, v2, 0, 0, 0, v_in);//Use tentative values for the phis that we found last time
		if(res1 > i_max) begin
			i_max = res1;
			V_phi_max = v_in;
		end
		if(res1 < i_min) begin
			i_min = res1;
			V_phi_min = v_in;
		end
		//$fwrite(outfile, "%f, %f\n", v_in, res1);
	end
	//$fclose(outfile);
	$display("V_phi_max: %f, V_phi_min: %f", V_phi_max, V_phi_min);
	
	//Now sweep Phi_LO until we get most positive signal
	i_min = 999999999;
	i_max = 0;
	//outfile = $fopen("mac_cal_diag.csv", "w");
	//$fwrite(outfile, "v, i\n");
	for(v_in = V_pi*-2; v_in <= V_pi*2; v_in = v_in + v_step) begin
		res1 = I_MAC(E_in_d, V_alpha_max, v_in, 0, 0, 0, V_phi_max);//Use tentative values for the phis that we found last time
		if(res1 > i_max) begin
			i_max = res1;
			V_LO_max = v_in;
		end
		if(res1 < i_min) begin
			i_min = res1;
			V_LO_min = v_in;
		end
		//$fwrite(outfile, "%f, %f\n", v_in, res1);
	end
	//$fclose(outfile);
	$display("V_LO_max: %f, V_LO_min: %f", V_LO_max, V_LO_min);
	
	
	
	//ABC cal time :)
	
	//First we sweep B and C against several different values of A to see what we get
	for(v2 = V_pi*-2; v2 <= V_pi*2; v2 = v2 + V_pi/4) begin
	
		//Sweep B
		i_min = 999999999;
		i_max = 0;
		//outfile = $fopen("mac_cal_diag.csv", "w");
		//$fwrite(outfile, "v, i\n");
		for(v_in = V_pi*-2; v_in <= V_pi*2; v_in = v_in + v_step) begin
			res1 = abs(I_MAC(E_in_d, V_alpha_max, V_LO_max, v2, v_in, V_c_max, V_phi_max));//Use tentative values for the phis that we found last time
			if(res1 > i_max) begin
				i_max = res1;
				V_b_ma = v_in;
			end
			if(res1 < i_min) begin
				i_min = res1;
				V_b_mi = v_in;
			end
			//$fwrite(outfile, "%f, %f\n", v_in, res1);
		end
		//$fclose(outfile);
		$display("V_b_max: %f, V_b_min: %f", V_b_ma, V_b_mi);
		
		//Sweep C
		i_min = 999999999;
		i_max = 0;
		//outfile = $fopen("mac_cal_diag.csv", "w");
		//$fwrite(outfile, "v, i\n");
		for(v_in = V_pi*-2; v_in <= V_pi*2; v_in = v_in + v_step) begin
			res1 = abs(I_MAC(E_in_d, V_alpha_max, V_LO_max, v2, V_b_max, v_in, V_phi_max));//Use tentative values for the phis that we found last time
			if(res1 > i_max) begin
				i_max = res1;
				V_c_ma = v_in;
			end
			if(res1 < i_min) begin
				i_min = res1;
				V_c_mi = v_in;
			end
			//$fwrite(outfile, "%f, %f\n", v_in, res1);
		end
		//$fclose(outfile);
		$display("V_c_max: %f, V_c_min: %f", V_c_ma, V_c_mi);
		
		
		//If the min/max voltages have smaller separation than the last pair then keep them
		if(abs(V_b_ma - V_b_mi) < abs(V_b_max - V_b_min) || v2 == V_pi*-2) begin
			V_b_max = V_b_ma;
			V_b_min = V_b_mi;
		end
		if(abs(V_c_ma - V_c_mi) < abs(V_c_max - V_c_min) || v2 == V_pi*-2) begin
			V_c_max = V_c_ma;
			V_c_min = V_c_mi;
		end
	
	end


	
	//Now we sweep a (the accululant modulator named alpha in the doccumentation
	i_min = 999999999;
	i_max = 0;
	outfile = $fopen("mac_cal_diag.csv", "w");
	$fwrite(outfile, "v, i\n");
	for(v_in = V_pi*-2; v_in <= V_pi*2; v_in = v_in + v_step) begin
		res1 = abs(I_MAC(E_in_d, V_alpha_max, V_LO_max, v_in, V_b_min, V_c_min, V_phi_max));//Use tentative values for the phis that we found last time
		if(res1 > i_max) begin
			i_max = res1;
			V_a_max = v_in;
		end
		if(res1 < i_min) begin
			i_min = res1;
			V_a_min = v_in;
		end
		$fwrite(outfile, "%f, %f\n", v_in, res1);
	end
	$fclose(outfile);
	$display("V_a_max: %f, V_a_min: %f", V_a_ma, V_a_mi);

		

	$display("Final ABC cal state:");
	$display("V_a_max: %f, V_a_min: %f", V_a_max, V_a_min);
	$display("V_b_max: %f, V_b_min: %f", V_b_max, V_b_min);
	$display("V_c_max: %f, V_c_min: %f", V_c_max, V_c_min);
	$display("Final Phi and alpha cal state:");
	$display("V_alpha_max: %f, V_alpha_min: %f, V_phi_LO: %f", V_alpha_max, V_alpha_min, v2);
	$display("V_phi_max: %f, V_phi_min: %f", V_phi_max, V_phi_min);
	$display("V_LO_max: %f, V_LO_min: %f", V_LO_max, V_LO_min);
	
	
	
	
endfunction


initial begin

	//automatic real r = cmp_num_test();
	//automatic nl_cal_state nl_state = cal_nl_chip();
	//gen_nl_lut(nl_state);
	automatic mac_cal_state mac_state = cal_mac_chip_neu();
	//test_nl_cal();
	//test_mac_cal();
	//sech_test();
end


endmodule 


