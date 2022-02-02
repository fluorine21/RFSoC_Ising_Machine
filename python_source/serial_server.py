# -*- coding: utf-8 -*-
"""
Created on Fri Jan 21 11:03:11 2022

@author: James Williams
"""

import socket
import serial
import ssl
import os.path 
import os
from pathlib import Path
from OpenSSL import crypto
import time

BAUDRATE = 115200
UART_TIMEOUT = 1000
SERVER_TIMEOUT = 1000
CLIENT_TIMEOUT = 1000

none = None

#Command definitions
CMD_LEN = 5 # in bytes
CMD_WRITE = 0
CMD_READ = 1
CMD_SHUTDOWN = 2
CMD_OPEN = 3
CMD_CLOSE = 4
CMD_DC = 5 #Disconnect from server
CMD_PING = 6


#Serial port buffer sizes
RX_S = 10e3#10k
TX_S = 10e3

UART_TIMEOUT = 10
portname = "COM1" #default, will be overwritten by client

SOCKET_TIMEOUT = 100
PORT_NUM = 25567

#replaced with os cwd below
#pem_path = 'C:\certs\certchain.pem'
#key_path = 'C:\certs\private.key'
#SSL_PATH = 'C:\certs'


#Does certificate generation for SSL socket
def cert_gen(
    KEY_FILE,
    CERT_FILE,
    emailAddress="a@g.co",
    commonName="cn",
    countryName="CA",
    localityName="SB",
    stateOrProvinceName="Illinois",
    organizationName="UC",
    organizationUnitName="QC",
    serialNumber=0,
    validityStartInSeconds=0,
    validityEndInSeconds=10*365*24*60*60):
    #can look at generated file using openssl:
    #openssl x509 -inform pem -in selfsigned.crt -noout -text
    # create a key pair
    k = crypto.PKey()
    k.generate_key(crypto.TYPE_RSA, 4096)
    
    
    SSL_PATH = str(Path.home())
    #Create the directory if it does not exist
    if not os.path.exists(SSL_PATH):
        os.makedirs(SSL_PATH)
    
    
    # create a self-signed cert
    cert = crypto.X509()
    cert.get_subject().C = countryName
    cert.get_subject().ST = stateOrProvinceName
    cert.get_subject().L = localityName
    cert.get_subject().O = organizationName
    cert.get_subject().OU = organizationUnitName
    cert.get_subject().CN = commonName
    cert.get_subject().emailAddress = emailAddress
    cert.set_serial_number(serialNumber)
    cert.gmtime_adj_notBefore(0)
    cert.gmtime_adj_notAfter(validityEndInSeconds)
    cert.set_issuer(cert.get_subject())
    cert.set_pubkey(k)
    cert.sign(k, 'sha512')
    with open(CERT_FILE, "wt+") as f:
        f.write(crypto.dump_certificate(crypto.FILETYPE_PEM, cert).decode("utf-8"))
    with open(KEY_FILE, "wt+") as f:
        f.write(crypto.dump_privatekey(crypto.FILETYPE_PEM, k).decode("utf-8"))

#Receives a user-defined number of bytes from an open socket c
#Returns bytestream on success
#Returns -1 on timeout
#Returns -2 on dead socket
#Returns -3 on other error
def receive_bytes(c, num_bytes):
    
    byte_res = []
                
    while(1):
        
        try:
            
            num_bytes_to_receive = num_bytes - len(byte_res)
            if(num_bytes_to_receive > 1024):
                num_bytes_to_receive = 1024
            
            #res = c.recv(1024)
            res = c.recv(num_bytes_to_receive)
            
            if(len(res) > 0):
        
                #copy all bytes into the result array
                #for b in res:
                byte_res += list(res)
                #If we have all of the bytes
                if(len(byte_res) >= num_bytes):
                    return byte_res
            else:
                print("Received an empty byte array from socket, socket is probably closed...")
                return -2
        except socket.timeout:
            #print("Timed out while waiting for bytes...")
            return -1
        #except Exception as e:
            #print("Unknown error occured while waiting for bytes")
            #return -3

