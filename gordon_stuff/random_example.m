% example of how to use high-level MATLAB functions to compile the FPGA
% files for matrix-vector multiplication with random values

% date: 23-Jul-2021 10:16:15
% author: Gordon H.Y. Li, California Institute of Technology

clear all;
rng default; % for reproducibility
filepath_pre = 'data'; % folder to save files
d = 3; % number of delay time steps
w = 1; % all data values are in [-w,w]
M = (rand(8,8)*2-1)/3; % random 8x8 matrix with values in [-1,1]/3
v = (rand(8,1)*2-1)/3; % random 8x1 column vector with values in [-1,1]/3
[a,b,c,in,out] = matrix_vector_multiplication(M,v,d,1,0); 
data = data_to_int8({a,b,c,out},[-w,w]);
% write files
writematrix(data{1},[filepath_pre,'/a.txt']);
writematrix(data{2},[filepath_pre,'/b.txt']);
writematrix(data{3},[filepath_pre,'/c.txt']);
writematrix(data{4},[filepath_pre,'/out.txt']);
cssm(in,[filepath_pre,'/in.txt']);

% perform time-multiplexed simulation
[a_read,b_read,c_read,in_read] = read_data(filepath_pre);
data_sim = simulation(filepath_pre,@f,d);
% compare the expected int8 output of M*v to the int8 time-multiplexed output
comp_out_int8 = [data{4},data_sim{end,4}]; 
% compare the expected double output of M*v to the double time-multiplexed output
Mv = data_to_double({data_sim{end,4}},[-w,w]);
comp_out_double = [out,Mv{1}]; 