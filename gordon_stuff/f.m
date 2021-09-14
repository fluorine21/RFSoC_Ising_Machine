function y = f(x)
% nonlinear activation function
% -------------------------------------------------------------------------
% inputs:
% x - vector of input values
% -------------------------------------------------------------------------
% outputs:
% y - vector of element-wise nonlinear activation of input values
% -------------------------------------------------------------------------

% TO DO: replace analytical CW solution for SHG with experimental data
y = x.*sech(x);
end