class serial_server:
    
    port = none #Serial port handle to be used
    sck = none #Initial unsecure socket over which we listen for connections
    shutdown_flag = 0
    
    def __init__(self):
        
        self.pem_path = str(Path.home())+'\certchain.pem'
        self.key_path = str(Path.home())+'\private.key'
        #SSL_PATH = str(Path.home())
        
        
        #Open serial port
        self.port = serial.Serial()
        self.port.baudrate = BAUDRATE
        self.port.port = portname
        self.port.timeout = UART_TIMEOUT
        self.port.set_buffer_size(rx_size = RX_S, tx_size = TX_S)
        
        
        print("Initializing serial server in secure mode")
        #Make sure we have an SSL key
        self.check_key()
        
        #SSL Stuff
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(self.pem_path, self.key_path)
        
        self.sck = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)
        self.sck.settimeout(SOCKET_TIMEOUT)
        
        try:
            while(not self.shutdown_flag):
                self.handle_client()
        except KeyboardInterrupt():
            print("Keyboard interrupt")
        print("Closing serial server")
        return
    
    def check_key(self):
        #If the key already exists
        if(os.path.exists(self.key_path) and os.path.exists(self.pem_path)):
            print("SSL Key found, skiping key generation...")
            return
        #Generate a key
        print("No SSL key found, generating key...")
        cert_gen(self.key_path, self.pem_path)
        return
    
    def handle_client(self):
        
        c_s = None
        while(1):
            #Get a live one on the hook
            try:
                c_s = self.get_connection()
                break
            except Exception as ex:
                if(type(ex) == KeyboardInterrupt()):
                    raise
                else:
                    print("Retrying listen...")
        
        #Get a command from the client (5 bytes)
        while(1):
            cmd = receive_bytes(c_s, CMD_LEN)
            num_bytes = int.from_bytes(cmd[1:CMD_LEN-1], byteorder='big', signed = False) 
            if(cmd == 1):
                continue
            if(cmd == 2):
                print("Socket closed, listening for new connection...")
                return
            
            if(cmd[0] == CMD_WRITE):
                if(num_bytes == 0):
                    print("ERROR: CMD payload len was 0")
                    continue
                payload = receive_bytes(c_s, CMD_LEN)
                if(type(payload) == int):
                    print("Error recieving send payload")
                    continue
                if(self.port.isOpen()):
                    self.port.write(payload)
                else:
                    print("Port was not open, ignoring send command")
                    continue
            elif(cmd[0] == CMD_READ):
               #Send the recieve length as a 4 byte number first
               #c_s.send(int(self.port.inWaiting()).to_bytes(4, byteorder='big', signed = False))
               #Send all of the bytes
               #c_s.send(self.port.read(self.port.inWaiting()))
               nb = num_bytes
               if(num_bytes > self.port.inWaiting()):
                   print("Warning, client tried to read " + str(num_bytes) + " but only " + str(self.port.inWaiting()) + " bytes were available")
                   nb = self.port.inWaiting()
               b = self.port.read(nb)
               c_s.send(int(len(b)).to_bytes(4, byteorder='big', signed = False))
               c_s.send(b)
               
               
            elif(cmd[0] == CMD_SHUTDOWN):
               self.shutdown_flag = 1
               return
            elif(cmd[0] == CMD_OPEN):
                #Get the requestred port name
               pn = str(cmd[1])
               pn = "COM" + pn
               res = 0
               try:
                   self.port.port = pn
                   self.port.open()
               except:
                   res = 1
               c_s.send([res])
            elif(cmd[0] == CMD_CLOSE):
               self.port.close()
            elif(cmd[0] == CMD_DC):
                c_s.shutdown(socket.SHUT_RDWR)
                c_s.close()
                return
               
            
            
            
        
        
    
    def get_connection(self):
        print("Listening for an incomming connection on port " + str(PORT_NUM))
        while(1):
            try:
                 #Once a client connects we'll be here
                c, addr = self.sck.accept()     # Establish connection with client.
                print("Got a connection from " + addr[0])
                
                try:
                    c_s = ssl.wrap_socket(c,
                            server_side=True,
                            certfile=self.pem_path,
                            keyfile=self.key_path,
                            ssl_version=ssl.PROTOCOL_TLS)
                except:
                    print("Unknown error while performing TLS handshake, still waiting for client connection")
                    continue
                
                c_s.settimeout(SERVER_TIMEOUT)
                return c_s
            except socket.timeout:
                #print("Waiting for client connection...")
                continue
            except:
                print("Unknown error while waiting for client connection")
                raise
            
        
        
        


