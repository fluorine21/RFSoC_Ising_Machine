function [a,b,c,in] = read_data(filepath_pre)
% reads FIFO and instruction input data
% -------------------------------------------------------------------------
% inputs:
% filepath_pre - folder containing the input data
% -------------------------------------------------------------------------
% outputs:
% a - vector containing A FIFO data (int8)
% b - vector containing B FIFO data (int8)
% c - vector containing C FIFO data (int8)
% in - cell array containing instruction data
% -------------------------------------------------------------------------
% read files
formatSpec = '%d'; % signed integer (base 10)
fileID = fopen([filepath_pre,'/a.txt'],'r');
a = fscanf(fileID,formatSpec);
fclose(fileID);
fileID = fopen([filepath_pre,'/b.txt'],'r');
b = fscanf(fileID,formatSpec);
fclose(fileID);
fileID = fopen([filepath_pre,'/c.txt'],'r');
c = fscanf(fileID,formatSpec);
fclose(fileID);
formatSpec = '%s'; % string
fileID = fopen([filepath_pre,'/in.txt'],'r');
in = textscan(fileID,formatSpec,'Delimiter',{';'});
fclose(fileID);
in = in{1,1};
end
