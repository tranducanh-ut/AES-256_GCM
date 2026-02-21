`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/28/2026 06:34:25 PM
// Design Name: 
// Module Name: subbyte
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


module subbyte(
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

   
    wire [7:0] sb0, sb1, sb2, sb3;
    wire [7:0] sb4, sb5, sb6, sb7;
    wire [7:0] sb8, sb9, sb10, sb11;
    wire [7:0] sb12, sb13, sb14, sb15;

   
    sbox S0  (s0,  sb0);
    sbox S1  (s1,  sb1);
    sbox S2  (s2,  sb2);
    sbox S3  (s3,  sb3);

    sbox S4  (s4,  sb4);
    sbox S5  (s5,  sb5);
    sbox S6  (s6,  sb6);
    sbox S7  (s7,  sb7);

    sbox S8  (s8,  sb8);
    sbox S9  (s9,  sb9);
    sbox S10 (s10, sb10);
    sbox S11 (s11, sb11);

    sbox S12 (s12, sb12);
    sbox S13 (s13, sb13);
    sbox S14 (s14, sb14);
    sbox S15 (s15, sb15);

   
    assign out = {
        sb0,  sb1,  sb2,  sb3,
        sb4,  sb5,  sb6,  sb7,
        sb8,  sb9,  sb10, sb11,
        sb12, sb13, sb14, sb15
    };
endmodule
