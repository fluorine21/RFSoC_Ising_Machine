clear; close all; clc;


t1 = readtable("nl_lut_gen_results.csv");

figure();
plot(t1{:, 1}, t1{:, 2}, 'linewidth', 2);