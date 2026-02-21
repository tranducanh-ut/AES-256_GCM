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

    // =====================================================
    // FSM
    // =====================================================
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
    localparam DONE_STATE  = 4'd13;

    reg [3:0] state;
     reg [127:0] h_key;
    reg [127:0] tag_mask;
    reg [127:0] ct1_temp, ct2_temp, ct3_temp;
    reg [127:0] ghash_accumulator;

    wire [127:0] aad_block1 = aad[223:96];
    wire [127:0] aad_block2 = {aad[95:0], 32'h0};
    wire [127:0] len_block  = {64'd224, 64'd384};


    // =====================================================
    // AES
    // =====================================================
    reg         aes_start;
    reg         aes_issued;
    wire        aes_done;
    wire        aes_busy;
    reg  [127:0] aes_in;
    wire [127:0] aes_out;

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

    // =====================================================
    // GHASH iterative
    // =====================================================
    reg         ghash_start;
    reg         ghash_issued;
    wire        ghash_done;

    reg  [127:0] ghash_data;
    reg  [127:0] ghash_prev;
    wire [127:0] ghash_out;

    ghash ghash_shared (
        .clk     (clk),
        .rst     (rst),
        .start   (ghash_start),
        .data_in (ghash_data),
        .h_key   (h_key),
        .y_prev  (ghash_prev),
        .done    (ghash_done),
        .y_out   (ghash_out)
    );

    // =====================================================
    // Internal registers
    // =====================================================
   
    // =====================================================
    // MAIN FSM
    // =====================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            done  <= 0;

            aes_start  <= 0;
            aes_issued <= 0;
            ghash_start  <= 0;
            ghash_issued <= 0;

            ciphertext1 <= 0;
            ciphertext2 <= 0;
            ciphertext3 <= 0;
            tag         <= 0;

        end else begin
            aes_start   <= 0;
            ghash_start <= 0;
            done        <= 0;

            case (state)

            // =====================================================
            IDLE: begin
                if (start) begin
                    aes_in <= 128'h0;
                    aes_issued <= 0;
                    state <= COMPUTE_H;
                end
            end

            // =====================================================
            COMPUTE_H: begin
                if (!aes_issued && !aes_busy) begin
                    aes_start  <= 1;
                    aes_issued <= 1;
                end
                if (aes_done) begin
                    h_key <= aes_out;
                    aes_issued <= 0;
                    aes_in <= {nonce, 32'd1};
                    state <= COMPUTE_Y0;
                end
            end

            COMPUTE_Y0: begin
                if (!aes_issued && !aes_busy) begin
                    aes_start <= 1;
                    aes_issued <= 1;
                end
                if (aes_done) begin
                    tag_mask <= aes_out;
                    aes_issued <= 0;
                    aes_in <= {nonce, 32'd2};
                    state <= COMPUTE_Y1;
                end
            end

            COMPUTE_Y1: begin
                if (!aes_issued && !aes_busy) begin
                    aes_start <= 1;
                    aes_issued <= 1;
                end
                if (aes_done) begin
                    ct1_temp <= plaintext1 ^ aes_out;
                    aes_issued <= 0;
                    aes_in <= {nonce, 32'd3};
                    state <= COMPUTE_Y2;
                end
            end

            COMPUTE_Y2: begin
                if (!aes_issued && !aes_busy) begin
                    aes_start <= 1;
                    aes_issued <= 1;
                end
                if (aes_done) begin
                    ct2_temp <= plaintext2 ^ aes_out;
                    aes_issued <= 0;
                    aes_in <= {nonce, 32'd4};
                    state <= COMPUTE_Y3;
                end
            end

            COMPUTE_Y3: begin
                if (!aes_issued && !aes_busy) begin
                    aes_start <= 1;
                    aes_issued <= 1;
                end
                if (aes_done) begin
                    ct3_temp <= plaintext3 ^ aes_out;
                    aes_issued <= 0;

                    ghash_data <= aad_block1;
                    ghash_prev <= 128'h0;
                    ghash_issued <= 0;
                    state <= GHASH_AAD1;
                end
            end

            // =====================================================
            // GHASH sequence
            // =====================================================
            GHASH_AAD1,
            GHASH_AAD2,
            GHASH_CT1,
            GHASH_CT2,
            GHASH_CT3,
            GHASH_LEN: begin

                if (!ghash_issued) begin
                    ghash_start  <= 1;
                    ghash_issued <= 1;
                end

                if (ghash_done) begin
                    ghash_accumulator <= ghash_out;
                    ghash_prev <= ghash_out;
                    ghash_issued <= 0;

                    case (state)
                        GHASH_AAD1: begin
                            ghash_data <= aad_block2;
                            state <= GHASH_AAD2;
                        end
                        GHASH_AAD2: begin
                            ghash_data <= ct1_temp;
                            state <= GHASH_CT1;
                        end
                        GHASH_CT1: begin
                            ghash_data <= ct2_temp;
                            state <= GHASH_CT2;
                        end
                        GHASH_CT2: begin
                            ghash_data <= ct3_temp;
                            state <= GHASH_CT3;
                        end
                        GHASH_CT3: begin
                            ghash_data <= len_block;
                            state <= GHASH_LEN;
                        end
                        GHASH_LEN: begin
                            state <= FINALIZE;
                        end
                    endcase
                end
            end

            // =====================================================
            FINALIZE: begin
                ciphertext1 <= ct1_temp;
                ciphertext2 <= ct2_temp;
                ciphertext3 <= ct3_temp;
                tag <= ghash_accumulator ^ tag_mask;
                state <= DONE_STATE;
            end

            DONE_STATE: begin
                done <= 1;
                if (!start)
                    state <= IDLE;
            end

            endcase
        end
    end
endmodule
