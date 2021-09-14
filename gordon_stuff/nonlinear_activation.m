function [a,b,c,in,out] = nonlinear_activation(f,v,d,compute_expected,input_FIFO)
% converts matrix-vector multiplication to time-multiplexed instructions
% (final vector values are stored in C FIFO)
% -------------------------------------------------------------------------
% inputs:
% f - function handle for nonlinear activation function
% v - vector (only used if input_FIFO == 0 or compute_expected == 1, otherwise ignored)
% d - number of delay time steps between sending the modulator voltage and
% receiving the computation output from the ADC (measured during
% calibration on FPGA)
% compute_expected - 0 = don't compute expected output,
% 1 = compute the expected output for diagnostic purposes
% input_FIFO - 0 = use v as the input vector, 1 = use A FIFO values as the input vector 
% -------------------------------------------------------------------------
% outputs:
% a - vector containing the initial FIFO values for modulator a
% b - vector containing the initial FIFO values for modulator b
% c - vector containing the initial FIFO values for modulator c
% in - cell array containing the FPGA instructions at each time step
% (c.f. https://www.overleaf.com/project/60f9aa175bf7a54e7a5741ef)
% out - vector containing the expected time-multiplexed output of the 
% element-wise nonlinear activation (out = f(v)) at each time step (empty if
% compute_expected == 0)
% -------------------------------------------------------------------------

if length(v) <= d
    % TO DO
    disp('special case for very small network size not implemented yet!');
    return
end
out = [];
if compute_expected == 1
    out = zeros(1+d+length(v),1);
    out(1:d+1) = NaN;
    out(d+1:end) = f(v);
end
if input_FIFO == 0
    a = v;
elseif input_FIFO == 1
    a = [];
else
    disp('input_FIFO must be 0 or 1!');
    return;
end
b = [0];
c = [];
in = cell(d+length(v)+1,1);
in{1} = 'SWI, MZC;';
num = 2;
for k = 1:length(v)
    in{num} = 'RMA';
    if num > d + 1
        in{num} = [in{num},', MRC;'];
    else
        in{num} = [in{num},';'];
    end
    num = num + 1;
end
for k = 1:d 
    in{1+length(v)+k} = 'MRC;';
end
in{1+length(v)+d} = ['RMB, RMC, SWI, ',in{1+length(v)+d}];
end