class serial_client:
    
    portname = ""
    baudrate = 115200
    server_ip = ""
    sck_u = None
    s = None #Secure socket to be used
    port_num = PORT_NUM
    
    
    def __init__(self, pn, s_ip, p_num):
        
        self.pem_path = str(Path.home())+'\certchain.pem'
        self.key_path = str(Path.home())+'\private.key'
        
        self.server_ip = s_ip
        self.portname = pn
        self.port_num = p_num
        
        #Connect to the server
        self.conect_to_server();
        


    def connect_to_server(self):
       
      
       print("Attempting to connect to server")
       
       #Open a totally new socket every time
       self.sck_u = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)
       self.s = ssl.wrap_socket(self.sck_u, ca_certs=self.pem_path)
       
       self.s.settimeout(CLIENT_TIMEOUT)
       
       #connect to the client
       self.s.connect((self.server_ip, self.port))
       time.sleep(0.1)
       self.s.send([CMD_PING] + (CMD_LEN-1)*[0])
       b = receive_bytes(self.s, 1)
       if(type(b) == int):
           print("Failed to connect to server at " + str(self.server_ip))
           return -1
       else:
           print("Connected to server!")
           print("SSL version: " + self.s.version())
           return 0

    def send_cmd(self, CMD):
    
        try:
            self.s.send([CMD_OPEN] + [self.port&0xFF] +(CMD_LEN - 2)*[0])
            return 0
        except:
            print("Server disconnected, trying once to reconnect...")
            if(self.connect_to_server()):
                print("Failed to connect to server")
                return -1
        try:
            self.s.send([CMD_OPEN] + [self.port_num&0xFF] +(CMD_LEN - 2)*[0])
            return 0
        except:
            return -1

    
    def open(self):
        
        #Get the port number
        pn = [int(i) for i in self.portname.split() if i.isdigit()]
        
        if(self.send_cmd([CMD_OPEN] + [pn&0xFF] + (CMD_LEN-2)*[0])):
            print("Failed to send open port command to server")
            return 1
        b = receive_bytes(self.s, 1)
        if(type(b) == int):
            print("Failed to receive server response")
            return 1
        return b[0]
        
        
    def close(self):
        
        if(self.send_cmd([CMD_CLOSE] + (CMD_LEN-1)*[0])):
            print("Failed to send close port command to server")
            return 1
        
        
    def read(self):
        
        if(self.send_cmd([CMD_READ] + (CMD_LEN-1)*[0])):
            print("Failed to send close port command to server")
            return 1
        b = receive_bytes(self.s,4)
        if(type(b)==int):
            print("Failed to receive read len")
            return 1
        n_b = int.from_bytes(b, byteorder='big', signed = False)
        b = receive_bytes(self.s,n_b)
        if(type(b)==int):
            print("Failed to receive read payload")
            return 1
        return b
        
        
        
    def write(self, b):
        
        if(self.send_cmd([CMD_WRITE] + (CMD_LEN-1)*[0])):
            print("Failed to send close port command to server")
            return 1
        blen = int(len(b)).to_bytes(4, byteorder='big', signed = False)
        a = self.send_cmd(blen)
        a += self.send_cmd(b)
        if(a):
            return 1
        return 0