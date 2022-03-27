clear;clc;close all;

t1 = readtable("mzi_test_results.csv");
plot(t1{:,1}, t1{:,2});