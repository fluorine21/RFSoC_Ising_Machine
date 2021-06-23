


module experiment_fsm(
	input wire clk, rst,
	
	//Run trigger for starting experiment
	input wire run_trig,
	output reg run_done,//Done flag for when we've finished processing instructions
	
	//Instruction bus, upper 16 bits are instruction, lower 16 are data for the 32-bit bus coming from cpu
	input wire [16:0] instr_axis_tdata,
	input wire instr_axis_tvalid,
	output wire instr_axis_tready,
	
	//beta in bus////////////////
	input wire [num_bits-1:0] b_r_tdata;
	input wire b_r_tvalid,
	output reg b_r_tready,
	
	//Needed for CPU readback
	output wire [num_bits-1:0] a_in_data,
	output wire a_in_valid,
	output wire a_in_ready,
	
	input wire [num_bits-1:0] c_in_data,
	input wire c_in_valid,
	output wire c_in_ready,

	output wire [num_bits-1:0] a_out_data,
	output wire a_out_valid,
	input wire a_out_ready,
	
	output wire [num_bits-1:0] c_out_data,
	output wire c_out_valid,
	input wire c_out_ready,

	/////////////////////////////////////
	
	//Outputs to DAC drivers
	output reg [num_bits-1:0] a_out,
	output reg a_valid,
	
	output reg [num_bits-1:0] b_out,
	output reg b_valid,
	
	output reg [num_bits-1:0] c_out,
	output reg c_valid,
	
	
	//Inputs from ADC drivers
	input wire [num_bits-1:0] mac_val_in,
	input wire mac_val_valid,
	output reg mac_run,
	
	input wire [num_bits-1:0] nl_val_in,
	input wire nl_val_valid,
	output reg nl_run,
	
	
	//Inputs and outputs for delay measurement
	input wire a_del_meas_trig, bc_del_meas_trig,
	input wire [num_bits-1:0] del_meas_val,
	input wire [num_bits-1:0] del_meas_thresh,//If we reach this value the pulse is consildered as recieved and the timer stops
	output reg [15:0] del_meas_mac_result,
	output reg [15:0] del_meas_nl_result,
	output reg del_done, //Done flag for when this measurement finishes
	
	input wire halt//from shift reg attached to bus, tells fsm when to stop on buffer empty
);

//Delay measurement stuff
reg [15:0] mac_del_counter, nl_del_counter;
wire [num_bits-1:0] mac_mag = mac_val_in[num_bits-1] ? (~mac_val_in+1) : mac_val_in;
wire [num_bits-1:0] nl_mag = nl_val_in[num_bits-1] ? (~nl_val_in+1) : nl_val_in;


//Internal busses for alpha and gamma fifos////////////////////////////////
//alpha in and out bus///////////////
wire [num_bits-1:0] a_r_tdata;
wire a_r_tvalid;
reg a_r_tready;
assign a_out_data = a_r_tdata;
assign a_out_valid = a_r_tvalid;

reg [num_bits-1:0] a_w_tdata;
reg a_w_tvalid;
wire a_w_tready;
assign a_in_ready = a_w_tready;
/////////////////////////////////////

//gamma in and out bus///////////////
wire [num_bits-1:0] c_r_tdata;
wire c_r_tvalid;
reg c_r_tready;
assign c_out_data = c_r_tdata;
assign c_out_valid = c_r_tvalid;

reg [num_bits-1:0] c_w_tdata;
reg c_w_tvalid;
wire c_w_tready;
assign c_in_ready = c_w_tready;
/////////////////////////////////////


//Doing all the bus multiplexing down here
//alpha fifo
axis_sync_fifo
#(var_fifo_depth, num_bits) a_fifo_inst
(

	rst,
	clk,

    (a_w_tvalid | a_in_valid),
    a_w_tready,
    (a_in_valid ? a_in_data : a_w_tdata),//Prefer write from CPU
    
    a_r_tdata,
    a_r_tvalid,
    (a_r_tready | a_out_ready) //Readout from either the CPU or the FMS
);

