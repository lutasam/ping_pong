module vga_controller(iRST_n,
                      iVGA_CLK,
                      oBLANK_n,
                      oHS,
                      oVS,
                      b_data,
                      g_data,
                      r_data,
							 up_1,
							 down_1,
							 up_2,
							 down_2);

	
input iRST_n;
input iVGA_CLK;
output reg oBLANK_n;
output reg oHS;
output reg oVS;
output [7:0] b_data;
output [7:0] g_data;  
output [7:0] r_data;                        
///////// ////                     
reg [18:0] ADDR;
reg [23:0] bgr_data;
wire VGA_CLK_n;
wire [7:0] index;
wire [23:0] bgr_data_raw;
wire cBLANK_n,cHS,cVS,rst;
////
assign rst = ~iRST_n;

input up_1, down_1, up_2, down_2;

wire [9:0] curr_x, curr_y;

converter cv(ADDR, curr_x, curr_y);

video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
                              .reset(rst),
                              .blank_n(cBLANK_n),
                              .HS(cHS),
                              .VS(cVS));
////
////Addresss generator
always@(posedge iVGA_CLK,negedge iRST_n)
begin
  if (!iRST_n)
     ADDR<=19'd0;
  else if (cHS==1'b0 && cVS==1'b0)
     ADDR<=19'd0;
  else if (cBLANK_n==1'b1)
     ADDR<=ADDR+1;
end
//////////////////////////
//////INDEX addr.
assign VGA_CLK_n = ~iVGA_CLK;
img_data	img_data_inst (
	.address ( ADDR ),
	.clock ( VGA_CLK_n ),
	.q ( index )
	);
	
/////////////////////////
//////Add switch-input logic here
	
//////Color table output
img_index	img_index_inst (
	.address ( index ),
	.clock ( iVGA_CLK ),
	.q ( bgr_data_raw)
	);	
//////
//////latch valid data at falling edge;
// curr_x is the row, curr_y is the column
always@(posedge VGA_CLK_n) begin // change here, it decides which color of the pixel is
	if (8 <= curr_y && curr_y <= 10 && curr_x < x1 + 30 && curr_x > x1 - 30 || // left line
		 628 <= curr_y && curr_y <= 630 && curr_x < x2 + 30 && curr_x > x2 - 30 || // right line
		 (curr_x - x_ball)*(curr_x - x_ball) + (curr_y - y_ball)*(curr_y - y_ball) <= 10) begin // ball (still need to add the score of both side of the player)
		 bgr_data <= 24'hFFFFFF;
	end
	else begin
		bgr_data <= bgr_data_raw;
	end
end
// #############################################

assign b_data = bgr_data[23:16];
assign g_data = bgr_data[15:8];
assign r_data = bgr_data[7:0]; 
///////////////////
//////Delay the iHD, iVD,iDEN for one clock cycle;
always@(negedge iVGA_CLK)
begin
  oHS<=cHS;
  oVS<=cVS;
  oBLANK_n<=cBLANK_n;
end


// counters, used to control the speed of the objects
reg[31:0] count1, count2, count3;
initial count1 = 1;
initial count2 = 0;
initial count3 = 0;


// game score register
reg[2:0] left_score, right_score;
initial begin
	left_score = 0;
	right_score = 0;
end

// control the lines
// ############################################
reg[9:0] x1, x2; // the middle point of the line
reg[9:0] x1_towards_up, x2_towards_up; // the direction of the line, 0 not move, 1 positive direction, 2 negative direction
reg[9:0] x_ball, y_ball; // the x, y value of the ball
reg[9:0] towards_right, towards_up; // the direction of the ball, 0 not move, 1 positive direction, 2 negative direction

initial
begin
	x1 = 10'd240;
	x2 = 10'd240;
	x1_towards_up = 10'd0;
	x2_towards_up = 10'd0;
end

always @(posedge iVGA_CLK)  begin
	if (count1% 32'd60000 == 0) begin
		if (up_1 == 1'b1) begin
			if (x1 >= 35) begin
				x1 = x1 - 10'd1;
				x1_towards_up = 10'd1;
			end
		end
		else if (down_1 == 1'b1) begin
			if (x1 < 460) begin
				x1 = x1 + 10'd1;
				x1_towards_up = 10'd2;
			end
		end
		else begin
			x1_towards_up = 10'd0;
		end
	end
	count1 <= count1 + 1;
end

always @(posedge iVGA_CLK)  begin
	if (count3% 32'd60000 == 0) begin
		if (up_2 == 1'b1) begin
			if (x2 >= 35) begin
				x2 = x2 - 10'd1;
				x2_towards_up = 10'd1;
			end
		end
		else if (down_2 == 1'b1) begin
			if (x2 < 460) begin
				x2 = x2 + 10'd1;
				x2_towards_up = 10'd2;
			end
		end	
		else begin
			x2_towards_up = 10'd0;
		end
	end
	count3 <= count3 + 1;
end
// ############################################


// control the ball
// ############################################
initial
begin
	x_ball = 10'd240;
	y_ball = 10'd320;
	towards_right = 10'd2;
	towards_up = 10'd0;
end

// too fast, divide the clock to slow it down!!
always @(posedge iVGA_CLK)  begin
	if (count2% 32'd100000 == 0) begin
	// have some error here!
		// judge whether the ball collides on one of the line
		if (8 <= y_ball && y_ball <= 10 && x_ball <= x1 + 30 && x_ball >= x1 - 30) begin // attach to left line
			 if (towards_right == 10'd1) begin // change the direction
				towards_right = 10'd2;
				y_ball = y_ball - 1;
			 end
			 else begin
				towards_right = 10'd1;
				y_ball = y_ball + 1;
			 end
			 
			 if (x1_towards_up == 10'd0) begin // not move
			 // pass, no need to change vertical direction
//				 if (towards_up == 10'd1) begin
//					towards_up = 10'd1;
//				 end
//				 else begin
//					towards_up = 10'd2;
//				 end
			 end
			 else if (x1_towards_up == 10'd2) begin // move down
				towards_up = 10'd2;
			 end
			 else begin // move up
				towards_up = 10'd1;
			 end
		end
		else if (628 <= y_ball && y_ball <= 630 && x_ball <= x2 + 30 && x_ball >= x2 - 30) begin // attach to right line
			 if (towards_right == 10'd1) begin // change the direction
				towards_right = 10'd2;
				y_ball = y_ball - 1;
			 end
			 else begin
				towards_right = 10'd1;
				y_ball = y_ball + 1;
			 end
			 
			 if (x2_towards_up == 10'd0) begin // not move
				// pass, no need to change vertical direction
//				 if (towards_up == 10'd1) begin
//					towards_up = 10'd1;
//				 end
//				 else begin
//					towards_up = 10'd2;
//				 end
			 end
			 else if (x2_towards_up == 10'd2) begin // move down
				towards_up = 10'd2;
			 end
			 else begin // move up
				towards_up = 10'd1;
			 end
		end
		else if (x_ball == 0 || x_ball == 479) begin // attach to bottom or top
			if (towards_up == 10'd1) begin
				towards_up = 10'd2;
			 end
			 else begin
				towards_up = 10'd1;
			 end
		end
		else if (y_ball == 0) begin // attach to left side
			// right player gets one point, init the ball
			x_ball = 10'd240;
			y_ball = 10'd320;
			towards_right = 10'd2;
			towards_up = 10'd0;
			
			right_score = right_score + 1;
		end
		else if (y_ball == 639) begin // attach to right side
			// left player gets one point, init the ball
			x_ball = 10'd240;
			y_ball = 10'd320;
			towards_right = 10'd1;
			towards_up = 10'd0;
			
			
			left_score = left_score + 1;
		end
		
		
		// move the ball
		if (towards_up == 10'd0 && towards_right == 10'd1) begin
			y_ball = y_ball + 10'd1;
		end
		else if (towards_up == 10'd0 && towards_right == 10'd2) begin
			y_ball = y_ball - 10'd1;
		end
		else if (towards_up == 10'd1 && towards_right == 10'd1) begin
			y_ball = y_ball + 10'd1;
			x_ball = x_ball - 10'd1;
		end
		else if (towards_up == 10'd1 && towards_right == 10'd2) begin
			y_ball = y_ball - 10'd1;
			x_ball = x_ball - 10'd1;
		end
		else if (towards_up == 10'd2 && towards_right == 10'd1) begin
			y_ball = y_ball + 10'd1;
			x_ball = x_ball + 10'd1;
		end
		else if (towards_up == 10'd2 && towards_right == 10'd2) begin
			y_ball = y_ball - 10'd1;
			x_ball = x_ball + 10'd1;
		end
	end
	count2 = count2 + 1;
end

// ############################################

endmodule