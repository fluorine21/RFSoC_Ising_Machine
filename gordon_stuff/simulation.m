function data = simulation(filepath_pre,f,d)
% performs time-multiplexed simulation using the given initial FIFO values
% and instructions (includes quantization effects from LUT and ADC)
% -------------------------------------------------------------------------
% inputs:
% filepath_pre - folder containing the input data
% f - function handle for nonlinear activation function
% d - number of delay time steps between sending the modulator voltage and
% receiving the computation output from the ADC (measured during
% calibration on FPGA)
% -------------------------------------------------------------------------
% outputs:
% data - cell array containing the FIFO (int8) and output (int8) values
% after each time step (row = time step, column = {a,b,c,out})
% -------------------------------------------------------------------------

mode = 0; % initialize in MAC mode
[a,b,c,in] = read_data(filepath_pre); % read input data
data = cell(length(in),4); % initialize data storage
out = zeros(length(in),1); % initialize outputs
for k = 1:length(in)
    % read modulator values
    data_mod = data_to_double({a(1),b(1),c(1)},[-1,1]);
    A = data_mod{1};
    B = data_mod{2};
    C = data_mod{3};
    x = A+B*C;
    if mode == 0
        if k+d <= length(in) 
            data_int8 = data_to_int8({x},[-1,1]);
        end
    elseif mode == 1
        if k+d <= length(in) 
            data_int8 = data_to_int8({f(x)},[-1,1]);
        end
    else
        disp('mode must be 0 or 1!');
        return;
    end
    out(k+d) = data_int8{1};
    if contains(in{k},'MRA')
        a = [a;out(k)];
    end
    if contains(in{k},'MRC')
        c = [c;out(k)];
    end
    if contains(in{k},'MZA')
        a = [a;0];
    end
    if contains(in{k},'MZC')
        c = [c;0];
    end
    if contains(in{k},'RMA')
        a = a(2:end);
    end
    if contains(in{k},'RMC')
        c = c(2:end);
    end
    if contains(in{k},'RMB')
        b = b(2:end);
    end
    if contains(in{k},'SWI')
        if mode == 0 
            mode = 1;
        elseif mode == 1
            mode = 0;
        else
            disp('mode must be 0 or 1!');
            return
        end
    end
    data{k,1} = a;
    data{k,2} = b;
    data{k,3} = c;
    data{k,4} = out(1:k);
end
end
