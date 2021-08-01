

import ising_config::*;



module chip_cal_alg();



task cal_nl_chip();
begin

	//We start by sweeping the voltage applied to the a modulator to find it's min, max
	real V_a_min = 0;
	real V_a_max = 0;
	
	real I_a_min = 9999999;
	real I_a_max = 0;
	
	for (real v_in = 0; v_in < 9; v_in += 0.01) begin
	
		real res = I_NLA(1, v_in, 0, 0);
		
		if(res > I_a_max) begin
			I_a_max = res;
			V_a_max = v_in;
		end
		
		if(res < I_a_min) begin
			I_a_min = res;
			V_a_min = v_in;
		end
	
	end
	
	//We'll now do this one more time but instead apply V_pi/2 to the LO path to see if we were accidentally measuring the wrong quadrature
	
	real V_LO = 0;
	
	for (real v_in = 0; v_in < 9; v_in += 0.01) begin
	
		real res = I_NLA(1, v_in, 3.5, 0);
		
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
	
	
	
	//Now we have the bias points for the A modulator
	
	//We'll bias it all the way open and then sweep alpha here
	real V_alpha_min = 0;
	real V_alpha_max = 0;
	
	real I_alpha_min = 9999999;
	real I_alpha_max = 0;
	for (real v_in = 0; v_in < 9; v_in += 0.01) begin
	
		real res = I_NLA(1, V_a_max, V_LO, v_in);
		
		if(res > I_a_max) begin
			I_alpha_max = res;
			V_alpha_max = v_in;
		end
		
		if(res < I_a_min) begin
			I_alpha_min = res;
			V_alpha_min = v_in;
		end
	
	end
	
	//Now we know the bias points for a and alpha, so we'll sweep V_LO with a and alpha set to max to make sure we're measuring the correct quadrature. 
	
	real V_LO_min = 0;
	real V_LO_max = 0;
	
	real I_LO_min = 99999;
	real I_LO_max = 0;
	
	for (real v_in = 0; v_in < 9; v_in += 0.01) begin
	
		real res = I_NLA(1, V_a_max, v_in, V_alpha_max);
		
		if(res > I_LO_max) begin
			I_LO_max = res;
			V_LO_max = v_in;
		end
		
		if(res < I_LO_min) begin
			I_LO_min = res;
			V_LO_min = v_in;
		end
	
	end
	
	//And we're done! We have all of the bias points for the a, alpha, and LO modulators
endtask
endtask



task cal_mac_chip();
begin

	//First we sweep a with a combo of 4 different set points for b and c ( [0,0], [3.5,0], [0,3.5], [3.5,3.5])
	
	real V_a_min = 0;
	real V_a_max = 0;
	
	real I_min = 99999;
	real I_max = 0;
	
	real V_b = 0; 
	real V_c = 0;
	
	for(real v_in = 0; v_in < 9; v_in += 0.01) begin
	
		//0, 0
		real res = I_MAC(1, v_in, 0, 0, 0, 0, 0);
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
		real res = I_MAC(1, v_in, 0, 0, 3.5, 0, 0);
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
		real res = I_MAC(1, v_in, 0, 0, 0, 3.5, 0);
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
		real res = I_MAC(1, v_in, 0, 0, 3.5, 3.5, 0);
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
	real V_LO = 0;
	
	for(real v_in = 0; v_in < 9; v_in += 0.01) begin
	
		//0, 0
		real res = I_MAC(1, v_in, 3.5, 0, 0, 0, 0);
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
		real res = I_MAC(1, v_in, 3.5, 0, 3.5, 0, 0);
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
		real res = I_MAC(1, v_in, 3.5, 0, 0, 3.5, 0);
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
		real res = I_MAC(1, v_in, 3.5, 0, 3.5, 3.5, 0);
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
	
	real V_LO_min = 0;
	real V_LO_max = 0;
	
	I_min = 9999;
	I_max = 0;
	
	for(real v_in = 0; v_in < 9; v_in += 0.01) begin
	
		real res = I_MAC(1, V_a_max, 0, 0, V_b, V_c, 0);
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
	
	


end
endtask





endmodule 


