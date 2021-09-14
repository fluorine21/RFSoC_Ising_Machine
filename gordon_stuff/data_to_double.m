function data_double = data_to_double(data,data_range)
% converts data from int8 (format suitable for FPGA) to double
% (default numeric data type in MATLAB)
% -------------------------------------------------------------------------
% inputs:
% data - cell array containing vectors of data to be converted
% data_range - 1x2 row vector containing the data range
% [min(data),max(data)] to be scaled from the int8 range [-127,127], any
% values outside the data range are mapped to the nearest endpoint
% -------------------------------------------------------------------------
% outputs:
% data_double - cell array containing vectors of data converted to double
% -------------------------------------------------------------------------

data_double = cell(1,length(data));
for k = 1:length(data)
    data_double{k} = double(rescale(data{k},data_range(1),data_range(2),'InputMin',-127,'InputMax',127));
end
end
