

import ising_config::*;


module adc_driver
#(
parameter addr_reg = 0,
parameter data_reg = 1,
parameter shift_amt_reg_base_addr = 2,
parameter sample_selector_addr = 3
)
(
	input wire clk, rst,
	
	input wire [31:0] gpio_in,
	
	//Input from ADC
	input wire [127:0] s_axis_tdata,
	input wire s_axis_tvalid,
	output wire s_axis_tready,
	
	//Output to experiment FSM
	output wire [num_bits-1:0] val_out,
	output wire val_valid,
	
	input wire adc_input_scaler_run,//From FSM, tells peak detector to start processing data, need to OR this with del trig
	
	//Output to PS over DMA
	output wire [127:0] m_axis_tdata,
	output wire m_axis_tvalid,
	input wire m_axis_tready,
	
	input wire del_trig//From CPU, tells adc driver when to start recording raw data
	
);

//GPIO bus definitions
wire w_clk = gpio_in[gpio_w_clk_bit];
wire [gpio_addr_width-1:0] gpio_addr = gpio_in[gpio_addr_start:gpio_addr_end];
wire [gpio_data_width-1:0] gpio_data = gpio_in[gpio_data_start:gpio_data_end];

assign s_axis_tready = 1;//Always ready to read data from ADC even if we're not using it


//Config reg for input shifter
wire [7:0] shift_amt;
config_reg #(8,1,16,shift_amt_reg_base_addr) shift_amt_reg_inst
(
	clk, rst,
	
	gpio_in, //GPIO bus, 15:0 is addr, 23:16 is data, 24 is w_clk
	
	shift_amt
);

//Input shifter instantiation
wire [127:0] shifted_adc_word;
shifter #(32, 128) input_shifter_inst
(
clk, rst, shift_amt, s_axis_tdata, shifted_adc_word
);


//peak detector instantiation
wire [15:0] peak_out;
// wire [2:0] peak_pos;
wire peak_out_valid = 1;
// peak_detector peak_detector_inst
// (
	// clk, rst,
	// shifted_adc_word,
	// adc_input_scaler_run,
	
	// peak_out, peak_out_valid, peak_pos
// );

//Sample Selector
sample_selector
#(sample_selector_addr) sample_selector_inst
(
	clk, rst,
	
	gpio_in,
	
	shifted_adc_word,
	
	peak_out //Might not actually be the peak but ya know, probably better this way
);

//Lookup table for input
lookup_table #(addr_reg, data_reg, 16, num_bits) input_lookup_table_inst
(
	clk, rst, gpio_in, peak_out, peak_out_valid, val_out, val_valid
);


//FSM for running the ADC buffer
reg adc_buffer_valid;
reg [1:0] state;
reg [9:0] cnt;
always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		adc_buffer_valid <= 0;
		state <= 0;
		cnt <= 0;
	end
	else begin
		case (state)
		0: begin
			//If we're begin triggered to run by the cpu
			if(del_trig) begin
				state <= 1;
				adc_buffer_valid <= 1;
				cnt <= 1020;
			end
		end
		1: begin
			if(!cnt) begin
				adc_buffer_valid <= 0;
				state <= 2;
			end
			else begin
				cnt <= cnt - 1;
			end
		end
		2: begin
			if(!del_trig)begin//If the triger line has been reset
				state <= 0;
			end
		end
		default begin
			state <= 0;
			adc_buffer_valid <= 0;
		end
		endcase
	end
end

//ADC buffer for PS readback
wire s_axis_tready_i;
//2**10 is 1024
axis_sync_fifo #(10, 128) adc_buffer(

	rst,
	clk,

    adc_buffer_valid,
    s_axis_tready_i,
    shifted_adc_word,
    
    m_axis_tdata,
    m_axis_tvalid,
    m_axis_tready 
);



endmodule



//We'll see if this ends up being synthesizable
//Might need to change to tree structure
module peak_detector
(
	input wire clk, rst,
	input wire [127:0] adc_word_in,
	input wire adc_word_in_valid,
	
	output reg [15:0] peak_out,
	output reg peak_out_valid,
	output reg [2:0] peak_pos_out
);


reg [127:0] adc_word_mag;//Absolute magnitude (all positive)
reg [127:0] adc_word_last;

integer i;
always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		adc_word_mag <= 0;
	end
	else begin
		if(adc_word_in_valid) begin
			peak_out_valid <= 1;
			adc_word_last <= adc_word_in;//Save for later
			for(i = 0; i < 8; i = i + 1) begin
				//If it's negative, invert it
				adc_word_mag[(i*16)+:16] <= adc_word_in[(i*16)+15] ? ~adc_word_in[(i*16)+:16] + 1 : adc_word_in[(i*16)+:16];
			end
		end
		else begin
			peak_out_valid <= 0;
		end
	end
end

reg [15:0] max_val;
reg [2:0] max_pos;
always @ * begin
	max_val = 0;
	max_pos = 0;
	for(i = 0; i < 8; i = i + 1) begin
		if(adc_word_mag[(i*16)+:16] > max_val) begin
			max_val = adc_word_mag[(i*16)+:16];
			max_pos = i;
		end
	end
	peak_out <= adc_word_last[(max_pos*16)+:16];
	peak_pos_out <= max_pos;
end



endmodule



