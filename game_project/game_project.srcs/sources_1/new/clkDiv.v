`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/27/2020 11:51:20 PM
// Design Name: 
// Module Name: clkDiv
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


module clkDiv(
    output clkDiv,
    input clk
    );
    
    reg clkDiv;
    
    initial begin
        clkDiv = 0;
    end
    
    always @(posedge clk) begin
        clkDiv = ~clkDiv;
    end
endmodule