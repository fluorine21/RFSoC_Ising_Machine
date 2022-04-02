import ising_config::*;


//Assuming set point is positive value from 0 to 0xffff, will remap to 0x8000 to 0x7FFF by adding 0x8000 before output

module dl
#(parameter base_addr = 0)
(
	input wire clk, rst,
	input wire [31:0] gpio_in,
	
	//Incomming ADC data
	input wire [127:0] adc_data_in,
	
	input wire lock_sig_active,//if 1, a calibration pulse is currently being read back and must be locked to
	input wire trig_lock,//if 1, we're actively running the fsm and trying to lock
	output reg lock_done,//If 1, this module is not in the process of locking
	
	output wire [15:0] setpt_out_ext,//Setpoint output of the lockbox
	
	output reg err
);



//GPIO registers for setting internal values
reg [15:0] max_pos_tol;//The maximum must be this far away from the edge of the sweep to be accepted as valid
config_reg #(8,2,16,base_addr + 0) max_pos_tol_reg (clk, rst, gpio_in, max_pos_tol);

reg [15:0] setpt_in;//Tells the module where to start looking after being reset by trig_lock going low
config_reg #(8,2,16,base_addr + 1) setpt_in_reg (clk, rst, gpio_in, setpt_in);

reg [15:0] exp_val_in;//Tells the module what the expected initial max should be so it knows when it falls out of lock
config_reg #(8,2,16,base_addr + 2) exp_val_in_reg (clk, rst, gpio_in, exp_val_in);

reg [15:0] tol_in;//Tells the module what the expected initial max should be so it knows when it falls out of lock
config_reg #(8,2,16,base_addr + 3) tol_in_reg (clk, rst, gpio_in, tol_in);

reg [15:0] num_avgs;//Tells the module how many averages to take when measuring each point
config_reg #(8,2,16,base_addr + 4) num_avgs_reg (clk, rst, gpio_in, num_avgs);

reg [15:0] lock_sig_pos;//Tells us which sample is the locking sample
config_reg #(8,2,16,base_addr + 5) lock_sig_pos_reg (clk, rst, gpio_in, lock_sig_pos);

reg [15:0] setpt_step;//Tells us how much to increment the setpt by when searching
config_reg #(8,2,16,base_addr + 6) setpt_step_reg (clk, rst, gpio_in, setpt_step);

reg [15:0] wait_cnt_in;//Tells us how many cycles pass between putting out a value and getting the result back
config_reg #(8,2,16,base_addr + 6) wait_cnt_in_reg (clk, rst, gpio_in, wait_cnt_in);

//Internal setpt register and translation to signed value
reg [15:0] setpt_int;//Last setpt to work for us
reg [15:0] setpt_out;
assign setpt_out_ext = setpt_out + 16'h8000;


//Current locking signal value extraced from the adc sample list
wire[15:0] lock_sig_val = adc_data_in[(lock_sig_pos*8)+:16];

reg [15:0] wait_cnt;//Wait counter before doing the locking cycle

//Locking algorithm local variables, _f and _l are the high and low setpts used, which average we're currently outputting
reg [15:0] setpt_max, exp_val_max, exp_val_int, setpt_h, setpt_l, num_avgs_cnt;
reg [31:0] avg_reg;
reg [15:0] sum_cnt;//Second counter for the calculate and compare portion in collect_average()
//This counter is only for what to output, first is how many averages to collect (2**) second counter is for the total we'll collect to figure out when to end
reg [15:0] num_pts, num_pts_cnt;
localparam num_pts_max = 512;//Maxumum number of points to count on each side of previous lock
reg [2:0] state, lock_state;
localparam [2:0] state_idle = 0, state_run_lock = 1;
localparam [2:0] lock_idle = 0, lock_start_write = 1, lock_continue_write = 2, lock_cleanup = 3;


task reset_reg();
begin
	state <= state_idle;
	setpt_out <= 0;
	setpt_max <= 0;
	exp_val_max <= 0;
	exp_val_int <= 0;
	setpt_h <= 0;
	setpt_l <= 0;
	avg_reg <= 0;
	sum_cnt <= 0;
	num_pts <= 0;
	num_pts_cnt <= 0;
	err <= 0;
	lock_done <= 0;
end
endtask

initial begin
	reset_reg();
end

task collect_average();
begin
	//Collects a single average measurement
	//When finished, compares it to previous average and keeps it if it is larger
	//Average calculation and max update logic plus 
	if(sum_cnt >= num_avgs) begin//If we're done with this average
		sum_cnt <= 1;//Reser the sum counter
		//Update avg reg to new value this cycle
		avg_reg <= lock_sig_val;
		//if this is a new max
		if(avg_reg[num_avgs+:16] > setpt_max)begin
			exp_val_max <= avg_reg[num_avgs+:16];
			setpt_max <= setpt_out - (setpt_step*(wait_cnt_in>>num_avgs));
		end
			
	end
	else begin//Continue averaging
		sum_cnt <= sum_cnt + 1;
		avg_reg <= avg_reg + lock_sig_val;
	end

