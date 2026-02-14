`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/28/2026 08:01:49 PM
// Design Name: 
// Module Name: mixcol
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


module mixcol(
input  [127:0] in,
    output [127:0] out
);

   

    
    function [7:0] mb2;
        input [7:0] x;
        begin
            mb2 = (x[7] == 1'b1) ? ((x << 1) ^ 8'h1b) : (x << 1);
        end
    endfunction

    // multiply by 3 = (x * 2) xor x
    function [7:0] mb3;
        input [7:0] x;
        begin
            mb3 = mb2(x) ^ x;
        end
    endfunction

    

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

    
    // Column 0
    wire [7:0] m0  = mb2(s0)  ^ mb3(s1) ^ s2       ^ s3;
    wire [7:0] m1  = s0       ^ mb2(s1) ^ mb3(s2) ^ s3;
    wire [7:0] m2  = s0       ^ s1       ^ mb2(s2) ^ mb3(s3);
    wire [7:0] m3  = mb3(s0) ^ s1       ^ s2       ^ mb2(s3);

    // Column 1
    wire [7:0] m4  = mb2(s4)  ^ mb3(s5) ^ s6       ^ s7;
    wire [7:0] m5  = s4       ^ mb2(s5) ^ mb3(s6) ^ s7;
    wire [7:0] m6  = s4       ^ s5       ^ mb2(s6) ^ mb3(s7);
    wire [7:0] m7  = mb3(s4) ^ s5       ^ s6       ^ mb2(s7);

    // Column 2
    wire [7:0] m8  = mb2(s8)  ^ mb3(s9) ^ s10      ^ s11;
    wire [7:0] m9  = s8       ^ mb2(s9) ^ mb3(s10) ^ s11;
    wire [7:0] m10 = s8       ^ s9       ^ mb2(s10) ^ mb3(s11);
    wire [7:0] m11 = mb3(s8) ^ s9       ^ s10      ^ mb2(s11);

    // Column 3
    wire [7:0] m12 = mb2(s12) ^ mb3(s13) ^ s14      ^ s15;
    wire [7:0] m13 = s12      ^ mb2(s13) ^ mb3(s14) ^ s15;
    wire [7:0] m14 = s12      ^ s13      ^ mb2(s14) ^ mb3(s15);
    wire [7:0] m15 = mb3(s12)^ s13      ^ s14      ^ mb2(s15);

    

    assign out = {
        m0,  m1,  m2,  m3,
        m4,  m5,  m6,  m7,
        m8,  m9,  m10, m11,
        m12, m13, m14, m15
    };

endmodule
