

import ising_config::*;



module chip_cal_alg();



task cal_nl_chip();

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





endmodule 


