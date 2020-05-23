`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/31/2019 03:09:33 PM
// Design Name: 
// Module Name: system
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
module system(
    output wire RsTx,
    input wire RsRx,
    output wire [3:0]vgaRed, vgaGreen, vgaBlue,
    output wire Hsync, Vsync,
    input reset, //btnC
    input clk
    );
wire [3:0] action;
vga_test vga(
    .clk(clk),
    .action(action),
    .hsync(Hsync),
    .vsync(Vsync),
    .rgb({vgaRed, vgaGreen, vgaBlue})
);

wire TX;
//wire transmit;
assign RsTx = TX;
uart_echo uartEcho (/*AUTOARG*/
   // Outputs
   TX, action,
   // Inputs
   clk, reset, RsRx
   ) ;
//top_uart u(
//    .RsTx(RsTx),
//    .RsRx(RsRx),
//    .led(led),
//    .clk(clk)
//    );
endmodule
