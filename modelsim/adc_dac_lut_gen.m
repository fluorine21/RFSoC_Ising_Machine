clear; close all; clc;


t1 = readtable("nl_lut_gen_results.csv");

V_nl_in = t1{:, 1};
I_nl_out = t1{:, 2};

figure();
subplot(1, 2, 1);
plot(V_nl_in, I_nl_out, 'linewidth', 2);
title("Input NL Calibration Curve");
xlabel("V");
ylabel("I");

%Generate the LUTS
[lut_dac, lut_adc] = gen_nl_luts(V_nl_in, I_nl_out);
%Interpolate the voltage points used
v_dac = lut_dac(:,2);
i_dac = [];
for i = 1:max(size(v_dac))
  i_dac = [i_dac, interp1(V_nl_in, I_nl_out, v_dac(i))];  
end

%figure out where 0, -128, and 127 are
p_0 = []; p_128 = []; p_127 = [];
for i = 1:max(size(v_dac))
    if(lut_dac(i,1) == 0)
       p_0 = [lut_dac(i,2), interp1(V_nl_in, I_nl_out, lut_dac(i,2))]; 
    elseif(lut_dac(i,1) == -128)
       p_128 = [lut_dac(i,2), interp1(V_nl_in, I_nl_out, lut_dac(i,2))];
    elseif(lut_dac(i,1) == 127)
       p_127 = [lut_dac(i,2), interp1(V_nl_in, I_nl_out, lut_dac(i,2))];
    end
end

subplot(1,2,2);
hold on
plot(V_nl_in, I_nl_out, 'linewidth', 2);
plot(v_dac, i_dac, 'r*');
plot(p_0(1), p_0(2), 'g*');
plot(p_128(1), p_128(2), 'b*');
plot(p_127(1), p_127(2), 'm*');
title("Output Calibration Points");
xlabel("V");
ylabel("I");

legend("Input Curve", "Fitted Curve", "0", "-128", "127");


t2 = readtable("mac_cal_diag.csv");
figure();
plot(t2{:,1}, t2{:,2}, 'linewidth', 2);











%adc table is [fsm_val, adc_voltage_input]
%dac table is 
function [lut_dac, lut_adc] = gen_nl_luts(V_in, I_out)
    
    
    %First we generate the ADC's LUT by taking the full scale values and
    %distributing the output points uniformly
    [I_max, I_max_pos] = max(I_out);
    [I_min, I_min_pos] = min(I_out);
    I_step = (I_max-I_min)/255;
    lut_adc = [-128:1:127;I_min:I_step:I_max]';

    %Find the position of the furthest and closest 0
    [zero_pos, fz] = find_zp(V_in, I_out, I_min_pos);
    
    %Now we know the position of the -128 peak and the closest 0
    %We just have to cut up this region and distribute correctly
    
    v_neg = [];
    i_neg = [];
    if(zero_pos > fz)%If we were going in the positive direction
        %Flip here so we always count from zero on up
        v_neg = flip(V_in(fz : zero_pos));
        i_neg = flip(I_out(fz : zero_pos));
    else
        v_neg = V_in(zero_pos : fz);
        i_neg = I_out(zero_pos : fz);
    end
    
    %Create normalized versions to measure the length correctly
    v_neg_n = v_neg .* (1/max(abs(v_neg)));
    i_neg_n = i_neg .* (1/max(abs(i_neg)));
    
    %Get the length of the whole thing and divide by 127 so we know the
    %step size
    
    l_step = get_len(v_neg_n, i_neg_n)/128;
    
    %Start building the lut
    lut_dac = [0, V_in(fz)];
    
    v_pos = 2;
    sw = 0;
    for i = 1:128
        
        %if we're at the end
        if(i == 128)
           %just assign the end value and we're done
           lut_dac = [lut_dac; [-128, v_neg(end)]];
           break;
        end
      
        %Walk up the function until we're at the correct step length
        while(get_len(v_neg_n(1:v_pos), i_neg_n(1:v_pos)) < l_step*i)
           v_pos = v_pos + 1; 
        end
        if(sw == 0)
            v_pos = v_pos - 1;
            sw = 1;
        else
           sw = 0; 
        end
        
        %now assign this v to the next value and move on
        lut_dac = [lut_dac; [i*-1,v_neg(v_pos)]];
    end
    
    %Now we'll do the exact same thing for the positive side
    [zero_pos, fz] = find_zp(V_in, I_out, I_max_pos);
    
    v_pos = [];
    i_pos = [];
    if(zero_pos > fz)%If we were going in the positive direction
        %Flip here so we always count from zero on up
        v_pos = flip(V_in(fz : zero_pos));
        i_pos = flip(I_out(fz : zero_pos));
    else
        v_pos = V_in(zero_pos : fz);
        i_pos = I_out(zero_pos : fz);
    end
    
    
    v_pos_n = v_pos .* (1/max(abs(v_pos)));
    i_pos_n = i_pos .* (1/max(abs(i_pos)));
    
    
    sw = 0;%Switches between over and undershoot for each point
    %We've already assigned a zero point so now we just go walking on up
    l_step = get_len(v_pos_n, i_pos_n)/127;%Re-adjust for the new size
    v_p = 2;
    for i = 1:127%Only go to 127 on the positive side
        
        %if we're at the end
        if(i == 127)
           %just assign the end value and we're done
           lut_dac = [lut_dac; [127, v_pos(end)]];
           break;
        end
      
        %Walk up the function until we're at the correct step length
        while(get_len(v_pos_n(1:v_p), i_pos_n(1:v_p)) < l_step*i)
           v_p = v_p + 1; 
        end
        if(sw == 0)
            v_p = v_p - 1;
            sw = 1;
        else
           sw = 0; 
        end
        
        %now assign this v to the next value and move on
        lut_dac = [lut_dac; [i,v_pos(v_p)]];
    end
    
    %We not need to reverse the order of everything as the zero we picked
    %was not in the middle, so this step will fix that
    for i = 1:max(size(lut_dac))
       if(lut_dac(i,1) > 0) 
           lut_dac(i,1) = 128 - lut_dac(i,1);
       elseif(lut_dac(i,1) < 0)
           lut_dac(i,1) = -129 - lut_dac(i,1);
       end
    end
    

