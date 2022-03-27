


package ising_config;

//GPIO bus definitions
parameter gpio_w_clk_bit = 24;
parameter gpio_addr_start = 15;
parameter gpio_addr_end = 0;
parameter gpio_data_start = 23;
parameter gpio_data_end = 16;
parameter gpio_addr_width = 16;
parameter gpio_data_width = 8;

//How many words the ADC can record
parameter adc_buffer_len = 256;

parameter num_bits = 8; //Bit precision to use for internal logic


parameter var_fifo_depth = 12; //(2**12 = 4096)
parameter instr_fifo_depth = 16;




//Config Reg Address table/////////////////////////////////////////////////////////////////////////
parameter run_trig_reg = 16'h0000;
parameter del_trig_reg = 16'h0001;//Bit 0 is for a, bit 1 is for bc
parameter halt_reg = 16'h0002;
parameter del_meas_val_reg = 16'h0003;
parameter del_meas_thresh_reg = 16'h0004;
parameter adc_run_reg = 17'h0005;//Bit 0 starts MAC fifo, bit 1 for NL
parameter mac_driver_addr_reg = 16'h0006;
parameter mac_driver_data_reg = 16'h0007;
parameter mac_driver_shift_amt_reg_base_addr = 16'h0008;
parameter nl_driver_addr_reg = 16'h0009;
parameter nl_driver_data_reg = 16'h000A;
parameter nl_driver_shift_amt_reg_base_addr = 16'h000B;

parameter a_output_scaler_addr_reg = 16'h000C;
parameter a_output_scaler_data_reg = 16'h000D;
parameter a_static_output_reg_base_addr = 16'h000E;//Static dac word to output
parameter a_dac_mux_sel_reg_base_addr = 16'h000F;//Selects between input from output scaler, static word, or delay cal
parameter a_shift_amt_reg_base_addr = 16'h0010;//Selects how much to shift output by

parameter a_nl_output_scaler_addr_reg = 16'h0011;
parameter a_nl_output_scaler_data_reg = 16'h0012;
parameter a_nl_static_output_reg_base_addr = 16'h0013;//Static dac word to output
parameter a_nl_dac_mux_sel_reg_base_addr = 16'h0014;//Selects between input from output scaler, static word, or delay cal
parameter a_nl_shift_amt_reg_base_addr = 16'h0015;//Selects how much to shift output by

parameter b_output_scaler_addr_reg = 16'h0016;
parameter b_output_scaler_data_reg = 16'h0017;
parameter b_static_output_reg_base_addr = 16'h0018;//Static dac word to output
parameter b_dac_mux_sel_reg_base_addr = 16'h0019;//Selects between input from output scaler, static word, or delay cal
parameter b_shift_amt_reg_base_addr = 16'h001A;//Selects how much to shift output by

parameter c_output_scaler_addr_reg = 16'h001B;
parameter c_output_scaler_data_reg = 16'h001C;
parameter c_static_output_reg_base_addr = 16'h001D;//Static dac word to output
parameter c_dac_mux_sel_reg_base_addr = 16'h001E;//Selects between input from output scaler, static word, or delay cal
parameter c_shift_amt_reg_base_addr = 16'h001F;//Selects how much to shift output by

parameter a_write_reg = 16'h0020;
parameter c_write_reg = 16'h0021;

parameter instr_b_sel_reg = 16'h0022;

parameter phi_lo_shift_amt_reg = 16'h0023;
parameter phi_shift_amt_reg = 16'h0024;

parameter a_output_reg = 16'h0025;
parameter a_nl_output_reg = 16'h0026;
parameter phi_nl_output_reg = 16'h0027;

parameter phi_lo_start_reg = 16'h0028;
parameter phi_start_reg = 16'h0029;

parameter mac_sample_selector_reg = 16'h002A;
parameter nl_sample_selector_reg = 16'h002B;


//Readback registers (most significant nibble is 1)
parameter del_meas_mac_result = 16'h1000;
parameter del_meas_nl_result = 16'h1001;
parameter a_read_reg = 16'h1002;
parameter c_read_reg = 16'h1003;
parameter mac_adc_read_reg = 16'h1004;
parameter nl_adc_read_reg = 16'h1005;
parameter instr_count_reg = 16'h1006;
parameter b_count_reg = 16'h1007;
parameter ex_state_reg = 16'h1008;

/////Config Reg Addr Table End//////////////////////////////////////////////////////////////

//Runtime calibration parameters
parameter phase_cal_avgs = 1; //How many samples to average together when doing the measurement for each point
parameter phase_sweep_dist = 5;//How many data points to look at on each sweep
parameter phase_sweep_step = 5;//What to increment the 
parameter phase_cal_tol = 10;//the num_bits-1 value returned by the ADC must be in this range for calibration to be complete


