function [a,b,c,in,out] = matrix_vector_multiplication(M,v,d,compute_expected,input_FIFO)
% converts matrix-vector multiplication to time-multiplexed instructions
% (final vector values are stored in A FIFO)
% -------------------------------------------------------------------------
% inputs:
% M - matrix
% v - vector (only used if input_FIFO == 0 or compute_expected == 1, otherwise ignored)
% d - number of delay time steps between sending the modulator voltage and
% receiving the computation output from the ADC (measured during
% calibration on FPGA)
% compute_expected - 0 = don't compute expected output,
% 1 = compute the expected output for diagnostic purposes
% input_FIFO - 0 = use v as the input vector, 1 = use C FIFO values as the input vector 
% -------------------------------------------------------------------------
% outputs:
% a - vector containing the initial FIFO values for modulator a
% b - vector containing the initial FIFO values for modulator b
% c - vector containing the initial FIFO values for modulator c
% in - cell array containing the FPGA instructions at each time step
% (c.f. https://www.overleaf.com/project/60f9aa175bf7a54e7a5741ef)
% out - vector containing the expected time-multiplexed output of the 
% matrix-vector multiplication (out = M.v) at each time step (empty if
% compute_expected == 0)
% -------------------------------------------------------------------------

if size(M,1) <= d || length(v) <= d
    % TO DO
    disp('special case for very small network size not implemented yet!');
    return
end
out = [];
if compute_expected == 1
    out = zeros(d+size(M,2)*size(M,1),1);
    out(1:d) = NaN;
    for k = 1:size(M,2)
        M0 = M;
        M0(:,k+1:end) = 0;
        v0 = v;
        v0(k+1:end) = 0;
        out(d+size(M,1)*(k-1)+1:d+size(M,1)*k) = M0*v0;
    end
end
a = zeros(size(M,1),1);
b = [M(:);0];
if input_FIFO == 0
    c = v;
elseif input_FIFO == 1
    c = [];
else
    disp('input_FIFO must be 0 or 1!');
    return;
end
in = cell(d+size(M,1)*size(M,2),1);
num = 1;
for k1 = 1:size(M,2)
    for k2 = 1:size(M,1)
        in{num} = 'RMA, RMB';
        if k2 == size(M,1)
            in{num} = [in{num},', RMC'];
        end
        if num > d
            in{num} = [in{num},', MRA;'];
        else
            in{num} = [in{num},';'];
        end
        if num == 1
            in{num} = ['MZC, ',in{num}];
        end
        num = num + 1;
    end 
end
for k = 1:d 
    in{size(M,1)*size(M,2)+k} = 'MRA;';
end
in{size(M,1)*size(M,2)+d} = ['RMB, RMC, ',in{size(M,1)*size(M,2)+d}];
end
