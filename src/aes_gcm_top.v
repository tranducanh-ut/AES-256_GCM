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
   input clk,
    input rst,
    input start,
    input [255:0] key,
    input [95:0] nonce,
    input [127:0] plaintext1,
    input [127:0] plaintext2,
    input [127:0] plaintext3,
    input [223:0] aad,
    output reg [127:0] ciphertext1,
    output reg [127:0] ciphertext2,
    output reg [127:0] ciphertext3,
    output reg [127:0] tag,
    output reg done
);

    // FSM
    localparam IDLE        = 4'd0;
    localparam COMPUTE_H   = 4'd1;
    localparam COMPUTE_Y0  = 4'd2;
    localparam COMPUTE_Y1  = 4'd3;
    localparam COMPUTE_Y2  = 4'd4;
    localparam COMPUTE_Y3  = 4'd5;
    localparam GHASH_AAD1  = 4'd6;
    localparam GHASH_AAD2  = 4'd7;
    localparam GHASH_CT1   = 4'd8;
    localparam GHASH_CT2   = 4'd9;
    localparam GHASH_CT3   = 4'd10;
    localparam GHASH_LEN   = 4'd11;
    localparam FINALIZE    = 4'd12;
    localparam STABILIZE   = 4'd13;  // ← THÊM STATE MỚI
    localparam DONE_STATE  = 4'd14;  // ← THÊM STATE MỚI
    
    reg [3:0] state;
    reg [4:0] wait_counter;
    reg [2:0] stabilize_counter;  // ← Counter để đợi ổn định
    
    // Single AES instance
    reg [127:0] aes_in;
    wire [127:0] aes_out;
    
    aes_encr aes_shared (
        .in(aes_in),
        .key(key),
        .out(aes_out)
    );
    
    // Single GHASH instance
    reg [127:0] ghash_data;
    reg [127:0] ghash_prev;
    wire [127:0] ghash_out;
    reg [127:0] h_key_reg;
    
    ghash ghash_shared (
        .data_in(ghash_data),
        .h_key(h_key_reg),
        .y_prev(ghash_prev),
        .y_out(ghash_out)
    );
    
    // Storage
    reg [127:0] h_key;
    reg [127:0] tag_mask;
    reg [127:0] ks1, ks2, ks3;
    reg [127:0] ct1_temp, ct2_temp, ct3_temp;
    reg [127:0] ghash_accumulator;
    
    // AAD blocks
    wire [127:0] aad_block1 = aad[223:96];
    wire [127:0] aad_block2 = {aad[95:0], 32'h0};
    wire [127:0] len_block = {64'd224, 64'd384};
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done <= 1'b0;
            wait_counter <= 5'd0;
            stabilize_counter <= 3'd0;
            ciphertext1 <= 128'h0;
            ciphertext2 <= 128'h0;
            ciphertext3 <= 128'h0;
            tag <= 128'h0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    wait_counter <= 5'd0;
                    stabilize_counter <= 3'd0;
                    if (start) begin
                        aes_in <= 128'h0;
                        state <= COMPUTE_H;
                    end
                end
                
                COMPUTE_H: begin
                    if (wait_counter < 5'd3) begin
                        wait_counter <= wait_counter + 1'b1;
                    end else begin
                        h_key <= aes_out;
                        h_key_reg <= aes_out;
                        aes_in <= {nonce, 32'd1};
                        wait_counter <= 5'd0;
                        state <= COMPUTE_Y0;
                    end
                end
                
                COMPUTE_Y0: begin
                    if (wait_counter < 5'd3) begin
                        wait_counter <= wait_counter + 1'b1;
                    end else begin
                        tag_mask <= aes_out;
                        aes_in <= {nonce, 32'd2};
                        wait_counter <= 5'd0;
                        state <= COMPUTE_Y1;
                    end
                end
                
                COMPUTE_Y1: begin
                    if (wait_counter < 5'd3) begin
                        wait_counter <= wait_counter + 1'b1;
                    end else begin
                        ks1 <= aes_out;
                        ct1_temp <= plaintext1 ^ aes_out;
                        aes_in <= {nonce, 32'd3};
                        wait_counter <= 5'd0;
                        state <= COMPUTE_Y2;
                    end
                end
                
                COMPUTE_Y2: begin
                    if (wait_counter < 5'd3) begin
                        wait_counter <= wait_counter + 1'b1;
                    end else begin
                        ks2 <= aes_out;
                        ct2_temp <= plaintext2 ^ aes_out;
                        aes_in <= {nonce, 32'd4};
                        wait_counter <= 5'd0;
                        state <= COMPUTE_Y3;
                    end
                end
                
                COMPUTE_Y3: begin
                    if (wait_counter < 5'd3) begin
                        wait_counter <= wait_counter + 1'b1;
                    end else begin
                        ks3 <= aes_out;
                        ct3_temp <= plaintext3 ^ aes_out;
                        
                        // Start GHASH
                        ghash_data <= aad_block1;
                        ghash_prev <= 128'h0;
                        wait_counter <= 5'd0;
                        state <= GHASH_AAD1;
                    end
                end
                
                GHASH_AAD1: begin
                    if (wait_counter < 5'd2) begin
                        wait_counter <= wait_counter + 1'b1;
                    end else begin
                        ghash_accumulator <= ghash_out;
                        ghash_data <= aad_block2;
                        ghash_prev <= ghash_out;
                        wait_counter <= 5'd0;
                        state <= GHASH_AAD2;
                    end
                end
                
                GHASH_AAD2: begin
                    if (wait_counter < 5'd2) begin
                        wait_counter <= wait_counter + 1'b1;
                    end else begin
                        ghash_accumulator <= ghash_out;
                        ghash_data <= ct1_temp;
                        ghash_prev <= ghash_out;
                        wait_counter <= 5'd0;
                        state <= GHASH_CT1;
                    end
                end
                
                GHASH_CT1: begin
                    if (wait_counter < 5'd2) begin
                        wait_counter <= wait_counter + 1'b1;
                    end else begin
                        ghash_accumulator <= ghash_out;
                        ghash_data <= ct2_temp;
                        ghash_prev <= ghash_out;
                        wait_counter <= 5'd0;
                        state <= GHASH_CT2;
                    end
                end
                
                GHASH_CT2: begin
                    if (wait_counter < 5'd2) begin
                        wait_counter <= wait_counter + 1'b1;
                    end else begin
                        ghash_accumulator <= ghash_out;
                        ghash_data <= ct3_temp;
                        ghash_prev <= ghash_out;
                        wait_counter <= 5'd0;
                        state <= GHASH_CT3;
                    end
                end
                
                GHASH_CT3: begin
                    if (wait_counter < 5'd2) begin
                        wait_counter <= wait_counter + 1'b1;
                    end else begin
                        ghash_accumulator <= ghash_out;
                        ghash_data <= len_block;
                        ghash_prev <= ghash_out;
                        wait_counter <= 5'd0;
                        state <= GHASH_LEN;
                    end
                end
                
                GHASH_LEN: begin
                    if (wait_counter < 5'd2) begin
                        wait_counter <= wait_counter + 1'b1;
                    end else begin
                        ghash_accumulator <= ghash_out;
                        wait_counter <= 5'd0;
                        state <= FINALIZE;
                    end
                end
                
                FINALIZE: begin
                    // Latch outputs vào registers
                    ciphertext1 <= ct1_temp;
                    ciphertext2 <= ct2_temp;
                    ciphertext3 <= ct3_temp;
                    tag <= ghash_accumulator ^ tag_mask;
                    stabilize_counter <= 3'd0;
                    state <= STABILIZE;  // ← Chuyển sang STABILIZE
                end
                
                STABILIZE: begin
                    // Đợi thêm cycles để data ổn định
                    if (stabilize_counter < 3'd5) begin  // Đợi 5 cycles
                        stabilize_counter <= stabilize_counter + 1'b1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    // Chỉ assert done khi đã ổn định hoàn toàn
                    done <= 1'b1;
                    if (!start) begin  // Chờ start về 0
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end


endmodule
