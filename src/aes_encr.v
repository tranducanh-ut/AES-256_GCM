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
    input  [127:0] in,    // AES luôn xử lý khối 128-bit
    input  [255:0] key,   // Khóa 256-bit cho AES-256
    output [127:0] out    // Đầu ra 128-bit
);

    // 1) Sinh round keys (AES-256 cần 15 keys x 128-bit = 1920 bits)
    wire [1919:0] roundKeys;

    keyexpan ke (
        .key(key),
        .roundKeys(roundKeys)
    );

    // 2) State qua các round (0 đến 14)
    wire [127:0] state [0:14];

    // 3) Initial AddRoundKey (Round 0)
    addroundkey ark0 (
        .data(in),
        .key (roundKeys[1919 -: 128]), // Lấy 128-bit đầu tiên (K0)
        .out (state[0])
    );

    // 4) Round 1 -> 13 (Vòng lặp có MixColumns)
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

    // 5) Final Round (Vòng 14: NO MixColumns)
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

    // 6) Output
    assign out = state[14];
endmodule
