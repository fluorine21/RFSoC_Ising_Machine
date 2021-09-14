function data_int8 = data_to_int8(data,data_range)
% converts data from doubles (default numeric data type in MATLAB) to int8
% (format suitable for FPGA)
% -------------------------------------------------------------------------
% inputs:
% data - cell array containing vectors of data to be converted
% data_range - 1x2 row vector containing the data range
% [min(data),max(data)] to be scaled to the range [-127,127], any
% values outside the data range are mapped to the nearest endpoint
% -------------------------------------------------------------------------
% outputs:
% data_int8 - cell array containing vectors of data converted to int8
% -------------------------------------------------------------------------

data_int8 = cell(1,length(data));
for k = 1:length(data)
    data_int8{k} = int8(rescale(data{k},-127,127,'InputMin',data_range(1),'InputMax',data_range(2)));
end
end
