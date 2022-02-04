clear; close all; clc;


%Get all the files in the directory
files = dir;
freq_l = [];
rat_l = [];
for i = 1:max(size(files))
    
   filename = files(i).name;
   if(max(size(filename)) < 4)
      continue 
   end
   ext = filename(max(size(filename))-2:end);
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
       
       [mi, ma] = get_min_max(readtable(filename), base_freq);
       rat = log10((ma/mi))*10;
       freq_l = [freq_l, base_freq];
       rat_l = [rat_l, rat];
       
   end
end

b = sortrows([freq_l',rat_l']);

figure();
semilogx(b(:,1), b(:,2), 'linewidth', 2);
title("Transfer measurement");
xlabel("Frequency (Hz)");
ylabel("Extinction Ratio (dB)");



function [mi, ma] = get_min_max(t, freq)

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

figure();
hold on
plot(t{:,1}, t{:,2});
plot(peak_list(:,1), peak_list(:,2), "r*");
title(sprintf("F = %i", freq));

mi = min(peak_list(:,2));
ma = max(peak_list(:,2));

end

%peak list is [time, value]
function p_l = get_peaks(peak_in, thresh)
    p_l = zeros(100,2);
    j = 1;
    for i = 2:max(size(peak_in))-1
        if(peak_in(i,2) > thresh && peak_in(i,2) > peak_in(i-1,2) && peak_in(i,2) > peak_in(i+1,2))
           %If this peak was too close to the last one
           if(j > 1 && abs(peak_in(i,1)-p_l(j-1,1)) < 1e-9)
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

