`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/26/2020 04:40:32 PM
// Design Name: 
// Module Name: absolute_value
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


module absolute_value(
    input [9:0] A,
    input [9:0] B,
    output reg [9:0] S,
    input clk
    );
always @(posedge clk)
begin
    if (A >= B) S = A - B;
    else S = B - A;
end
endmodule
