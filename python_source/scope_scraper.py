# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""

import visa
import numpy as np
import matplotlib.pyplot as plt
from struct import unpack
import time

source = "b207"
#source = "b229b"

# Establish Connection

rm = visa.ResourceManager('@py') # Calling PyVisaPy library
rm.list_resources()
#scope = rm.open_resource('USB0::0x0699::0x040C::No_Serial::INSTR') # Connecting via USB

#scope = rm.open_resource('TCPIP::131.215.138.154::INSTR') # B229B north table southwest corner 

scope = rm.open_resource('TCPIP::131.215.138.153::INSTR') # B207 southeast corner
# Setting source as Channel 1
scope.write('DATA:SOU CH1') 
scope.write('DATA:WIDTH 1') 
if(source == "b207"):
    scope.write(':DATa:ENCdg ascii')
    scope.write(':DATA:REsample 1')
if(source == "b229b"):
    scope.write('DATA:ENC RPB')
    

log_filename = "menlo_1550_power_log_b207"

def get_avg_val_new(num_avg):

    avg_list = []
    for j in range(0, num_avg):
        # Getting axis info
       #scope.write(':DATa:SOUrce CH1')
       #scope.write(':DATa:START 1')
       #scope.write(':DATa:STOP 1000000')
       #scope.write(':DATa:ENCdg ascii')
       #scope.write(':DATa:WIDth 1')
       #scope.write(':DATA:REsample 1')
    
       Npoints = int(scope.query('WFMOUTPRE:NR_PT?').split(' ')[-1]) 
       X_INCrement = float(scope.query('WFMOUTPRE:XINCR?')) # Time difference between data points; Could also be found with :WAVeform:XINCrement? after setting :WAVeform:SOURce
       X_ORIGin    = float(scope.query('WFMOUTPRE:XZEro?')) # Always the first data point in memory; Could also be found with :WAVeform:XORigin? after setting :WAVeform:SOURce
        
       time_data = X_ORIGin + X_INCrement*np.arange(Npoints)
        
       YMULt = float(scope.query('WFMOUTPRE:YMULt?')) 
       YZERo = float(scope.query('WFMOUTPRE:YZEro?')) 
       YREF = float(scope.query('WFMOUTPRE:Yoff?')) 
       c = np.array(scope.query('CURVe?').split(','), dtype=float)
        
       volt_data = YZERo + YMULt*(np.array(c, dtype=int) - YREF)
       
       avg_list.append(np.average(volt_data))
       print(".", end = '')

    
    return np.average(avg_list)



def get_avg_val(num_avg):

    avg_list = []
    for j in range(0, num_avg):
        # Getting axis info
        ymult = float(scope.query('WFMPRE:YMULT?')) # y-axis least count
        yzero = float(scope.query('WFMPRE:YZERO?')) # y-axis zero error
        yoff = float(scope.query('WFMPRE:YOFF?')) # y-axis offset
        xincr = float(scope.query('WFMPRE:XINCR?')) # x-axis least count
        
        # Reading Binary Data from instrument
        scope.write('CURVE?')
        data = scope.read_raw() # Reading binary data
        headerlen = 2 + int(data[1]) # Finding header length
        #header = data[:headerlen] # Separating header 
        ADC_wave = data[headerlen:-1] # Separating data
        
        # Converting to Binary to ASCII
        ADC_wave = np.array(unpack('%sB' % len(ADC_wave),ADC_wave))
        
        Volts = (ADC_wave - yoff) * ymult + yzero
        Time = np.arange(0, xincr * len(Volts), xincr)
        
        avg_list.append(np.average(Volts))
        print(".", end = '')
    
    # Plotting Volt Vs. Time
    #plt.plot(Time, Volts) 
    #plt.xlim(0, max(Time))
    #plt.ylim(-0.1, 1.5)
    #plt.show()
    
    return np.average(avg_list)


num_avg = 10
data_interval = 1 #in seconds
num_data_pts = int(60*60*10*(1/data_interval)) #collect this many averages


f = open(log_filename, "a")
f.write("timestamp (utc), avg voltage\r\n")
f.close()
a_t = []
a_l = []
t0 = time.time()
for i in range(0, num_data_pts):
    
    #Get data
    t3 = time.time()
    print("Getting waveform round " + str(i) + " out of " + str(num_data_pts))
    av = get_avg_val_new(2)
    print("Avg voltage was " + str(av))
    f = open(log_filename, "a")
    t1 = time.time()
    f.write(str(t1) + ", " + str(av) + "\r\n")
    f.close()
    a_t.append(t1-t0)
    a_l.append(av)
    
    
    # Plotting average
    plt.plot(a_t, a_l) 
    plt.xlim(0,max(a_t))
    plt.ylim(max(a_l)*0.8, max(a_l)*1.2)
    plt.xlabel("Time since start (s)")
    plt.ylabel("Detector voltage (V)")
    plt.show()
    
    t4 = time.time()-t3
    print("Elapsed sampling time was " + str(t4) + " seconds")
    if(t4 < data_interval):
        time.sleep(data_interval-(time.time()-t3))
    
print("Data collection finished")