end


%This function is supposed to determine the furthest zero from the
%positive/negative peak of the nonlinear function
function [zp, fz] = find_zp(v_in, i_in, peak_pos)

    %If we're starting off at a negative peak
    if(i_in(peak_pos) < 0)
        %Just invert everything so it's fine
        i_in = i_in .* -1;
    end
    
    %Start walking in both directions from the -128 peak to see which side goes positive first
    %Whichever side goes positive first, we'll assume it's too close to the
    %127 peak and keep going in the opposite direction
    p_pos = peak_pos;
    n_pos = peak_pos;
    first = 0;
    zp = 0;
    while(1)
        
        %If we found a negative value on the positive side
        if(i_in(p_pos) < 0 && first ~= 'p')
           %If we already found a positive value on the negative side
           if(first == 'n')
               zp = p_pos;
               break;%We're done
           else
               first = 'p';
               fz = p_pos;
           end
        elseif(abs( (i_in(p_pos)/i_in(peak_pos))) < 0.01 && first == 'n')
            zp = p_pos;
            break;%We're done
        end
        
        %If we found a negative value on the negative side
        if(i_in(n_pos) < 0 && first ~= 'n')
            if(first == 'p') 
              zp = n_pos;
              break;%We're done
            else
               first = 'n'; 
               fz = n_pos;
            end
        elseif(abs( (i_in(n_pos)/i_in(peak_pos))) < 0.01 && first == 'p')
            zp = n_pos;
            break;%We're done
        end
        
        %If we can step further in the positive direction
        if(p_pos > 1 && p_pos < max(size(i_in)))
            if(first ~= 'p')
                p_pos = p_pos + 1;
            end
        else
           %If we reached the positive end and the negative side was
           %already first
           if(first == 'n')
              %If there's enough points here
              if(abs(p_pos - peak_pos) > 256)
                    zp = p_pos;
                    break;%We're done, we'll use the positive side
              else
                  %Fail
                  error("NL LUT CAL FAIL");
              end
           else%Othwerwise just keep going on the negative side
               first = 'p';
           end
        end
        
        %If we can step further in the positive direction
        if(n_pos > 1 && n_pos < max(size(i_in)))
            if(first ~= 'n')
                n_pos = n_pos - 1;
            end
        else
           %If we reached the positive end and the negative side was
           %already first
           if(first == 'p')
              %If there's enough points here
              if(abs(n_pos - peak_pos) > 256)
                    zp = n_pos;
                    break;%We're done, we'll use the positive side
              else
                  %Fail
                  error("NL LUT CAL FAIL");
              end
           else%Othwerwise just keep going on the negative side
               first = 'n';
           end
        end
        
    end
end





function l = get_len(v_in, i_in)
    l = 0;
    for i = 2:max(size(v_in))
        l = l + sqrt( ((v_in(i)-v_in(i-1))^2) + ((i_in(i)-i_in(i-1))^2) );
    end
end