import ising_config::*;


module dl
(
	input wire clk, rst, 
	input wire [31:0] gpio_in,
	
	
	input wire [255:0] adc_data_in
	
	//initial set point and expected value and tolerance, and number of averages to collect for each locking pt, and number of cycles to wait before locking
	//And how much to inc/dec the locking setpoint by
	input wire [15:0] setpt_in, exp_val_in, tol_in, num_avgs, wait_cnt_in, setpt_step,
	
	input wire lock_sig_active,//if 1, a calibration pulse is currently being read back and must be locked to
	input wire [2:0] lock_sig_pos,//Tells us which sample is the locking sample
	input wire trig_lock,//if 1, we're actively running the fsm and trying to lock
	
	output wire [15:0] setpt_out//Setpoint output of the lockbox
);


//Current locking signal value extraced from the adc sample list
wire[15:0] lock_sig_val = adc_data_in[(lock_sig_pos*8)+:16];

reg [15:0] wait_cnt;//Wait counter before doing the locking cycle

initial begin


end

task reset_reg();
begin
	state <= state_idle;
	setpt_out <= 0;
end
endtask

//Locking algorithm local variables
reg [15:0] setpt_max, exp_val_max, exp_val_int;
reg [31:0] avg_reg;
reg [15:0] sum_cnt;//Second counter for the calculate and compare portion

reg [15:0] num_pts, num_pts_cnt;//This counter is only for what to output
localparam num_pts_max = 512
task run_lock_fsm();
begin
	case(lock_state)
	
	
		lock_state_idle: begin
			if(lock_done) begin
				//do nothing
			end
			if(lock_found) begin//If the rest of the algorithm found the lock point
				//Write the new setpoint and expected value
				setpt_out <= setpt_max;
				exp_val_int <= exp_val_max;
				num_pts <= 0;//Reset number of points to collect
			end
			else begin
				num_pts <= num_pts + 1;//number of points to collect is (1 << num_pts);
				
				//If we're failing
				if(((1<<(num_pts+1))+1) > num_pts_max) begin
					fail!
				end
				
				
				state <= state_lock_start_write;
				
				//Setup the set point for the next round of data
				setpt_out <= setpt_int - (setpt_step << num_pts)
				//And the wait cycles as well
				wait_cnt <= wait_cnt_in;
				num_avgs_cnt <= 1;
				
				exp_val_max <= 0;
				setpt_max <= 0;
			end
		
		end
	
		//Starts writing setpt sweep values out to the DAC and counting off how many cycles to wait till the incomming adc data is valid
		lock_start_write: begin
			//If we have enough averages, go to the next setpt
			if(num_avgs_cnt >= num_avgs) begin
				num_avgs_cnt <= 1;
				num_pts_cnt <= num_pts_cnt + 1;
				setpt <= setpt + setpt_step;
			end
			else begin
				num_avgs_cnt <= num_avgs_cnt + 1;
			end
			
			
			//Once we're done with all that, if it's time to move on, do so
			if(!wait_cnt) begin
				state <= lock_continue_write;
				wait_cnt <= num_avgs;
			end
			wait_cnt <= wait_cnt - 1;
		
		end
		
		lock_continue_write: begin
		
			//If we have enough averages, go to the next setpt
			if(num_avgs_cnt >= num_avgs) begin
				num_avgs_cnt <= 1;
				num_pts_cnt <= num_pts_cnt + 1;
				setpt_out <= setpt_out + setpt_step;
			end
			else begin
				num_avgs_cnt <= num_avgs_cnt + 1;
			end
			
			//Average calculation and max update logic plus 
			if(sum_cnt >= num_avgs) begin
				sum_cnt <= 1;
				//Update avg reg to new value this cycle
				avg_reg <= lock_sig_val;
				//if this is a new max
				if(avg_reg[num_avgs+:16] > setpt_max)begin
					exp_val_max <= avg_reg[num_avgs+:16];
					setpt_max <= setpt_out - (setpt_step*num_avgs);
				end
					
			end
			else begin//Continue averaging
				sum_cnt <= sum_cnt + 1;
				avg_reg <= avg_reg + lock_sig_val;
			end
			
			
			
			
			//If we're done collecting points and collecting the end bit too
			if(num_pts_cnt > ((1<<(num_pts+1))+1)+wait_cnt_in) begin
				//wait for data collection to end
				lock_state <= lock_cleanup;
			end
			
			
		end
		
		lock_cleanup begin
			setpt_out <= setpt_max;
			exp_val_int <= exp_val_max;
		
			//done
			lock_state <= lock_idle;
			lock_done <= 1;
		end
	
	
	endcase

end
endtask



always @ (posedge clk or negedge rst) begin
	if(!rst) begin
	
	end
	else begin
	
		if(!trig_lock) begin
			reset_reg();
			setpt_int <= setpt_in;//Update the internal setpoint with the initial setpoint while we're waiting
			exp_val_int <= exp_val_in
		end
		else begin
	
			case(state):
			
			state_idle: begin
			
				//If we're out of tolerance
				if(int_abs(exp_val_int-lock_sig_val) > tol_in) begin
					//If it's better than expected, update the expectation
					if(lock_sig_val>exp_val_int) begin
						exp_val_int <= lock_sig_val;
					end
					//If it's worse then try to lock again
					else begin
						lock_done <= 0;
						wait_cnt <= wait_cnt_in;
						state <= state_wait_lock;
					end
				
				end
			
			end
			
			state_wait_lock: begin
				if(!wait_cnt) begin
					state <= state_run_lock;
				end
				wait_cnt <= wait_cnt - 1;
			end
			
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