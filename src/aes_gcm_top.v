`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2026 10:38:15 PM
// Design Name: 
// Module Name: aes_gcm_top
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


module aes_gcm_top(
   input clk, rst,
    input [255:0] key,
    input [95:0]  nonce,
    input [127:0] plaintext1,  // Block 1
    input [127:0] plaintext2,  // Block 2
    input [127:0] plaintext3,  // Block 3
    input [223:0] aad,         // Additional Authenticated Data (224 bits)
    output [127:0] ciphertext1,
    output [127:0] ciphertext2,
    output [127:0] ciphertext3,
    output [127:0] tag
);
    // Hash key và counter values
    wire [127:0] h_key;
    wire [127:0] ctr0, ctr1, ctr2, ctr3;
    wire [127:0] keystream1, keystream2, keystream3;
    wire [127:0] tag_mask;
    
    // GHASH pipeline - cần 5 bước
    wire [127:0] ghash_y1, ghash_y2, ghash_y3, ghash_y4, ghash_y5;
    
    // Length block: len(AAD) = 224 bits, len(Ciphertext) = 384 bits
    wire [127:0] len_block = {64'd224, 64'd384};
    
    // AAD cần được pad thành 128-bit blocks
    // AAD = 224 bits: 
    //   Block 1: bits [223:96] = 128 bits
    //   Block 2: bits [95:0]   = 96 bits + 32 bits padding
    wire [127:0] aad_block1 = aad[223:96];
    wire [127:0] aad_block2 = {aad[95:0], 32'h00000000};
    
    // 1. Tạo Hash Key H = AES_K(0^128)
    aes_encr aes_h (.in(128'b0), .key(key), .out(h_key));
    
    // 2. Tạo counter values
    // Counter bắt đầu từ 1 cho tag mask, từ 2 cho encryption
    assign ctr0 = {nonce, 32'd1};  // Y[0] cho tag mask
    assign ctr1 = {nonce, 32'd2};  // Y[1] cho plaintext block 1
    assign ctr2 = {nonce, 32'd3};  // Y[2] cho plaintext block 2
    assign ctr3 = {nonce, 32'd4};  // Y[3] cho plaintext block 3
    
    // 3. Encrypt counters để tạo keystreams
    aes_encr aes_tag_gen (.in(ctr0), .key(key), .out(tag_mask));
    aes_encr aes_ctr1 (.in(ctr1), .key(key), .out(keystream1));
    aes_encr aes_ctr2 (.in(ctr2), .key(key), .out(keystream2));
    aes_encr aes_ctr3 (.in(ctr3), .key(key), .out(keystream3));
    
    // 4. Tạo ciphertext
    assign ciphertext1 = plaintext1 ^ keystream1;
    assign ciphertext2 = plaintext2 ^ keystream2;
    assign ciphertext3 = plaintext3 ^ keystream3;
    
    // 5. GHASH Pipeline (6 bước do AAD có 2 blocks)
    // Y1 = GHASH(0, AAD_block1)
    ghash g1 (
        .data_in(aad_block1),
        .h_key(h_key),
        .y_prev(128'b0),
        .y_out(ghash_y1)
    );
    
    // Y2 = GHASH(Y1, AAD_block2) 
    ghash g2 (
        .data_in(aad_block2),
        .h_key(h_key),
        .y_prev(ghash_y1),
        .y_out(ghash_y2)
    );
    
    // Y3 = GHASH(Y2, C1)
    ghash g3 (
        .data_in(ciphertext1),
        .h_key(h_key),
        .y_prev(ghash_y2),
        .y_out(ghash_y3)
    );
    
    // Y4 = GHASH(Y3, C2)
    ghash g4 (
        .data_in(ciphertext2),
        .h_key(h_key),
        .y_prev(ghash_y3),
        .y_out(ghash_y4)
    );
    
    // Y5 = GHASH(Y4, C3)
    ghash g5 (
        .data_in(ciphertext3),
        .h_key(h_key),
        .y_prev(ghash_y4),
        .y_out(ghash_y5)
    );
    
    // Y6 = GHASH(Y5, len_block) - FINAL GHASH
    wire [127:0] ghash_final;
    ghash g6 (
        .data_in(len_block),
        .h_key(h_key),
        .y_prev(ghash_y5),
        .y_out(ghash_final)
    );
    
    // 6. Tạo tag = GHASH_final ⊕ E(K, Y[0])
    assign tag = ghash_final ^ tag_mask;
endmodule
