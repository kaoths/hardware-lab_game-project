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
	
	wire[23:0] tclk;
    assign tclk[0] = clk;
    //Clock Divide
    genvar c;
    generate for(c=0; c<23; c=c+1) begin
        clkDiv fdiv(tclk[c+1], tclk[c]);
    end endgenerate

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
    localparam SKILL_CHECK_PHASE    = 2; // press space, more accurate = more damage
    localparam SELECT_MONSTER_PHASE = 3; // select monster to attack
    localparam EVADE_PHASE          = 4; // evade bullet for 5 secs
    
    localparam GAME_END_VICTORY     = 6; // player wins
    localparam GAME_END_DEFEATED    = 7; // player dies
    // others
    localparam MAX_DAMAGE = 80;
    localparam BULLET_DAMAGE = 40;
    // colors
    localparam RED = 12'hF00;
    localparam GREEN = 12'h0F0;
    localparam BLUE = 12'h00F;
    localparam CYAN = 12'h0FF;
    localparam MAGENTA = 12'hF0F;
    localparam YELLOW = 12'hFF0;
    localparam BLACK = 12'h000;
    localparam WHITE = 12'hFFF;
    //------------------------------------------------
    
    reg [2:0] state = 0;
    reg [9:0] cx = 320;
    reg [9:0] cy = 140;
    reg [9:0] player_hp = 200;
    reg [9:0] attack_damage = 80;
    
    // monster regs
    reg [9:0] m1_x = 240, m1_y = 60;
    reg [9:0] m2_x = 400, m2_y = 150;
    reg [9:0] m1_vy = 2;
    reg [9:0] m2_vx = 2, m2_vy = 2;
    reg [9:0] m1_hp = 200, m2_hp = 200;
    reg draw_m1 = 1, draw_m2 = 1;
    reg m1_hit = 0, m2_hit = 0;
    reg selected_monster = 0;
    
    // skill check regs
    reg [9:0] target_bar_x = 450, target_bar_y = 250; // point at top-left corner
    reg [9:0] moving_bar_x = 0, moving_bar_y = 280;
    reg [3:0] moving_bar_vx = 10;
    wire [9:0] damage_penalty;
    absolute_value skill_check_error(moving_bar_x,target_bar_x,damage_penalty,clk);   	
	reg [6:0] count = 0;
	
	// register for Basys 3 12-bit RGB DAC 
	reg [11:0] rgb_reg;
	reg reset = 0;
	wire [9:0] x, y;

	// video status output from vga_sync to tell when to route out rgb signal to DAC
	wire video_on;
    wire p_tick;
	// instantiate vga_sync
	vga_sync vga_sync_unit (.clk(clk), .reset(reset), .hsync(hsync), .vsync(vsync), .video_on(video_on), .p_tick(p_tick), .x(x), .y(y));

    // for actions only !!! --> put movement logics at vsync
	always @(posedge clk) begin
	    case(state)
	       MAIN_SCREEN: begin
	           if (action == SPACE) begin
	               state = ACTION_PHASE;
	           end
	       end
	       
	       ACTION_PHASE: begin
	           if (action == SPACE) state = SKILL_CHECK_PHASE;
	       end
	       
	       SKILL_CHECK_PHASE: 
	       begin
	        if (action == SPACE) begin
	           if ( damage_penalty < MAX_DAMAGE )
	               attack_damage = MAX_DAMAGE - damage_penalty;
	           else
	               attack_damage = 0;
	           state = SELECT_MONSTER_PHASE;
	        end
	       end
	       
	       SELECT_MONSTER_PHASE: begin
	           if (action == LEFT && m1_hp > 0 || m2_hp == 0) selected_monster = 0;
	           if (action == RIGHT && m2_hp > 0 || m1_hp == 0) selected_monster = 1;
	           if (action == SPACE) begin
	               if (selected_monster == 0) begin
	                   if(m1_hp > attack_damage) m1_hp = m1_hp - attack_damage;
	                   else m1_hp = 0;
	               end
	               if (selected_monster == 1) begin
	                   if(m2_hp > attack_damage) m2_hp = m2_hp - attack_damage;
	                   else m2_hp = 0;
	               end
	               if( m1_hp == 0 && m2_hp == 0) state = GAME_END_VICTORY; // all monster died
	               else begin
	                   draw_m1 = 1; draw_m2 = 1;
	                   state = EVADE_PHASE;
	               end
	           end
	       end
	       
	       EVADE_PHASE: 
	       begin
	           if (player_hp == 0) state = GAME_END_DEFEATED;
	           if (action == UP && cy > 40 + RADIUS + 3) cy = cy - 3; //W
	           if (action == LEFT && cx > 220 + RADIUS + 3) cx = cx - 3; //A
	           if (action == DOWN && cy < 240 - RADIUS - 3) cy = cy + 3; //S
	           if (action == RIGHT && cx < 420 - RADIUS - 3) cx = cx + 3; //D
	           //if (action == SPACE) state = ACTION_PHASE; // This should be auto after 5 secs, not pressing space
	           if (count == 65) state  = ACTION_PHASE;
	           if (m1_hit == 1) begin
	               draw_m1 = 0;
	           end
	           if (m2_hit == 1) begin
	               draw_m2 = 0;
	           end
	           
	       end
	    endcase
	end
	//640x480
	Pixel_On_Text2 #(.displayText("Duay Kao Duay Kang Orm Moo Kra TaH Group")) t0(
                                clk,
                                170, // text position.x (top left)
                                150, // text position.y (top left)
                                x, // current position.x
                                y, // current position.y
                                gname  // result, 1 if current pixel is on text, 0 otherwise
    );
	Pixel_On_Text2 #(.displayText("Niti Assavaplakorn        6031031221")) t1(
                                clk,
                                190, // text position.x (top left)
                                250, // text position.y (top left)
                                x, // current position.x
                                y, // current position.y
                                name1  // result, 1 if current pixel is on text, 0 otherwise
    );
    Pixel_On_Text2 #(.displayText("Tanawit Kritwongwiman     6031021021")) t2(
                                clk,
                                190, // text position.x (top left)
                                300, // text position.y (top left)
                                x, // current position.x
                                y, // current position.y
                                name2  // result, 1 if current pixel is on text, 0 otherwise
    );
    Pixel_On_Text2 #(.displayText("Natchapol Srisang         6031308121")) t3(
                                clk,
                                190, // text position.x (top left)
                                350, // text position.y (top left)
                                x, // current position.x
                                y, // current position.y
                                name3  // result, 1 if current pixel is on text, 0 otherwise
    );
    Pixel_On_Text2 #(.displayText("Thanadol Rungjitwaranon   6031018121")) t4(
                                clk,
                                190, // text position.x (top left)
                                400, // text position.y (top left)
                                x, // current position.x
                                y, // current position.y
                                name4  // result, 1 if current pixel is on text, 0 otherwise
    );
    Pixel_On_Text2 #(.displayText("Press ['space'] to fight.")) t5(
                                clk,
                                230, // text position.x (top left)
                                440, // text position.y (top left)
                                x, // current position.x
                                y, // current position.y
                                text_act  // result, 1 if current pixel is on text, 0 otherwise
    );
    Pixel_On_Text2 #(.displayText("Press ['space'] to skill check.")) t6(
                                clk,
                                200, // text position.x (top left)
                                440, // text position.y (top left)
                                x, // current position.x
                                y, // current position.y
                                text_skill  // result, 1 if current pixel is on text, 0 otherwise
    );
    Pixel_On_Text2 #(.displayText("Select monster to attack with ['A'] or ['D'] then press ['space'].")) t7(
                                clk,
                                50, // text position.x (top left)
                                440, // text position.y (top left)
                                x, // current position.x
                                y, // current position.y
                                text_select  // result, 1 if current pixel is on text, 0 otherwise
    );
    Pixel_On_Text2 #(.displayText("FIGHT")) t8(
                                clk,
                                30, // text position.x (top left)
                                400, // text position.y (top left)
                                x, // current position.x
                                y, // current position.y
                                text_fight  // result, 1 if current pixel is on text, 0 otherwise
    );Pixel_On_Text2 #(.displayText("Green           Cyan")) t9(
                                clk,
                                30, // text position.x (top left)
                                400, // text position.y (top left)
                                x, // current position.x
                                y, // current position.y
                                text_green_cyan  // result, 1 if current pixel is on text, 0 otherwise
    );
    Pixel_On_Text2 #(.displayText("You Won.")) t10(
                                clk,
                                300, // text position.x (top left)
                                150, // text position.y (top left)
                                x, // current position.x
                                y, // current position.y
                                text_won  // result, 1 if current pixel is on text, 0 otherwise
    );
    Pixel_On_Text2 #(.displayText("You Lose.")) t11(
                                clk,
                                300, // text position.x (top left)
                                150, // text position.y (top left)
                                x, // current position.x
                                y, // current position.y
                                text_lose // result, 1 if current pixel is on text, 0 otherwise
    );
    
	// for game rendering
	always @(posedge p_tick) begin
	    // Default Background
	    rgb_reg = BLACK;
	    // to render objects override background color
	    
	    // HP always show
	    if ( y >= 315 && y <= 335 && x <= m1_hp )
	       rgb_reg = GREEN;
	    if ( y >= 340 && y <= 360 && x <= m2_hp )
	       rgb_reg = CYAN;
	    if ( y >= 365 && y <= 385 && x <= player_hp )
	       rgb_reg = RED;
	    
	    case(state)
	       MAIN_SCREEN:
	           begin
	               if (gname||name1||name2||name3||name4) rgb_reg = BLACK;
	               else rgb_reg = WHITE;	               
	           end
	       ACTION_PHASE:
	           begin
	               if (text_act || text_fight) rgb_reg = WHITE;
	               if ( (x - 15)**2 + (y - 405)**2 <= 100 ) rgb_reg = RED;
	           end
	       EVADE_PHASE:
	           begin
	           // Player
	           if ( (x - cx)**2 + (y - cy)**2 <= RADIUS**2 )
	               rgb_reg = RED;
	           // Playbox
	           if ( (x == 220 || x == 420) && ( y >= 40 && y <= 240 ) )
	               rgb_reg = WHITE;
	           if ( (y == 40 || y == 240) && ( x >= 220 && x <= 420 ) )
	               rgb_reg = WHITE;
	           // monster 1 bullet (square shape)
	           if ( draw_m1 == 1 && m1_hp > 0 &&
	                x >= m1_x - 3 && x <= m1_x + 3 && 
	                y >= m1_y - 3 && y <= m1_y + 3 )
	               rgb_reg = GREEN;
	           // monster 2 bullet (circle shape)
	           if ( draw_m2 == 1 && m2_hp > 0 &&
	               (x - m2_x)**2 + (y - m2_y)**2 <= 4**2 )
	               rgb_reg = CYAN;
	           end
	       SKILL_CHECK_PHASE:
	           begin
	           if ( x >= target_bar_x && x <= target_bar_x + 5 &&
	                y >= target_bar_y && y <= target_bar_y + 30 )
	                rgb_reg = YELLOW;
	           if ( x >= moving_bar_x && x <= moving_bar_x + 10 &&
	                y >= moving_bar_y && y <= moving_bar_y + 30 )
	                rgb_reg = WHITE;
	           if (text_skill) rgb_reg = WHITE;
	           end
	       SELECT_MONSTER_PHASE:
	           begin
	               if (text_select || text_green_cyan) rgb_reg = WHITE;
	               if ( selected_monster == 0 && (x - 15)**2 + (y - 405)**2 <= 100 ) rgb_reg = RED;
	               if ( selected_monster == 1 && (x - 140)**2 + (y - 405)**2 <= 100 ) rgb_reg = RED;
	           end
	       GAME_END_VICTORY: 
	           begin
	               if (text_won) rgb_reg = WHITE;
	           end
	       GAME_END_DEFEATED: 
	           begin
	               if (text_lose) rgb_reg = WHITE;
	           end
	    endcase
	   
	end
	
	// for game updating, logics here
	always @(posedge vsync) begin
	   case(state)
	       EVADE_PHASE:
	           begin
	           // monster 1 movement
	           if (m1_y >= 240 - 3 || m1_y <= 40 + 3) m1_vy = -m1_vy;
	           m1_y = m1_y + m1_vy;
	           // monster 2 movement
	           if (m2_x >= 420 - 4 || m2_x <= 220 + 4) m2_vx = -m2_vx;
	           if (m2_y >= 240 - 4 || m2_y <= 40 + 4) m2_vy = -m2_vy;
	           m2_x = m2_x + m2_vx;
	           m2_y = m2_y + m2_vy;
	           // check for collision
	           // collide with square bullet
	           if ( draw_m1 == 1 && (cx - m1_x)**2 + (cy - m1_y)**2 < (RADIUS + 3)**2 ) begin
	               m1_hit = 1;
	               if (player_hp > BULLET_DAMAGE) player_hp = player_hp - BULLET_DAMAGE;
	               else player_hp = 0;
	               end
	           // collide with circle bullet
	           if ( draw_m2 == 1 && (cx - m2_x)**2 + (cy - m2_y)**2 < (RADIUS + 4)**2 ) begin
	               m2_hit = 1;
	               if (player_hp > BULLET_DAMAGE) player_hp = player_hp - BULLET_DAMAGE;
	               else player_hp = 0;
	               end
	           if (draw_m1 == 0) m1_hit = 0;
	           if (draw_m2 == 0) m2_hit = 0;
	           end
	       SKILL_CHECK_PHASE:
	       begin
	           if ( moving_bar_x >= 630 ) moving_bar_x = 0;
	           moving_bar_x = moving_bar_x + moving_bar_vx;
	       end
	   endcase
	   
	end
	assign rgb = (video_on) ? rgb_reg : 12'b0;
	
	always @(posedge tclk[23]) begin
	   if(state == EVADE_PHASE) begin
	       count = count+1;
	   end
	   else count = 0;
	end
endmodule


