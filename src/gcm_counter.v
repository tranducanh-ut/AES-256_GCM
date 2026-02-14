`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2026 10:36:54 PM
// Design Name: 
// Module Name: gcm_counter
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


module gcm_counter(
input clk, rst,
    input load,
    input [95:0] nonce,
    input en,
    output [127:0] count_out
);
    reg [31:0] cb;
    always @(posedge clk or posedge rst) begin
        if (rst) cb <= 32'd2;
        else if (load) cb <= 32'd2;
        else if (en) cb <= cb + 1;
    end
    assign count_out = {nonce, cb};
endmodule