end
endtask


task update_setpt();
begin
	//Updates the setpt to the next search value
	if(num_avgs_cnt >= num_avgs) begin
		num_avgs_cnt <= 1;
		num_pts_cnt <= num_pts_cnt + 1;
		setpt_out <= setpt_out + setpt_step;
	end
	else begin
		num_avgs_cnt <= num_avgs_cnt + 1;
	end
end
endtask


//FSM for waiting wait_cnt_in before sending a pulse to lock_sig_active
reg [15:0] lock_sig_wait;
reg lock_sig_state;
reg lock_sig_active_int;
always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		lock_sig_state <= 0;
		lock_sig_active_int <= 0;
	end
	else begin
		if(!lock_sig_state) begin
			lock_sig_active_int <= 0;
			if(lock_sig_active) begin
				lock_sig_state <= 1;
				lock_sig_wait <= wait_cnt_in;
			end
		end
		else begin
			if(lock_sig_wait) begin
				lock_sig_wait <= lock_sig_wait - 1;
			end
			else begin
				lock_sig_active_int <= 1;
				lock_sig_state <= 0;
			end
		end
	end	
end


task run_lock_fsm();
begin
	case(lock_state)
	
		lock_idle: begin
			if(lock_done) begin
				//do nothing
			end
			else begin
			
				//We always increase the number of points we're taking each cycle by 2x
				num_pts <= num_pts + 1;//number of points to collect is (1 << num_pts);
				
				//If we're failing
				if(((1<<(num_pts+1))+1) > num_pts_max) begin
					err <= 1;
					lock_done <= 1;
				end
				
				
				state <= lock_start_write;
				
				//Setup the set point for the next round of data
				setpt_out <= setpt_int - (setpt_step << num_pts);
				setpt_l <= setpt_int - (setpt_step << num_pts);
				
				
				//And the counters we need
				wait_cnt <= wait_cnt_in;//Number of cycle delay between writing and reading
				num_avgs_cnt <= 1;//Which average we're currently outputting
				sum_cnt <= 1;//which average we're currently taking
				
				//Two variables for storing max experimental value and which setpt gave it to us
				exp_val_max <= 0;
				setpt_max <= 0;
			end
		
		end
	
		//Starts writing setpt sweep values out to the DAC and counting off how many cycles to wait till the incomming adc data is valid
		lock_start_write: begin
			
			update_setpt();
			
			//If we're about to start receiving valid data, move on to recording it
			if(!wait_cnt) begin
				state <= lock_continue_write;
				wait_cnt <= num_avgs;
			end
			wait_cnt <= wait_cnt - 1;
		
		end
		
		lock_continue_write: begin
		
			update_setpt();
			collect_average();
			
			//If we need to write the last setpt
			if(num_pts_cnt > ((1<<(num_pts+1))+1)) begin
				setpt_h <= setpt_out;
			end
			
			//If we're done collecting points and collecting the end bit too
			if(num_pts_cnt >= ((1<<(num_pts+1))+1)+wait_cnt_in) begin
				//Figure out if we had a successful lock and cleanup
				lock_state <= lock_cleanup;
			end
			
		end
		
		lock_cleanup: begin
	
			//If the lock was successful:
			if(setpt_max > setpt_l + max_pos_tol && setpt_max < setpt_h - max_pos_tol) begin
				lock_done <= 1;
				setpt_out <= setpt_max;
				setpt_int <= setpt_max;
				exp_val_int <= exp_val_max;
				num_pts <= 0;//Reset number of points to collect
			end
			else begin
				lock_done <= 0;
			end
		
			lock_state <= lock_idle;
		end
	
	
	endcase

end
endtask





always @ (posedge clk or negedge rst) begin
	if(!rst) begin
		reset_reg();
	end
	else begin
	
		if(!trig_lock) begin
			reset_reg();
			setpt_int <= setpt_in;//Update the internal setpoint with the initial setpoint while we're waiting
			exp_val_int <= exp_val_in;
		end
		else begin
	
			case(state)
			
			state_idle: begin
			
				//If we're supposed to be locking and are out of tolerance
				if(lock_sig_active_int && int_abs(exp_val_int-lock_sig_val) > tol_in) begin
					//If it's better than expected, update the expectation
					if(lock_sig_val>exp_val_int) begin
						exp_val_int <= lock_sig_val;
					end
					//If it's worse then try to lock again
					else begin
						lock_done <= 0;
						wait_cnt <= wait_cnt_in;
						state <= state_run_lock;
					end
				
				end
			
			end
			
			//state_wait_lock: begin//Don't actually need this state, the waiting is done elsewhere
			//	if(!wait_cnt) begin
			//		state <= state_run_lock;
			//	end
			//	wait_cnt <= wait_cnt - 1;
			//end
			
			state_run_lock: begin
				if(lock_done) begin
					//Go back to idle
					state <= state_idle;
				end
				run_lock_fsm();
			end
			
			
			default begin
				reset_reg();
			end
			
			endcase
		end//if trigger lock
	end
end



endmodule