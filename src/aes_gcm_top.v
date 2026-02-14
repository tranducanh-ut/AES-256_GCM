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
    input [95:0]  nonce,
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
    
    // Wires cho kết quả combinational
    wire [127:0] ciphertext1_comb;
    wire [127:0] ciphertext2_comb;
    wire [127:0] ciphertext3_comb;
    wire [127:0] tag_comb;
    
    wire [127:0] h_key;
    wire [127:0] ctr0, ctr1, ctr2, ctr3;
    wire [127:0] keystream1, keystream2, keystream3;
    wire [127:0] tag_mask;
    
    // GHASH intermediate values
    wire [127:0] ghash_y1, ghash_y2, ghash_y3, ghash_y4, ghash_y5;
    
    // Length block
    wire [127:0] len_block = {64'd224, 64'd384};
    
    // AAD blocks
    wire [127:0] aad_block1 = aad[223:96];
    wire [127:0] aad_block2 = {aad[95:0], 32'h00000000};
    
    // FSM states
    localparam IDLE = 3'b000;
    localparam COMPUTING = 3'b001;
    localparam LATCHING = 3'b010;      // State mới: Latch data
    localparam STABILIZING = 3'b011;   // State mới: Đợi data ổn định
    localparam DONE = 3'b100;          // Assert done
    
    reg [2:0] state, next_state;
    reg [3:0] wait_counter;
    
    // Số cycles chờ cho mỗi giai đoạn
    localparam COMPUTE_CYCLES = 4'd5;    // Đợi combinational logic
    localparam STABILIZE_CYCLES = 4'd3;  // Đợi sau khi latch để ổn định
    
    // Tạo hash key
    aes_encr aes_h (.in(128'b0), .key(key), .out(h_key));
    
    // Tạo counter values
    assign ctr0 = {nonce, 32'd1};
    assign ctr1 = {nonce, 32'd2};
    assign ctr2 = {nonce, 32'd3};
    assign ctr3 = {nonce, 32'd4};
    
    // Encrypt counters
    aes_encr aes_tag_gen (.in(ctr0), .key(key), .out(tag_mask));
    aes_encr aes_ctr1 (.in(ctr1), .key(key), .out(keystream1));
    aes_encr aes_ctr2 (.in(ctr2), .key(key), .out(keystream2));
    aes_encr aes_ctr3 (.in(ctr3), .key(key), .out(keystream3));
    
    // Tạo ciphertext
    assign ciphertext1_comb = plaintext1 ^ keystream1;
    assign ciphertext2_comb = plaintext2 ^ keystream2;
    assign ciphertext3_comb = plaintext3 ^ keystream3;
    
    // GHASH chain
    ghash g1 (
        .data_in(aad_block1),
        .h_key(h_key),
        .y_prev(128'b0),
        .y_out(ghash_y1)
    );
    
    ghash g2 (
        .data_in(aad_block2),
        .h_key(h_key),
        .y_prev(ghash_y1),
        .y_out(ghash_y2)
    );
    
    ghash g3 (
        .data_in(ciphertext1_comb),
        .h_key(h_key),
        .y_prev(ghash_y2),
        .y_out(ghash_y3)
    );
    
    ghash g4 (
        .data_in(ciphertext2_comb),
        .h_key(h_key),
        .y_prev(ghash_y3),
        .y_out(ghash_y4)
    );
    
    ghash g5 (
        .data_in(ciphertext3_comb),
        .h_key(h_key),
        .y_prev(ghash_y4),
        .y_out(ghash_y5)
    );
    
    wire [127:0] ghash_final;
    ghash g6 (
        .data_in(len_block),
        .h_key(h_key),
        .y_prev(ghash_y5),
        .y_out(ghash_final)
    );
    
    assign tag_comb = ghash_final ^ tag_mask;
    
    // FSM - State register
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // Wait counter
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wait_counter <= 4'b0;
        end else begin
            case (state)
                IDLE: 
                    wait_counter <= 4'b0;
                    
                COMPUTING: begin
                    if (wait_counter < COMPUTE_CYCLES)
                        wait_counter <= wait_counter + 1'b1;
                    else
                        wait_counter <= 4'b0;  // Reset cho state tiếp theo
                end
                
                LATCHING:
                    wait_counter <= 4'b0;  // Reset cho STABILIZING
                    
                STABILIZING: begin
                    if (wait_counter < STABILIZE_CYCLES)
                        wait_counter <= wait_counter + 1'b1;
                end
                
                DONE:
                    wait_counter <= 4'b0;
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTING;
            end
            
            COMPUTING: begin
                if (wait_counter >= COMPUTE_CYCLES)
                    next_state = LATCHING;
            end
            
            LATCHING: begin
                next_state = STABILIZING;
            end
            
            STABILIZING: begin
                if (wait_counter >= STABILIZE_CYCLES)
                    next_state = DONE;
            end
            
            DONE: begin
                if (!start)
                    next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ciphertext1 <= 128'b0;
            ciphertext2 <= 128'b0;
            ciphertext3 <= 128'b0;
            tag <= 128'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                
                COMPUTING: begin
                    done <= 1'b0;
                end
                
                LATCHING: begin
                    // Chốt data tại state này
                    ciphertext1 <= ciphertext1_comb;
                    ciphertext2 <= ciphertext2_comb;
                    ciphertext3 <= ciphertext3_comb;
                    tag <= tag_comb;
                    done <= 1'b0;
                end
                
                STABILIZING: begin
                    // Data đã được latch, đợi ổn định
                    done <= 1'b0;
                end
                
                DONE: begin
                    // Sau khi data đã ổn định, mới assert done
                    done <= 1'b1;
                end
            endcase
        end
    end


endmodule
