`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/28/2026 06:31:44 PM
// Design Name: 
// Module Name: shiftrow
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


module shiftrow(
 input  [127:0] in,
    output [127:0] out
);

    
    wire [7:0] s0  = in[127:120];
    wire [7:0] s1  = in[119:112];
    wire [7:0] s2  = in[111:104];
    wire [7:0] s3  = in[103:96];

    wire [7:0] s4  = in[95:88];
    wire [7:0] s5  = in[87:80];
    wire [7:0] s6  = in[79:72];
    wire [7:0] s7  = in[71:64];

    wire [7:0] s8  = in[63:56];
    wire [7:0] s9  = in[55:48];
    wire [7:0] s10 = in[47:40];
    wire [7:0] s11 = in[39:32];

    wire [7:0] s12 = in[31:24];
    wire [7:0] s13 = in[23:16];
    wire [7:0] s14 = in[15:8];
    wire [7:0] s15 = in[7:0];

   
    assign out = {
       
        s0,   s5,   s10,  s15,
       
        s4,   s9,   s14,  s3,
       
        s8,   s13,  s2,   s7,
       
        s12,  s1,   s6,   s11
    };

endmodule