//Runtime variables

//This is the full scale dac output times the amplifier gain divided by the full digital scale to normalize
real dac_scale_fac = 66000/(3*14);//Multiply to go from voltage to dac value
//This is the position of the waveform we ultimately use as the voltage being sent to the chip
const integer wave_pos = 4;
//This is the scaling factor we use to convert the current comming from the homodyne detection to the value returned by the ADCs////////////////
real adc_scale_fac = 66000/(400*2);//TODO//Multiply to go from voltage to ADC value
//Incident electric field amplitude at beginning of chip
real E_in_d = 20;


integer program_1[] = 
{
	
	16'h0030,//Add 0 to a, c
	16'h0007,//Remove a, b, c
	16'h0007,//Remove a, b, c
	16'h0007,//Remove a, b, c
	16'h0007,//Remove a, b, c
	16'h0007,//Remove a, b, c
	16'h0007,//Remove a, b, c
	16'h0007,//Remove a, b, c
	16'h0007 //Remove a, b, c

};

real pi = 3.1415926535897932384626;
real V_pi = 7;
typedef struct {real r, i;} cmp_num;
typedef struct {real V_a_min, V_a_max, V_b_min, V_b_max, V_c_min, V_c_max, V_alpha_min, V_alpha_max, V_phi_min, V_phi_max, V_LO_min, V_LO_max;} mac_cal_state;//Alpha here refers to very first modulator
typedef struct {real V_a_min, V_a_max, V_alpha_min, V_alpha_max, V_LO_min, V_LO_max;} nl_cal_state;//a here is the first modulator

function cmp_num cmp_add(input cmp_num a, b);
	cmp_add.r = a.r + b.r;
	cmp_add.i = a.i + b.i;
endfunction

function cmp_num cmp_mul(input cmp_num a, b);
	cmp_mul.r = (a.r*b.r) - (a.i*b.i);
	cmp_mul.i = (a.r*b.i) + (a.i*b.r);
endfunction

function cmp_num cmp_exp(input cmp_num a);
	cmp_exp.r = $cos(a.i);
	cmp_exp.i = $sin(a.i);
	cmp_exp.r = cmp_exp.r*$exp(a.r);
	cmp_exp.i = cmp_exp.i*$exp(a.r);
endfunction

