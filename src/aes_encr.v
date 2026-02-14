`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/28/2026 10:03:53 PM
// Design Name: 
// Module Name: aes_encr
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


module aes_encr(
 input wire rst,
    input  [127:0] in,    
    input  [255:0] key,   
    output [127:0] out    
);

    //   15 keys x 128-bit = 1920 bits
    wire [1919:0] roundKeys;

    keyexpan ke (
        .key(key),
        .roundKeys(roundKeys)
    );

   
    wire [127:0] state [0:14];

    
    addroundkey ark0 (
        .data(in),
        .key (roundKeys[1919 -: 128]), // Lấy 128-bit đầu tiên 
        .out (state[0])
    );

  
    genvar i;
    generate
        for (i = 1; i < 14; i = i + 1) begin : ROUND_LOOP
            encryptRound r (
                .in  (state[i-1]),
                .key (roundKeys[1919 - 128*i -: 128]),
                .out (state[i])
            );
        end
    endgenerate

   // vongf14 ko có mixcol
    wire [127:0] sb_out;
    wire [127:0] sr_out;

    subbyte sb (
        .in (state[13]),
        .out(sb_out)
    );

    shiftrow sr (
        .in (sb_out),
        .out(sr_out)
    );

    addroundkey ark14 (
        .data(sr_out),
        .key (roundKeys[127:0]), // Lấy 128-bit cuối cùng (K14)
        .out (state[14])
    );

   
    assign out = state[14];
endmodule
