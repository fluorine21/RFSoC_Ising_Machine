


module adc_driver
#(
parameter input_scaler_base_addr = 0,
parameter adc_trig_reg_base_addr = 256
)
(
	input wire clk, rst,
	
	input wire [31:0] gpio_in
	
	//Input from ADC
	input wire [127:0] s_axis_tdata,
	input wire s_axis_tvalid,
	output wire s_axis_tready,
	
	//Output to experiment FSM
	output wire [7:0] val_out,
	output wire val_valid,
	
	input wire adc_input_scaler_run,//From FSM, tells peak detector to start processing data
	
	//Output to PS over DMA
	output wire [127:0] m_axis_tdata,
	output wire m_axis_tvalid,
	input wire m_axis_tready
	
);

assign s_axis_tready = 1;


//peak detector instantiation
wire [15:0] peak_val;
wire [2:0] peak_pos;
wire peak_out_valid;
peak_detector peak_detector_inst
(
	clk, rst,
	s_axis_tdata,
	adc_input_scaler_run,
	
	peak_out, peak_out_valid, peak_pos
);

//input scaler instantiation
input_scaler #(input_scaler_base_addr) input_scaler_inst
(
	clk, rst,
	gpio_in,
	
	//Input from peak detector
	peak_out,
	peak_out_valid,
	
	val_out,
	val_valid
);


//config reg for triggering adc record
//Shift ammount register
wire [7:0] adc_trig;
config_reg #(8,1,16,adc_trig_reg_base_addr) adc_trig_reg
(
	clk, rst,
	
	gpio_in, //GPIO bus, 15:0 is addr, 23:16 is data, 24 is w_clk
	
	adc_trig
);

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
		case state:
		0: begin
			if(adc_trig[0]) begin
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
			if(!adc_trig[0])begin
				state <= 0;
			end
		end
		default begin
			state <= 0;
			adc_buffer_valid <= 0;
		end
	end
end

//ADC buffer for PS readback
wire s_axis_tready;
axis_sync_fifo #(1024, 128) adc_buffer(

	rst,
	clk,

    adc_buffer_valid,
    s_axis_tready,
    s_axis_tdata,
    
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
				adc_word_mag[(i*8)+:8] <= adc_word_in[(i*8)+7] ? ~adc_word_in[(i*8)+:16] + 1 : adc_word_in[(i*8)+:16];
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
		if(adc_word_mag[(i*8)+:16] > max_val) begin
			max_val = adc_word_mag[(i*8)+:16];
			max_pos = i;
		end
	end
	peak_out <= adc_word_last[(max_pos*8)+:16];
	peak_pos_out <= max_pos;
end



endmodule