function cmp_num cmp_sech(input cmp_num a);
	//compute denominator
	automatic cmp_num d = cmp_add(cmp_exp(cmp_mul('{2,0},a)),'{1,0});
	//Compute the inverse
	automatic cmp_num d_i = cmp_inv(d);
	//Compute the rest
	
	//For testing
	if(a.i != 0) begin
		$display("Warning, cmp_sech recieved complex argument");
	end
	
	return cmp_mul('{2,0}, cmp_mul(cmp_exp(a), d_i));
endfunction

function cmp_num cmp_inv(input cmp_num a);
	automatic real d = (a.r*a.r) + (a.i*a.i);
	cmp_inv.r = a.r/d;
	cmp_inv.i = (-1*a.i)/d;
endfunction

function real cmp_sqr_mag(input cmp_num a);

	return (a.r*a.r)+(a.i*a.i);
	
endfunction

function real I_NLA(input real E_in, V_a, V_LO, V_alpha);
	
	//NL Parameters
	automatic cmp_num eta = '{1,0};
	automatic cmp_num t_out = '{1,0};
	automatic cmp_num kappa = '{510*1,0};
	//automatic cmp_num kappa = '{1,0};//For testing purposes
	automatic cmp_num L = '{0.002,0};
	//automatic cmp_num L = '{1,0};//For testing purposes
	automatic cmp_num t_nla = '{1,0};
	automatic cmp_num t_alpha = '{1,0};
	automatic cmp_num t_in = '{1,0};
	automatic cmp_num t_lo = '{1,0};
	automatic cmp_num t_a = '{1,0};
	
	//Bias points for nl chip (all in radians
    automatic real a_nl_bias = 0;
    automatic real alpha_nl_bias = 0;
    automatic real phi_LO_bias = 0;

    automatic cmp_num a = '{$cos( ((V_a*pi)/(V_pi*2)) + a_nl_bias), 0};
    automatic cmp_num alpha = '{$cos( ((V_alpha*pi)/(V_pi*2)) + alpha_nl_bias), 0};
    automatic cmp_num phi_LO = '{0,(pi * 0.5 * (V_LO/V_pi)) + phi_LO_bias};
    
    //E_4 = t_in * 1i * sqrt(1-(a*a));
	automatic cmp_num E_4 = '{0,t_in.r * $sqrt(1-(a.r*a.r)) * E_in};
    
	//E_LO = t_lo * exp(1i*phi_LO) * E_4;
    automatic cmp_num E_LO = cmp_mul(t_lo, cmp_mul(cmp_exp(phi_LO) , E_4));
    
    //E_3 = t_in * a * E_in;
	automatic cmp_num E_3 = cmp_mul(t_in, cmp_mul(a, '{E_in, 0}));
    
    //E_alpha = t_a * alpha * E_3;
	automatic cmp_num E_alpha = cmp_mul(t_a, cmp_mul(alpha, E_3));
    
    //E_NLA = t_nla * E_alpha * sech(kappa * L * E_alpha);
	automatic cmp_num sech_arg = cmp_mul(kappa, cmp_mul(L, E_alpha));
	automatic cmp_num E_NLA = cmp_mul(t_nla, cmp_mul(E_alpha, cmp_sech(sech_arg)));
	//automatic cmp_num E_NLA = cmp_mul(E_alpha, cmp_sech(E_alpha));//For testing porpoises
	//automatic cmp_num E_NLA = cmp_sech(E_alpha);//For testing porpoises

    //E_2 = t_out * (1/sqrt(2)) * ( (1i*E_LO) + E_NLA);
	automatic cmp_num last_arg = cmp_add(cmp_mul('{0,1}, E_LO), E_NLA);
	automatic cmp_num E_2 = cmp_mul(t_out, cmp_mul('{1/$sqrt(2),0}, last_arg));
	
    //E_1 = t_out * (1/sqrt(2)) * ( E_LO + (1i*E_NLA));
	automatic cmp_num last_arg2 = cmp_add(cmp_mul('{0,1}, E_NLA), E_LO);
	automatic cmp_num E_1 = cmp_mul(t_out, cmp_mul('{1/$sqrt(2),0}, last_arg2));
    
    //return eta * ((abs(E_1)^2)-(abs(E_2)^2));
	return eta.r * (cmp_sqr_mag(E_1) - cmp_sqr_mag(E_2));
	//return E_NLA.r;//For testing purposes
	//return 0;//For testing porpoises :)

endfunction


function real I_MAC(input real E_in, V_a, V_LO, V_alpha, V_beta, V_gamma, V_phi);

	//MAC parameters
    automatic cmp_num eta = '{1,0};
    automatic cmp_num t_out = '{1,0};
    automatic cmp_num t_mzi = '{1,0};
    automatic cmp_num t_alpha = '{1,0};
    automatic cmp_num t_beta = '{1,0};
    automatic cmp_num t_gamma = '{1,0};
    automatic cmp_num t_phi = '{1,0};
    automatic cmp_num t_in = '{1,0};
    automatic cmp_num t_lo = '{1,0};
	
	//MAC Bias points
	automatic real a_mac_bias = 0;
    automatic real alpha_mac_bias = 0;
    automatic real beta_mac_bias = 0;
    automatic real gamma_mac_bias = 0;
    automatic real phi_LO_bias = 0;
    automatic real phi_alpha_bias = 0;
	
	automatic cmp_num a = '{$cos( (pi*0.5*(V_a/V_pi)) + a_mac_bias), 0};
	automatic cmp_num alpha = '{$cos( (pi*0.5*(V_alpha/V_pi)) + alpha_mac_bias), 0};
	automatic cmp_num beta = '{$cos( (pi*0.5*(V_beta/V_pi)) + beta_mac_bias), 0};
	automatic cmp_num gamma = '{$cos( (pi*0.5*(V_gamma/V_pi)) + gamma_mac_bias), 0};
	automatic cmp_num phi = '{0, (pi*0.5*(V_phi/V_pi)) + phi_alpha_bias};//All imaginary for exponential
	automatic cmp_num phi_LO = '{0, (pi*0.5*(V_LO/V_pi)) + phi_LO_bias};//All imaginary for exponential

	automatic cmp_num E_5 = '{0, t_in.r*$sqrt(1-(a.r*a.r))*E_in};
	
	automatic cmp_num E_LO = cmp_mul(t_lo, cmp_mul(cmp_exp(phi_LO), E_5));
	
	automatic cmp_num E_4 = '{t_in.r*a.r*E_in,0};
	
	automatic cmp_num E_alpha = cmp_mul('{0,1/$sqrt(2)}, cmp_mul(t_alpha, cmp_mul(alpha, E_4)));
	
	automatic cmp_num E_3 = cmp_mul(t_phi, cmp_mul(cmp_exp(phi), E_alpha));
	
	automatic cmp_num E_beta = cmp_mul('{1/$sqrt(2),0}, cmp_mul(t_beta, cmp_mul(beta, E_4)));
	
	automatic cmp_num E_bg = cmp_mul(t_beta, cmp_mul(gamma, E_beta));
	
	automatic cmp_num E_mac_arg = cmp_add(E_bg, cmp_mul(E_3, '{0,1}));
	automatic cmp_num E_mac = cmp_mul('{1/$sqrt(2), 0}, cmp_mul(t_mzi, E_mac_arg));
	
	automatic cmp_num E_2_arg = cmp_add(cmp_mul(E_LO, '{0,1}), E_mac);
	automatic cmp_num E_2 = cmp_mul('{1/$sqrt(2),0}, cmp_mul(t_out, E_2_arg));
	
	automatic cmp_num E_1_arg = cmp_add(cmp_mul(E_mac, '{0,1}), E_LO);
	automatic cmp_num E_1 = cmp_mul('{1/$sqrt(2),0}, cmp_mul(t_out, E_1_arg));
	
	return eta.r * (cmp_sqr_mag(E_1) - cmp_sqr_mag(E_2));
	
endfunction






/////////////////////////////////////////////////////////////////////////////
//The following set of functions are used to generate the LUT and set-point// 
//information from the chip model implemented in the two functions above/////
/////////////////////////////////////////////////////////////////////////////


function real abs(real val);
	if(val < 0) begin
		return -1*val;
	end
	else begin
		return val;
	end
endfunction


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
	
	//Do this same sweep but with the phase of alpha shifted 180 to make it negative
	outfile = $fopen("mac_asn_bo_co.csv", "w");
	$fwrite(outfile, "v_alpha, I_out_I\n");

	for(v = 0; v <= V_pi*2; v = v + 0.001) begin
		res1 = I_MAC(E_in_d, cal_state.V_alpha_max, cal_state.V_LO_max+ (V_pi*2), v, cal_state.V_b_max+ (V_pi*2), cal_state.V_c_max+ (V_pi*2), cal_state.V_phi_max+ (V_pi*2));
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
	
	$display("MAC LUT GEN finished");
	
	
endfunction

//New mac cal alg
function mac_cal_state cal_mac_chip();

	//First we sweep the input modulator (referred to as alpha here)
	automatic real i_min, i_max, v_min, v_max, v_in, res1, v2, v3;
	automatic real V_alpha_max, V_alpha_min;
	automatic real V_a_min, V_a_max, V_b_min, V_b_max, V_c_min, V_c_max;
	automatic real V_a_mi, V_a_ma, V_b_mi, V_b_ma, V_c_mi, V_c_ma;
	automatic real V_LO_max, V_LO_min, V_phi_max, V_phi_min;
	automatic real v_step = 0.1;
	automatic int outfile, j;
	
	$display("%%%%%%%%%%%%%%%%MAC cal start%%%%%%%%%%%%%%%%");
	
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
			//$display("Trying V_LO = %f, V_phi = %f", v2, v3);
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
		//$display("V_b_max: %f, V_b_min: %f", V_b_ma, V_b_mi);
		
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
		//$display("V_c_max: %f, V_c_min: %f", V_c_ma, V_c_mi);
		
		
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
	$display("V_alpha_max: %f, V_alpha_min: %f", V_alpha_max, V_alpha_min);
	$display("V_phi_max: %f, V_phi_min: %f", V_phi_max, V_phi_min);
	$display("V_LO_max: %f, V_LO_min: %f", V_LO_max, V_LO_min);
	$display("%%%%%%%%%%%%%%%%MAC cal done%%%%%%%%%%%%%%%%");
	
	return '{V_a_min, V_a_max, V_b_min, V_b_max, V_c_min, V_c_max, V_alpha_min, V_alpha_max, V_phi_min, V_phi_max, V_LO_min, V_LO_max}; 
	
	
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
	
	$display("%%%%%%%%%%%%%%%%NL cal start%%%%%%%%%%%%%%%%");
	
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
	$display("%%%%%%%%%%%%%%%%NL cal done%%%%%%%%%%%%%%%%");
	
	//And we're done! We have all of the bias points for the a, alpha, and LO modulators
	
	return '{V_a_min, V_a_max, V_alpha_min, V_alpha_max, V_LO_min, V_LO_max};
	
endfunction


//Creates the 256-bit wave from a single sample
function [255:0] get_wave(input [15:0] val_in);
	automatic reg [15:0] val_inv = ~(val_in)+1;
	get_wave = { {8{val_in}}, {8{val_inv}} };
endfunction

//Reverses the order of the samples in a 256-bit word wave
function [255:0] reverse_wave(input [255:0] wave_in);
	automatic int i = 0;
	for(i = 0; i < 256; i = i + 16) begin
		reverse_wave[i+:16] = wave_in[(256-16-i)+:16];
	end
endfunction


endpackage