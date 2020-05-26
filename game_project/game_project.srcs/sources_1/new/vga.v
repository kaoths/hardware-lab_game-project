`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/31/2019 03:31:32 PM
// Design Name: 
// Module Name: vga
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module vga_sync
	(
		input wire clk, reset,
		output wire hsync, vsync, video_on, p_tick,
		output wire [9:0] x, y
	);
	
	// constant declarations for VGA sync parameters
	localparam H_DISPLAY       = 640; // horizontal display area
	localparam H_L_BORDER      =  48; // horizontal left border
	localparam H_R_BORDER      =  16; // horizontal right border
	localparam H_RETRACE       =  96; // horizontal retrace
	localparam H_MAX           = H_DISPLAY + H_L_BORDER + H_R_BORDER + H_RETRACE - 1;
	localparam START_H_RETRACE = H_DISPLAY + H_R_BORDER;
	localparam END_H_RETRACE   = H_DISPLAY + H_R_BORDER + H_RETRACE - 1;
	
	localparam V_DISPLAY       = 480; // vertical display area
	localparam V_T_BORDER      =  10; // vertical top border
	localparam V_B_BORDER      =  33; // vertical bottom border
	localparam V_RETRACE       =   2; // vertical retrace
	localparam V_MAX           = V_DISPLAY + V_T_BORDER + V_B_BORDER + V_RETRACE - 1;
        localparam START_V_RETRACE = V_DISPLAY + V_B_BORDER;
	localparam END_V_RETRACE   = V_DISPLAY + V_B_BORDER + V_RETRACE - 1;
	
	// mod-4 counter to generate 25 MHz pixel tick
	reg [1:0] pixel_reg;
	wire [1:0] pixel_next;
	wire pixel_tick;
	
	always @(posedge clk, posedge reset)
		if(reset)
		  pixel_reg <= 0;
		else
		  pixel_reg <= pixel_next;
	
	assign pixel_next = pixel_reg + 1; // increment pixel_reg 
	
	assign pixel_tick = (pixel_reg == 0); // assert tick 1/4 of the time
	
	// registers to keep track of current pixel location
	reg [9:0] h_count_reg, h_count_next, v_count_reg, v_count_next;
	
	// register to keep track of vsync and hsync signal states
	reg vsync_reg, hsync_reg;
	wire vsync_next, hsync_next;
 
	// infer registers
	always @(posedge clk, posedge reset)
		if(reset)
		    begin
                    v_count_reg <= 0;
                    h_count_reg <= 0;
                    vsync_reg   <= 0;
                    hsync_reg   <= 0;
		    end
		else
		    begin
                    v_count_reg <= v_count_next;
                    h_count_reg <= h_count_next;
                    vsync_reg   <= vsync_next;
                    hsync_reg   <= hsync_next;
		    end
			
	// next-state logic of horizontal vertical sync counters
	always @*
		begin
		h_count_next = pixel_tick ? 
		               h_count_reg == H_MAX ? 0 : h_count_reg + 1
			       : h_count_reg;
		
		v_count_next = pixel_tick && h_count_reg == H_MAX ? 
		               (v_count_reg == V_MAX ? 0 : v_count_reg + 1) 
			       : v_count_reg;
		end
		
        // hsync and vsync are active low signals
        // hsync signal asserted during horizontal retrace
        assign hsync_next = h_count_reg >= START_H_RETRACE
                            && h_count_reg <= END_H_RETRACE;
   
        // vsync signal asserted during vertical retrace
        assign vsync_next = v_count_reg >= START_V_RETRACE 
                            && v_count_reg <= END_V_RETRACE;

        // video only on when pixels are in both horizontal and vertical display region
        assign video_on = (h_count_reg < H_DISPLAY) 
                          && (v_count_reg < V_DISPLAY);

        // output signals
        assign hsync  = hsync_reg;
        assign vsync  = vsync_reg;
        assign x      = h_count_reg;
        assign y      = v_count_reg;
        assign p_tick = pixel_tick;
endmodule

module vga_test
	(
		input wire clk,
		input wire [3:0] action,
		output wire hsync, vsync,
		output wire [11:0] rgb
	);

	parameter WIDTH = 640;
	parameter HEIGHT = 480;
	parameter RADIUS = 10;
	
    // Local PARAMS or Static VAR (Use UPPER_SNAKE_CASE)
    // Actions
    localparam UP    = 1;
    localparam LEFT  = 2;
    localparam DOWN  = 3;
    localparam RIGHT = 4;
    localparam SPACE = 5;
    // States
    localparam MAIN_SCREEN          = 0;
    localparam ACTION_PHASE         = 1; // there is only FIGHT choice
    localparam EVADE_PHASE          = 2; // evade bullet for 5 secs
    localparam SKILL_CHECK_PHASE    = 3; // press space, more accurate = more damage
    localparam SELECT_MONSTER_PHASE = 4; // select monster to attack
    
    localparam GAME_END_VICTORY     = 6; // player wins
    localparam GAME_END_DEFEAT      = 7; // player dies
    //------------------------------------------------
    
    reg [2:0] state = 2;
    reg [9:0] cx = WIDTH/2;
    reg [9:0] cy = HEIGHT/2;
    
    //monster regs
    reg [9:0] m1_x = 240, m1_y = 160;
    reg [9:0] m2_x = 400, m2_y = 250;
    reg [9:0] m1_vx = 0, m1_vy = 2;
    reg [9:0] m2_vx = 2, m2_vy = 2;
    reg draw_m1 = 1, draw_m2 = 1;
    
	// register for Basys 3 12-bit RGB DAC 
	reg [11:0] rgb_reg;
	reg reset = 0;
	wire [9:0] x, y;

	// video status output from vga_sync to tell when to route out rgb signal to DAC
	wire video_on;
    wire p_tick;
	// instantiate vga_sync
	vga_sync vga_sync_unit (.clk(clk), .reset(reset), .hsync(hsync), .vsync(vsync), .video_on(video_on), .p_tick(p_tick), .x(x), .y(y));

    // for actions only !!! --> put other logics at vsync
	always @(posedge clk) begin
	    case(state)
	       EVADE_PHASE:
	       begin
	           if (action == UP && cy > 140 + RADIUS + 3) cy = cy - 3; //W
	           if (action == LEFT && cx > 220 + RADIUS + 3) cx = cx - 3; //A
	           if (action == DOWN && cy < 340 - RADIUS - 3) cy = cy + 3; //S
	           if (action == RIGHT && cx < 420 - RADIUS - 3) cx = cx + 3; //D
	       end
	    endcase
	end
	
	// for game rendering
	always @(posedge p_tick) begin   
	    case(state)
	       MAIN_SCREEN:
	           begin
	           end
	       ACTION_PHASE:
	           begin
	           end
	       EVADE_PHASE:
	           begin
	           // Default Background
	           rgb_reg = 12'h000;
	           // to render objects override background color
	           // Player
	           if ( (x - cx)**2 + (y - cy)**2 <= RADIUS**2 )
	               rgb_reg = 12'hF00;
	           // Playbox
	           if ( (x == 220 || x == 420) && ( y >= 140 && y <= 340 ) )
	               rgb_reg = 12'hFFF;
	           if ( (y == 140 || y == 340) && ( x >= 220 && x <= 420 ) )
	               rgb_reg = 12'hFFF;
	           // monster 1 bullet (square shape)
	           if ( draw_m1 == 1 &&
	                m1_x >= x - 3 && m1_x <= x + 3 && 
	                m1_y >= y - 3 && m1_y <= y + 3 )
	               rgb_reg = 12'h8F0;
	           // monster 2 bullet (circle shape)
	           if ( draw_m2 == 1 && (x - m2_x)**2 + (y - m2_y)**2 <= 4**2 )
	               rgb_reg = 12'h8F0;
	           end
	    endcase
	   
	end
	
	// for game updating, logics here
	always @(posedge vsync) begin
	   case(state)
	       EVADE_PHASE:
	           begin
	           // monster 1 movement
	           if (m1_y >= 340 - 3 || m1_y <= 140 + 3) m1_vy = -m1_vy;
	           m1_y = m1_y + m1_vy;
	           // monster 2 movement
	           if (m2_x >= 420 - 4 || m2_x <= 220 + 4) m2_vx = -m2_vx;
	           if (m2_y >= 340 - 4 || m2_y <= 140 + 4) m2_vy = -m2_vy;
	           m2_x = m2_x + m2_vx;
	           m2_y = m2_y + m2_vy;
	           // check for collision
	           // collide with square bullet
	           if ( (cx - m1_x)**2 + (cy - m1_y)**2 < (RADIUS + 3)**2 ) begin
	               draw_m1 = 0;
	               // damage to player
	               end
	           // collide with circle bullet
	           if ( (cx - m2_x)**2 + (cy - m2_y)**2 < (RADIUS + 4)**2 ) begin
	               draw_m2 = 0;
	               // damage to player
	               end
	           end
	   endcase
	   
	end
	assign rgb = (video_on) ? rgb_reg : 12'b0;
endmodule