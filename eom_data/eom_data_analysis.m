clear; close all; clc;


t2 = readtable("2022_2_27/noMHz.csv");
figure();
plot(t2{:,1}, t2{:,2});
title("No Modulation slow detector")
xlabel("Time (s)");
ylabel("Detector Voltage (V)");
ylim([0, max(t2{:,2})*1.2]);

t2 = readtable("2022_2_27/noMHz_2.csv");
figure();
plot(t2{:,1}, t2{:,2});
title("No Modulation fast detector")
xlabel("Time (s)");
ylabel("Detector Voltage (V)");

%list of directories
dir_list = ["2022_2_27/group5_1", "2022_2_27/group4_3", "2022_1_27/long_1"];

res_list = {};

for k = 1:max(size(dir_list))

%Get all the files in the directory
files = dir(dir_list(k));
freq_l = [];
rat_l = [];
for i = 1:max(size(files))
    
   filename = files(i).name;
   if(max(size(filename)) < 4)
      continue 
   end
   ext = filename(max(size(filename))-2:end);
   filename_full = dir_list(k)+"\"+filename;
   if(strcmp(ext, 'csv'))
       fprintf("Processing %s...\n", filename);
       c = regexp(filename,'\d*','Match');
       c = c{1,1};
       base_freq = str2num(c);
       mul = filename(max(size(filename))-6:max(size(filename))-4);
       if(strcmp(mul, 'kHz'))
           base_freq = base_freq * 1e3;
       elseif(strcmp(mul,'MHz'))
           base_freq = base_freq * 1e6;
       end
       
       [mi, ma, gain_fit] = get_min_max(readtable(filename_full), base_freq);
       rat = log10((ma/mi))*10;
       freq_l = [freq_l, base_freq];
       rat_l = [rat_l; rat,gain_fit];
       
   end
end

b = sortrows([freq_l',rat_l]);

res_list{1,k} = b;

end

figure();
hold on

for k = 1:max(size(res_list))
    b = res_list{1,k};
    %plot(b(:,1), b(:,2), 'linewidth', 2);
    err = b(:,2)*0.3;
    errorbar(b(:,1), b(:,2), err, 'linewidth', 2);
    plot(b(:,1), b(:,3), '--', 'linewidth', 2);
end
title("Transfer measurement");
xlabel("Frequency (Hz)");
ylabel("Extinction Ratio (dB)");
set(gca, 'XScale', 'log')
legend("long 1 (DC)", "long 1 fit (DC)", "short rf", "short rf fit", "long rf" ,"long rf fit");





function [mi, ma, gain_fit] = get_min_max(t, freq)

%Estimate how many pulses should be in this waveform
exp_num_pulse = round((t{end,1}-t{1,1})/(4e-9));

thresh = max(t{:,2})/100;
thresh_step = max(t{:,2})/1000;
gd = 0;
gu = 0;
while 1
   peak_list = get_peaks(t{:,:}, thresh);
   if(max(size(peak_list)) > exp_num_pulse)
       if(gd)
           break;
       end
       thresh = thresh + thresh_step;
       gu = 1;
   elseif(max(size(peak_list)) < exp_num_pulse)
       if(gu)
          break; 
       end
       thresh = thresh - thresh_step;
       gd = 1;
   else
      break; 
   end
end



mi = min(peak_list(:,2));
ma = max(peak_list(:,2));

p_o = peak_list;

sr = abs(t{1,1}-t{2,1});
%resample before lowpass
t_vec = t{1,1}:4e-9:t{max(size(t)),1};
peak_resample = interp1(peak_list(:,1), peak_list(:,2), t_vec);
peak_resample(isnan(peak_resample)) = 0;

%Lowpass filter to remove noise
peak_resample = lowpass(peak_resample, freq*5, 1/sr);

%Fit to the function A*cos(B*sin(x) + C)
fo = fitoptions('Method','NonlinearLeastSquares',...
               'Lower',[ma/3,pi/4,freq/2,0,0,0],...
               'Upper',[ma+mi,(3*pi)/4, freq*6 ,2*pi, 2*pi,ma],...
               'StartPoint',[ma, 1, 2*pi*freq, pi,pi, mi]);
ft = fittype('(a*sin(b*cos((c*x)+d)+e))+f','options',fo);

[curve,gof] = fit(t_vec',peak_resample',ft);

f_fit = @(a,b,c,d,e,f,dt) (a.*sin(b.*cos(c*dt + d)+e))+f;
f_fit_p = @(dt) f_fit(curve.a, curve.b, curve.c, curve.d, curve.e, curve.f, dt);
figure();
hold on
plot(t{:,1}, t{:,2});
plot(p_o(:,1), p_o(:,2), "g*");
plot(t_vec, peak_resample, "r*");
fplot(f_fit_p, [peak_list(1,1), peak_list(max(size(peak_list)),1)], 'linewidth', 2);
title(sprintf("F = %ikHz, r2 = %f, F fit = %fkHz", freq/1000, gof.rsquare, curve.c/(2*pi*1000)));
xlabel("Time (s)");
ylabel("Detector Voltage (V)");
legend("Original waveform","original peaks", "Resampled peaks",  "function fit");


h = max(f_fit_p(t_vec));
l = min(f_fit_p(t_vec));
gain_fit = log10(h/l)*10;
end




%peak list is [time, value]
function p_l = get_peaks(peak_in, thresh)
    p_l = zeros(100,2);
    j = 1;
    for i = 2:max(size(peak_in))-1
        if(peak_in(i,2) > thresh && peak_in(i,2) > peak_in(i-1,2) && peak_in(i,2) > peak_in(i+1,2))
           %If this peak was too close to the last one
           if(j > 1 && abs(peak_in(i,1)-p_l(j-1,1)) < 1e-9)
               %If it's larger then swap it out
              if(peak_in(i,2)>p_l(j-1,2))
                  p_l(j-1,1) = peak_in(i,1);
                  p_l(j-1,2) = peak_in(i,2);
              end
              continue 
           end
            if(j > max(size(p_l)))
              p_l = [p_l; zeros(100,2)]; 
           end
           p_l(j,1) = peak_in(i,1);
           p_l(j,2) = peak_in(i,2);
           j = j + 1;
        end
    end
    
    j = max(size(p_l));
    while(p_l(j,1) == 0)
       j = j - 1; 
    end
    p_l = p_l(1:j,:);

end



