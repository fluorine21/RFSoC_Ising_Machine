


%For now we'll assume that 0x7FFF is 7 volts and 0x8000 is -7 volts
%and that Vpi is 7 volts
%We'll also assume that 7 volts corresponds to a phi of pi
V_pi = 7;


%We'll also assume that Ein is 1V/m

E_in = 1;






function res = I_NLA(E_in, V_a, V_LO, V_alpha)

    %NL parameters
    eta = 1;
    t_out = 1;
    kappa = 510;
    L = 2e-3;
    t_nla = 1;
    t_alpha = 1;
    t_in = 1;
    t_lo = 1;
    
    %Bias points for nl chip (all in radians
    a_nl_bias = 0;
    alpha_nl_bias = 0;
    phi_LO_bias


    a = cos( (V_a/V_pi) + a_nl_bias);
    alpha = cos( (V_alpha/V_pi) + alpha_nl_bias);
    
    phi_LO = (pi .* (V_LO/V_pi)) + phi_LO_bias;
    
    E_4 = t_in * 1i * sqrt(1-(a*a));
    
    E_LO = t_lo * exp(1i*phi_LO) * E_4;
    
    E_3 = t_in * a * E_in;
    
    E_alpha = t_a * alpha * E_3;
    
    E_NLA = t_nla * E_alpha * sech(kappa * L * E_alpha);

    E_2 = t_out * (1/sqrt(2)) * ( (1i*E_LO) + E_NLA);
    E_1 = t_out * (1/sqrt(2)) * ( E_LO + (1i*E_NLA));
    
    res = eta * ((abs(E_1)^2)-(abs(E_2)^2));
    
end


function res = I_MAC(E_in, V_a, V_LO, V_alpha, V_beta, V_gamma, V_phi)

    %MAC parameters
    eta = 1;
    t_out = 1;
    t_mzi = 1;
    t_alpha = 1;
    t_beta = 1;
    t_gamma = 1;
    t_phi = 1;
    t_in = 1;
    t_lo = 1;
    
    %MAC bias points
    a_mac_bias = 0;
    alpha_mac_bias = 0;
    beta_mac_bias = 0;
    gamma_mac_bias = 0;
    phi_LO_bias = 0;
    phi_alpha_bias = 0;
    
    
    


end