//gamma fifo
axis_sync_fifo
#(var_fifo_depth, num_bits) c_fifo_inst
(

	rst,
	clk,

    (c_w_tvalid | c_in_valid),
    c_w_tready,
    (c_in_valid ? c_in_data : c_w_tdata),
    
    c_r_tdata,
    c_r_tvalid,
    (c_r_tready | c_out_ready) //Readout from either the CPU or the FMS
);
//////////////////////////////////////////////////////////////////////////

//1 if all buffers are valid, waits on invalid buffer but does not halt
wire buf_rdy = c_r_tvalid & a_r_tvalid & b_r_tvalid & instr_axis_tvalid;

reg out;//0 for MAC, 1 for NL (changed during runtime by instruction)
reg [num_bits-1:0] out_val = out ? nl_val_in : mac_val_in;

task execute_run();
begin
	
	//If we're done
	if(!instr_axis_tvalid && halt_in)begin
	
		state <= state_idle;//Return to the idle state 
		run_done <= 1;
	end
	//Only execute if we're on a valid instruction
	else if(!instr_axis_tvalid) begin
	
		//Buffer outputs always get pushed to DACs regardless of instruction
		a_out <= a_r_tdata;
		b_out <= b_r_tdata;
		c_out <= c_r_tdata;
		//They're also always valid here
		a_valid <= 1;
		b_valid <= 1;
		c_valid <= 1;
	
		if(instr_axis_tdata & (1 << 0) begin //remove a
			a_r_tready <= 1;
		end
		else
			a_r_tready <= 0;
		end
		
		if(instr_axis_tdata & (1 << 1) begin //remove b
			b_r_tready <= 1;
		end
		else
			b_r_tready <= 0;
		end
		
		if(instr_axis_tdata & (1 << 2) begin //remove c
			c_r_tready <= 1;
		end
		else
			c_r_tready <= 0;
		end
		
		if(instr_axis_tdata & (1 << 3) begin //add out -> a
			a_w_tdata <= out_val;
			a_w_tvalid <= 1;
		else
			a_w_tvalid <= 0;
		end
		
		if(instr_axis_tdata & (1 << 4) begin //add out -> c
			c_w_tdata <= out_val;
			c_w_tvalid <= 1;
		else
			c_w_tvalid <= 0;
		end
		
		if(instr_axis_tdata & (1 << 5) begin //add 0 -> a
			a_w_tdata <= 0;
			a_w_tvalid <= 1;
		else
			a_w_tvalid <= 0;
		end
		
		if(instr_axis_tdata & (1 << 6) begin //add 0 -> c
			c_w_tdata <= 0;
			c_w_tvalid <= 1;
		else
			c_w_tvalid <= 0;
		end
		
		if(instr_axis_tdata & (1 << 7) begin //switch
			out <= ~out;
		end
		if(instr_axis_tdata & (1 << 8) begin
		
		end
		if(instr_axis_tdata & (1 << 9) begin
		
		end
		if(instr_axis_tdata & (1 << 10) begin
		
		end
		if(instr_axis_tdata & (1 << 11) begin
		
		end
		if(instr_axis_tdata & (1 << 12) begin
		
		end
		if(instr_axis_tdata & (1 << 13) begin
		
		end
		if(instr_axis_tdata & (1 << 14) begin
		
		end
		if(instr_axis_tdata & (1 << 15) begin
		
		end
		
		
		
	
	end


end
endtask



task reset_regs();
begin

	state <= state_idle;
	
	a_w_tdata <= 0;
	a_w_tvalid <= 0;
	a_r_tready <= 0;
	c_w_tdata <= 0;
	c_w_tvalid <= 0;
	c_r_tready <= 0;
	
	b_r_tready <= 0;
	
	out <= 0;
	
	del_meas_mac_result <= 0;
	del_meas_nl_result <= 0;
	del_done <= 0;
	
	//Outputs to DACsa_out <= a_r_tdata;
	a_out <= 0;
	b_out <= 0;
	c_out <= 0;
	a_valid <= 0;
	b_valid <= 0;
	c_valid <= 0;
	
	
end
endtask

reg [2:0] state;
reg mac_done;
localparam [2:0] state_idle = 0, 
				 state_del_meas_1 = 1, 
				 state_del_meas_2 = 2, //waits for all triggers to go low before resetting
				 state_run = 3,
				 state_wait_rst = 4;


always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		reset_regs();
	end
	else begin
	
		case(state)
	
		state_idle: begin
		
			mac_del_counter <= 1;
			nl_del_counter <= 1;
			
			if(a_del_meas_trig) begin
				state <= state_del_meas_1;
				a_out <= del_meas_val;
				a_valid <= 1;
				mac_run <= 1;
				nl_run <= 1;
				del_done <= 0;
			end
			else if(bc_del_meas_trig) begin
				state <= state_del_meas_1;
				b_out <= del_meas_val;
				b_valid <= 1;
				c_out <= del_meas_val;
				c_valid <= 1;
				mac_run <= 1;
				nl_run <= 1;
				del_done <= 0;
			end
			else if(run_trig) begin
				state <= state_run;
				run_done <= 0;
			end
		end
		
		
		state_run: begin
			//If all of the buffers are ready
			if(buf_rdy) begin
				execute_run();
			end
		end
		
		
		state_del_meas_1: begin
			//keep all outputs valid so we bias the modulator back to 0 signal
			a_valid <= 1;
			b_valid <= 1;
			c_valid <= 1;
			
			//Set all outputs back to 0 here
			a_out <= 0;
			b_out <= 0;
			c_out <= 0;
			
			//If both are done
			if(mac_mag > del_meas_thresh && nl_mag > del_meas_thresh) begin
				//Report the results and wait for reset
				del_meas_mac_result <= mac_del_counter;
				del_meas_nl_result <= nl_del_counter;
				del_done <= 1;
				state <= state_wait_rst;
			end
			else if(mac_mag > del_meas_thresh) begin
				nl_del_counter <= nl_del_counter + 1;
				mac_done <= 1;
				state <= state_del_meas_2;
			end
			else if(nl_mag > del_meas_thresh) begin
				mac_del_counter <= mac_del_counter + 1;
				mac_done <= 0;
				state <= state_del_meas_2;
			end
			//If we had some kind of timeout
			else if(nl_del_counter > 255 || mac_del_counter > 255) begin
				//Report it as an error
				del_meas_mac_result <= 16'hffff;
				del_meas_nl_result <= 16'hffff;
				del_done <= 1;
				state <= state_wait_rst;
			end
			else begin
				//If nothing has happened yet just increment both counters
				nl_del_counter <= nl_del_counter + 1;
				mac_del_counter <= mac_del_counter + 1;
			end
		end
		
		state_del_meas_2: begin
		
			//If we're waiting on mac to finish up
			if(!mac_done) begin
				//if it's done
				if(mac_mag > del_meas_thresh) begin
					del_meas_mac_result <= mac_del_counter;	
					state <= state_wait_rst;
					del_done <= 1;
				end
				//If we've had overflow
				else if(mac_del_counter > 255) begin
					del_meas_mac_result <= 16'hffff;
					state <= state_wait_rst;
					del_done <= 1;
				end
				else begin
					mac_del_counter <= mac_del_counter + 1;
				end
			end
			else begin
				//if it's done
				if(nl_mag > del_meas_thresh) begin
					del_meas_nl_result <= nl_del_counter;	
					state <= state_wait_rst;
					del_done <= 1;
				end
				//If we've had overflow
				else if(nl_del_counter > 255) begin
					del_meas_nl_result <= 16'hffff;
					state <= state_wait_rst;
					del_done <= 1;
				end
				else begin
					nl_del_counter <= nl_del_counter + 1;
				end
			end
			
		end
	
		state_wait_rst: begin
			if(!a_del_meas_trig && !bc_del_meas_trig && !run_trig) begin
				state <= state_idle;
			end
		end
	
		endcase
	end
end



endmodule