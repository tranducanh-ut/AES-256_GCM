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
 input  wire        clk,
    input  wire        rst,     // active-high async reset (bạn có thể đổi sang sync nếu muốn)
    input  wire        start,   // pulse 1 cycle
    input  wire [127:0] in,
    input  wire [255:0] key,
    output reg  [127:0] out,
    output reg         done,
    output reg         busy
);

    // ============================================================
    // 1) Key expansion (combinational)
    //   15 round keys x 128-bit = 1920 bits
    //   K0 .. K14
    // ============================================================
    wire [1919:0] roundKeys;

    keyexpan ke (
        .key(key),
        .roundKeys(roundKeys)
    );

    // Helper wires for keys
    wire [127:0] k0  = roundKeys[1919 -: 128]; // K0 (first 128 bits)
    wire [127:0] k14 = roundKeys[127:0];       // K14 (last 128 bits)

    // Function-like selection (combinational) for K1..K13
    // key for round r (1..13): roundKeys[1919 - 128*r -: 128]
    wire [127:0] k_round;
    reg  [3:0]   round_cnt; // 1..14 when busy

    assign k_round = (round_cnt == 4'd14) ? k14
                    : roundKeys[1919 - 128*round_cnt -: 128];

    // ============================================================
    // 2) State register (holds 128-bit AES state)
    // ============================================================
    reg [127:0] state_reg;

    // ============================================================
    // 3) Combinational datapath for:
    //    - Round0 AddRoundKey (at start)
    //    - Round 1..13 (encryptRound)
    //    - Round14 final (subbyte+shiftrow+addroundkey)
    // ============================================================

    // --- Round0: AddRoundKey(input, K0) ---
    wire [127:0] state0_wire;
    addroundkey u_ark0 (
        .data(in),
        .key (k0),
        .out (state0_wire)
    );

    // --- Round 1..13: full round (includes MixColumns) ---
    wire [127:0] round_full_out;
    encryptRound u_round_full (
        .in  (state_reg),
        .key (k_round),
        .out (round_full_out)
    );

    // --- Round14: final round (no MixColumns) ---
    wire [127:0] sb_out;
    wire [127:0] sr_out;
    wire [127:0] final_out;

    subbyte u_sb_final (
        .in (state_reg),
        .out(sb_out)
    );

    shiftrow u_sr_final (
        .in (sb_out),
        .out(sr_out)
    );

    addroundkey u_ark_final (
        .data(sr_out),
        .key (k14),
        .out (final_out)
    );

    // ============================================================
    // 4) Control FSM (simple)
    // ============================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_reg <= 128'd0;
            out       <= 128'd0;
            done      <= 1'b0;
            busy      <= 1'b0;
            round_cnt <= 4'd0;
        end else begin
            // default: done is a pulse
            done <= 1'b0;

            if (!busy) begin
                // idle
                if (start) begin
                    // load initial state = AddRoundKey(in, K0)
                    state_reg <= state0_wire;
                    busy      <= 1'b1;
                    round_cnt <= 4'd1; // next cycle execute Round1
                end
            end else begin
                // busy: executing rounds
                if (round_cnt <= 4'd13) begin
                    // execute full round 1..13
                    state_reg <= round_full_out;
                    round_cnt <= round_cnt + 4'd1;
                end else begin
                    // round_cnt == 14: execute final round, finish
                    state_reg <= final_out;
                    out       <= final_out;
                    done      <= 1'b1;
                    busy      <= 1'b0;
                    round_cnt <= 4'd0;
                end
            end
        end
    end
endmodule
