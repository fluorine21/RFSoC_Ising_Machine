clear;clc;close all;

t = readtable("EOM_meas_dec_2021.xlsx");

%This is the analysis for Ryoto's first working device (That I accidentally
%bent some of the wirebonds on). 

%V_pi mm calculations 

%Format is length, vp
vp_11 = [t{1:2,2},t{1:2,4}; t{5:6,2},t{5:6,4}; t{9:10,2},t{9:10,4}];
vp_9 = [t{3,2},t{3,4}; t{7,2},t{7,4}; t{11,2},t{11,4}];
vp_7 = [t{4,2},t{4,4}; t{8,2},t{8,4}; t{12,2},t{12,4}];

%Invert all of the lengths
vp_11(:,1) = (vp_11(:,1).^-1);
vp_9(:,1) = (vp_9(:,1).^-1);
vp_7(:,1) = (vp_7(:,1).^-1);

%Linear fits
P11 = polyfit(vp_11(:,1), vp_11(:,2), 1);
P9 = polyfit(vp_9(:,1), vp_9(:,2), 1);
P7 = polyfit(vp_7(:,1), vp_7(:,2), 1);


%Plot everything
figure();
subplot(1,3,1);
hold on
plot(vp_11(:,1), vp_11(:,2), "r*");
fplot(@(x) P11(1).*x + P11(2));
xlabel("Inverse Length (1/mm)");
ylabel("V_{\pi}");
title(sprintf("11um separation, slope = %f V*mm", P11(1)));
xlim([0, max(vp_11(:,1))*1.2]);
legend("data", "linear fit");


subplot(1,3,2);
hold on
plot(vp_9(:,1), vp_9(:,2), "r*");
fplot(@(x) P9(1).*x + P9(2));
xlabel("Inverse Length (1/mm)");
ylabel("V_{\pi}");
title(sprintf("9um separation, slope = %f V*mm", P9(1)));
xlim([0, max(vp_9(:,1))*1.2]);
legend("data", "linear fit");

subplot(1,3,3);
hold on
plot(vp_7(:,1), vp_7(:,2), "r*");
fplot(@(x) P7(1).*x + P7(2));
xlabel("Inverse Length (1/mm)");
ylabel("V_{\pi}");
title(sprintf("7um separation, slope = %f V*mm", P7(1)));
xlim([0, max(vp_7(:,1))*1.2]);
legend("data", "linear fit");


%-12mV is the lowest signal we read on the slow detector at med gain (with
%no input power)
%But I see in my measurements its around -22 so we'll go with -30;

ofs = -30;

%Format is low, high
%Subtract out the lowest signal offset
exv_2_t = t{1:4,5:6} - ofs;
exv_2_c = t{1:4,7:8} - ofs;

exv_4_t = t{5:8,5:6} - ofs;
exv_4_c = t{5:8,7:8} - ofs;

exv_6_t = t{9:12,5:6} - ofs;
exv_6_c = t{9:12,7:8} - ofs;


er = @(l,h) log10((h./l))*10;

%Now we will plot device length vs extinction ratio
exv_2_t = er(exv_2_t(:,1), exv_2_t(:,2));
exv_2_c = er(exv_2_c(:,1), exv_2_c(:,2));
exv_4_t = er(exv_4_t(:,1), exv_4_t(:,2));
exv_4_c = er(exv_4_c(:,1), exv_4_c(:,2));
exv_6_t = er(exv_6_t(:,1), exv_6_t(:,2));
exv_6_c = er(exv_6_c(:,1), exv_6_c(:,2));

figure();
hold on
plot([2,2,2,2], exv_2_t, "r*");
plot([2,2,2,2], exv_2_c, "b*");

plot([4,4,4,4], exv_4_t, "r*");
plot([4,4,4,4], exv_4_c, "b*");

plot([6,6,6,6], exv_6_t, "r*");
plot([6,6,6,6], exv_6_c, "b*");
title("Extinction Ratio vs Device Length");
legend("Thru", "Coupled");
xlabel("Device Length (mm)");
ylabel("Extinction Ratio (dB)");
xlim([1,7]);











