


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




//Config Reg Address table
parameter run_trig_reg = 16'h0000;
parameter del_trig_reg = 16'h0001;
parameter halt_reg = 16'h0002;
parameter del_meas_val_reg = 16'h0003;
parameter del_meas_thresh_reg = 16'h0004;
parameter adc_run_reg = 17'h0005;
//Address table for configuration registers (0 to 65535)
//parameter mac_input_scaler_addr_reg = 16'h0002;
//parameter mac_input_scaler_data_reg = 16'h0003;
//parameter nl_input_scaler_addr_reg = 16'h0004;
//parameter nl_input_scaler_data_reg = 16'h0005;
parameter mac_driver_addr_reg = 16'h000C;
parameter mac_driver_data_reg = 16'h000D;
parameter mac_driver_shift_amt_reg_base_addr = 16'h000E;
parameter nl_driver_addr_reg = 16'h000F;
parameter nl_driver_data_reg = 16'h0010;
parameter nl_driver_shift_amt_reg_base_addr = 16'h0011;

//Readback registers
parameter del_meas_mac_result = 16'h0006;
parameter del_meas_nl_result = 16'h0007;
parameter a_read_reg = 16'h0008;
parameter c_read_reg = 16'h0009;
parameter mac_adc_read_reg = 16'h000A;
parameter nl_adc_read_reg = 16'h000B;
parameter instr_count_reg = 16'h0012;
parameter b_count_reg = 16'h0013;
parameter ex_state_reg = 16'h0014;


parameter a_output_scaler_addr_reg = 16'h0015;
parameter a_output_scaler_data_reg = 16'h0016;
parameter a_static_output_reg_base_addr = 16'h0017;//Static dac word to output
parameter a_dac_mux_sel_reg_base_addr = 16'h0018;//Selects between input from output scaler, static word, or delay cal
parameter a_shift_amt_reg_base_addr = 16'h0019;//Selects how much to shift output by

parameter a_nl_output_scaler_addr_reg = 16'h0027;
parameter a_nl_output_scaler_data_reg = 16'h0028;
parameter a_nl_static_output_reg_base_addr = 16'h0029;//Static dac word to output
parameter a_nl_dac_mux_sel_reg_base_addr = 16'h002A;//Selects between input from output scaler, static word, or delay cal
parameter a_nl_shift_amt_reg_base_addr = 16'h002B;//Selects how much to shift output by

parameter b_output_scaler_addr_reg = 16'h001A;
parameter b_output_scaler_data_reg = 16'h001B;
parameter b_static_output_reg_base_addr = 16'h001C;//Static dac word to output
parameter b_dac_mux_sel_reg_base_addr = 16'h001D;//Selects between input from output scaler, static word, or delay cal
parameter b_shift_amt_reg_base_addr = 16'h001E;//Selects how much to shift output by

parameter c_output_scaler_addr_reg = 16'h001F;
parameter c_output_scaler_data_reg = 16'h0020;
parameter c_static_output_reg_base_addr = 16'h0021;//Static dac word to output
parameter c_dac_mux_sel_reg_base_addr = 16'h0022;//Selects between input from output scaler, static word, or delay cal
parameter c_shift_amt_reg_base_addr = 16'h0023;//Selects how much to shift output by

parameter a_write_reg = 16'h0024;
parameter c_write_reg = 16'h0025;

parameter instr_b_sel_reg = 16'h0026;





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

real pi = 3.1415926535;
real V_pi = 7;
typedef struct {real r, i;} cmp_num;

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
	return cmp_mul('{2,0}, cmp_mul(cmp_exp(a), d_i));
endfunction

function cmp_num cmp_inv(input cmp_num a);
	automatic real d = (a.r*a.r) + (a.i*a.i);
	cmp_inv.r = a.r/d;
	cmp_inv.i = (-1*a.i)/d);
endfunction

function real cmp_sqr_mag(input cmp_num a);

	return (a.r*a.r)+(a.i*a.i);
	
endfunction

function real I_NLA(input real E_in, V_a, V_LO, V_alpha);
	
	//NL Parameters
	automatic cmp_num eta = '{1,0};
	automatic cmp_num t_out = '{1,0};
	automatic cmp_num kappa = '{510,0};
	automatic cmp_num L = '{0.002,0};
	automatic cmp_num t_nla = '{1,0};
	automatic cmp_num t_alpha = '{1,0};
	automatic cmp_num t_in = '{1,0};
	automatic cmp_num t_lo = '{1,0};
	automatic t_a = '{1,0};
	
	//Bias points for nl chip (all in radians
    automatic real a_nl_bias = 0;
    automatic real alpha_nl_bias = 0;
    automatic real phi_LO_bias = 0;

    automatic cmp_num a = '{$cos( (V_a/V_pi) + a_nl_bias), 0};
    automatic cmp_num alpha = '{$cos( (V_alpha/V_pi) + alpha_nl_bias), 0};
    automatic cmp_num phi_LO = '{0,(pi * (V_LO/V_pi)) + phi_LO_bias};
    
    //E_4 = t_in * 1i * sqrt(1-(a*a));
	automatic cmp_num E_4 = '{0,t_in.r * $sqrt(1-(a.r*a.r))};
    
	//E_LO = t_lo * exp(1i*phi_LO) * E_4;
    automatic cmp_num E_LO = cmp_mul(t_lo, cmp_mul(cmp_exp(phi_LO) , E_4));
    
    //E_3 = t_in * a * E_in;
	automatic cmp_num E_3 = cmp_mul(t_in, cmp_mul(a, '{E_in, 0}));
    
    //E_alpha = t_a * alpha * E_3;
	automatic cmp_num E_alpha = cmp_mul(t_a, cmp_mul(alpha, E_3));
    
    //E_NLA = t_nla * E_alpha * sech(kappa * L * E_alpha);
	automatic cmp_num sech_arg = cmp_mul(kappa, cmp_mul(L, E_alpha));
	automatic cmp_num E_NLA = cmp_mul(t_nla, cmp_mul(E_alpha, cmp_sech(sech_arg)));
	

    //E_2 = t_out * (1/sqrt(2)) * ( (1i*E_LO) + E_NLA);
	automatic cmp_num last_arg = cmp_add(cmp_mul('{0,1}, E_LO), E_NLA);
	automatic cmp_num E_2 = cmp_mul(t_out, cmp_mul('{1/$sqrt(2)}, last_arg));
	
    //E_1 = t_out * (1/sqrt(2)) * ( E_LO + (1i*E_NLA));
	automatic cmp_num last_arg2 = cmp_add(cmp_mul('{0,1}, E_NLA), E_LO);
	automatic cmp_num E_1 = cmp_mul(t_out, cmp_mul('{1/$sqrt(2)}, last_arg2));
    
    //return eta * ((abs(E_1)^2)-(abs(E_2)^2));
	return eta.r * (cmp_sqr_mag(E_1) - cmp_sqr_mag(E_2));

endfunction



endpackage