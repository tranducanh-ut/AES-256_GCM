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
     input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [255:0] key,
    input  wire [95:0]  nonce,
    input  wire [127:0] plaintext1,
    input  wire [127:0] plaintext2,
    input  wire [127:0] plaintext3,
    input  wire [223:0] aad,
    output reg  [127:0] ciphertext1,
    output reg  [127:0] ciphertext2,
    output reg  [127:0] ciphertext3,
    output reg  [127:0] tag,
    output reg         done
);

    // ============================================================
    // FSM states (giữ nguyên như bạn đang dùng)
    // ============================================================
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
    localparam STABILIZE   = 4'd13;
    localparam DONE_STATE  = 4'd14;

    reg [3:0] state;

    // Counter đợi ổn định output (bạn đang dùng)
    reg [2:0] stabilize_counter;

    // ============================================================
    // AES iterative shared instance (ĐÃ SỬA)
    // ============================================================
    reg         aes_start;
    wire        aes_done;
    wire        aes_busy;
    reg  [127:0] aes_in;
    wire [127:0] aes_out;

    // Cờ để đảm bảo aes_start chỉ pulse 1 lần / state
    reg aes_issued;

    aes_encr aes_shared (
        .clk   (clk),
        .rst   (rst),
        .start (aes_start),
        .in    (aes_in),
        .key   (key),
        .out   (aes_out),
        .done  (aes_done),
        .busy  (aes_busy)
    );

    // ============================================================
    // GHASH combinational (giữ nguyên)
    // ============================================================
    reg  [127:0] ghash_data;
    reg  [127:0] ghash_prev;
    wire [127:0] ghash_out;

    // Storage
    reg [127:0] h_key;
    reg [127:0] tag_mask;
    reg [127:0] ct1_temp, ct2_temp, ct3_temp;
    reg [127:0] ghash_accumulator;

    // AAD blocks
    wire [127:0] aad_block1 = aad[223:96];
    wire [127:0] aad_block2 = {aad[95:0], 32'h0};

    // length block: [len(AAD) || len(C)] in bits
    // AAD = 224 bits, C = 3*128 = 384 bits
    wire [127:0] len_block = {64'd224, 64'd384};

    ghash ghash_shared (
        .data_in(ghash_data),
        .h_key  (h_key),
        .y_prev (ghash_prev),
        .y_out  (ghash_out)
    );

    // ============================================================
    // Main FSM
    // ============================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done  <= 1'b0;

            aes_in     <= 128'd0;
            aes_start  <= 1'b0;
            aes_issued <= 1'b0;

            stabilize_counter <= 3'd0;

            ciphertext1 <= 128'd0;
            ciphertext2 <= 128'd0;
            ciphertext3 <= 128'd0;
            tag         <= 128'd0;

            h_key            <= 128'd0;
            tag_mask         <= 128'd0;
            ct1_temp         <= 128'd0;
            ct2_temp         <= 128'd0;
            ct3_temp         <= 128'd0;
            ghash_data       <= 128'd0;
            ghash_prev       <= 128'd0;
            ghash_accumulator<= 128'd0;

        end else begin
            // default
            aes_start <= 1'b0; // pulse-only
            done      <= 1'b0;

            case (state)

                // ====================================================
                IDLE: begin
                    aes_issued         <= 1'b0;
                    stabilize_counter  <= 3'd0;

                    if (start) begin
                        // AES_enc(K, 0) => H key
                        aes_in   <= 128'h0;
                        state    <= COMPUTE_H;
                    end
                end

                // ====================================================
                // COMPUTE_H: run AES_enc(key, 0) => h_key
                COMPUTE_H: begin
                    // issue AES start once
                    if (!aes_issued && !aes_busy) begin
                        aes_start  <= 1'b1;
                        aes_issued <= 1'b1;
                    end

                    // wait done
                    if (aes_done) begin
                        h_key      <= aes_out;
                        aes_issued <= 1'b0;

                        // Next: tag_mask = AES_enc(key, {nonce,1})
                        aes_in <= {nonce, 32'd1};
                        state  <= COMPUTE_Y0;
                    end
                end

                // ====================================================
                // COMPUTE_Y0: tag_mask = AES_enc(key, {nonce,1})
                COMPUTE_Y0: begin
                    if (!aes_issued && !aes_busy) begin
                        aes_start  <= 1'b1;
                        aes_issued <= 1'b1;
                    end

                    if (aes_done) begin
                        tag_mask   <= aes_out;
                        aes_issued <= 1'b0;

                        // Y1 keystream = AES_enc(key, {nonce,2})
                        aes_in <= {nonce, 32'd2};
                        state  <= COMPUTE_Y1;
                    end
                end

                // ====================================================
                // COMPUTE_Y1: ks1 = AES_enc(key, {nonce,2}), ct1 = pt1 ^ ks1
                COMPUTE_Y1: begin
                    if (!aes_issued && !aes_busy) begin
                        aes_start  <= 1'b1;
                        aes_issued <= 1'b1;
                    end

                    if (aes_done) begin
                        ct1_temp   <= plaintext1 ^ aes_out;
                        aes_issued <= 1'b0;

                        // Y2 keystream = AES_enc(key, {nonce,3})
                        aes_in <= {nonce, 32'd3};
                        state  <= COMPUTE_Y2;
                    end
                end

                // ====================================================
                // COMPUTE_Y2
                COMPUTE_Y2: begin
                    if (!aes_issued && !aes_busy) begin
                        aes_start  <= 1'b1;
                        aes_issued <= 1'b1;
                    end

                    if (aes_done) begin
                        ct2_temp   <= plaintext2 ^ aes_out;
                        aes_issued <= 1'b0;

                        // Y3 keystream = AES_enc(key, {nonce,4})
                        aes_in <= {nonce, 32'd4};
                        state  <= COMPUTE_Y3;
                    end
                end

                // ====================================================
                // COMPUTE_Y3
                COMPUTE_Y3: begin
                    if (!aes_issued && !aes_busy) begin
                        aes_start  <= 1'b1;
                        aes_issued <= 1'b1;
                    end

                    if (aes_done) begin
                        ct3_temp   <= plaintext3 ^ aes_out;
                        aes_issued <= 1'b0;

                        // Start GHASH
                        ghash_data <= aad_block1;
                        ghash_prev <= 128'h0;
                        state      <= GHASH_AAD1;
                    end
                end

                // ====================================================
                // GHASH pipeline (giữ kiểu "đợi 1 nhịp" vì ghash_out là comb)
                GHASH_AAD1: begin
                    ghash_accumulator <= ghash_out;
                    ghash_data <= aad_block2;
                    ghash_prev <= ghash_out;
                    state      <= GHASH_AAD2;
                end

                GHASH_AAD2: begin
                    ghash_accumulator <= ghash_out;
                    ghash_data <= ct1_temp;
                    ghash_prev <= ghash_out;
                    state      <= GHASH_CT1;
                end

                GHASH_CT1: begin
                    ghash_accumulator <= ghash_out;
                    ghash_data <= ct2_temp;
                    ghash_prev <= ghash_out;
                    state      <= GHASH_CT2;
                end

                GHASH_CT2: begin
                    ghash_accumulator <= ghash_out;
                    ghash_data <= ct3_temp;
                    ghash_prev <= ghash_out;
                    state      <= GHASH_CT3;
                end

                GHASH_CT3: begin
                    ghash_accumulator <= ghash_out;
                    ghash_data <= len_block;
                    ghash_prev <= ghash_out;
                    state      <= GHASH_LEN;
                end

                GHASH_LEN: begin
                    ghash_accumulator <= ghash_out;
                    state <= FINALIZE;
                end

                // ====================================================
                FINALIZE: begin
                    ciphertext1 <= ct1_temp;
                    ciphertext2 <= ct2_temp;
                    ciphertext3 <= ct3_temp;

                    // tag = GHASH ^ tag_mask
                    tag <= ghash_accumulator ^ tag_mask;

                    stabilize_counter <= 3'd0;
                    state <= STABILIZE;
                end

                STABILIZE: begin
                    if (stabilize_counter < 3'd5)
                        stabilize_counter <= stabilize_counter + 1'b1;
                    else
                        state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start)
                        state <= IDLE;
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
