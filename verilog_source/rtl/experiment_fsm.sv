


module experiment_fsm(
	input wire clk, rst,
	
	//Run trigger for starting experiment
	input wire run_trig,
	output reg run_done,//Done flag for when we've finished processing instructions
	
	//Instruction bus, upper 16 bits are instruction, lower 16 are data
	input wire [31:0] instr_axis_tdata,
	input wire instr_axis_tvalid,
	output wire instr_axis_tready,
	
	//alpha in and out bus///////////////
	input wire [num_bits-1:0] a_r_tdata;
	input wire a_r_tvalid,
	output wire a_r_tready,
	
	output wire [num_bits-1:0] a_w_tdata;
	output wire a_w_tvalid,
	input wire a_w_tready,
	/////////////////////////////////////
	
	//beta in and out bus////////////////
	//Don't think we actually need this
	//input wire [num_bits-1:0] b_r_tdata;
	//input wire b_r_tvalid,
	//output wire b_r_tready,
	
	//output wire [num_bits-1:0] b_w_tdata;
	//output wire b_w_tvalid,
	//input wire b_w_tready,
	/////////////////////////////////////
	
	//gamma in and out bus///////////////
	input wire [num_bits-1:0] c_r_tdata;
	input wire c_r_tvalid,
	output wire c_r_tready,
	
	output wire [num_bits-1:0] c_w_tdata;
	output wire c_w_tvalid,
	input wire c_w_tready,
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
	output wire [15:0] del_meas_mac_result,
	output wire [15:0] del_meas_nl_result,
	output reg del_done //Done flag for when this measurement finishes
);

reg [15:0] mac_del_counter, nl_del_counter;


wire [num_bits-1:0] mac_mag = mac_val_in[num_bits-1] ? (~mac_val_in+1) : mac_val_in;
wire [num_bits-1:0] nl_mag = nl_val_in[num_bits-1] ? (~nl_val_in+1) : nl_val_in;

task reset_regs();
begin

	state <= state_idle;

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
			end
			else if(bc_del_meas_trig) begin
				state <= state_del_meas_1;
				b_out <= del_meas_val;
				b_valid <= 1;
				c_out <= del_meas_val;
				c_valid <= 1;
				mac_run <= 1;
				nl_run <= 1;
			end
			else if(run_trig) begin
				state <= state_run;
			end
		end
		
		state_del_meas_1: begin
			a_valid <= 0;
			b_valid <= 0;
			c_valid <= 0;
			
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