

import ising_config::*;

module chip_cal_alg();


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
	
	for (v_in = 0; v_in < 9; v_in += 0.01) begin
	
		res = I_NLA(1, v_in, 0, 0);
		
		if(res > I_a_max) begin
			I_a_max = res;
			V_a_max = v_in;
		end
		
		if(res < I_a_min) begin
			I_a_min = res;
			V_a_min = v_in;
		end
	
	end
	
	$display("Initial values: V_a_max: %f, V_a_min: %f\n", V_a_max, V_a_min);
	
	//We'll now do this one more time but instead apply V_pi/2 to the LO path to see if we were accidentally measuring the wrong quadrature
	
	
	for (v_in = 0; v_in < 9; v_in += 0.01) begin
	
		res = I_NLA(1, v_in, 3.5, 0);
		
		if(res > I_a_max) begin
			I_a_max = res;
			V_a_max = v_in;
			V_LO = 3.5;
		end
		
		if(res < I_a_min) begin
			I_a_min = res;
			V_a_min = v_in;
		end
	
	end
	
	$display("Final values: V_a_max: %f, V_a_min: %f\n", V_a_max, V_a_min);
	
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
	
		res = I_NLA(1, V_a_max, v_in, V_alpha_max);
		
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
	
	//And we're done! We have all of the bias points for the a, alpha, and LO modulators
	
	return '{V_a_min, V_a_max, V_alpha_min, V_alpha_max, V_LO_min, V_LO_max};
	
endfunction



function mac_cal_state cal_mac_chip();

	//First we sweep a with a combo of 4 different set points for b and c ( [0,0], [3.5,0], [0,3.5], [3.5,3.5])
	
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
		res = I_MAC(1, v_in, 0, 0, 0, 0, 0);
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
		//3.5, 0
		res = I_MAC(1, v_in, 0, 0, 3.5, 0, 0);
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 3.5;
			V_c = 0;
		end
		//0, 3.5
		res = I_MAC(1, v_in, 0, 0, 0, 3.5, 0);
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 0;
			V_c = 3.5;
		end
		//3.5, 3.5
		res = I_MAC(1, v_in, 0, 0, 3.5, 3.5, 0);
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 3.5;
			V_c = 3.5;
		end
	
	end
	
	//Now we repeat the whole thing with a different V_LO and see if anything changes
	
	
	for(v_in = 0; v_in < 9; v_in += 0.01) begin
		//0, 0
		res = I_MAC(1, v_in, 3.5, 0, 0, 0, 0);
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 0;
			V_c = 0;
			V_LO = 3.5;
		end
		//3.5, 0
		res = I_MAC(1, v_in, 3.5, 0, 3.5, 0, 0);
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 3.5;
			V_c = 0;
			V_LO = 3.5;
		end
		//0, 3.5
		res = I_MAC(1, v_in, 3.5, 0, 0, 3.5, 0);
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 0;
			V_c = 3.5;
			V_LO = 3.5;
		end
		//3.5, 3.5
		res = I_MAC(1, v_in, 3.5, 0, 3.5, 3.5, 0);
		if(res < I_min) begin
			I_min = res;
			V_a_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_a_max = v_in;
			V_b = 3.5;
			V_c = 3.5;
			V_LO = 3.5;
		end
	end
	
	//Now we know the bias points for A, we'll bias B and C to their more open points (either 0 or 3.5) and then find the right bias for V_LO_max
	
	I_min = 9999;
	I_max = 0;
	
	for(v_in = -9; v_in < 9; v_in += 0.01) begin
		res = I_MAC(1, V_a_max, 0, 0, V_b, V_c, 0);
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
		res = I_MAC(1, V_a_max, V_LO_max, 0, v_in, V_c, 0);
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
		
		res = I_MAC(1, V_a_max, V_LO_max, 0, V_b_max, v_in, 0);
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
		res = I_MAC(1, V_a_max, V_LO_max, v_in, V_b_min, V_c_min, 0);
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
		res = I_MAC(1, V_a_max, V_LO_max, v_in, V_b_min, V_c_min, 3.5);
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
		res = I_MAC(1, V_a_max, V_LO_max, V_alpha_max, V_b_min, V_c_min, v_in);
		if(res < I_min) begin
			I_min = res;
			V_phi_min = v_in;
		end
		if(res > I_max) begin
			I_max = res;
			V_phi_max = v_in;
		end
	end
	
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


initial begin

	automatic real r = cmp_num_test();
	automatic nl_cal_state nl_state = cal_nl_chip();
	automatic mac_cal_state mac_state = cal_mac_chip();

end


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

function void test_nl_cal(nl_cal_state nl_cal);





endfunction


function real abs(real val);
	if(val < 0) begin
		return -1*val;
	end
	else begin
		return val;
	end
endfunction





endmodule 


