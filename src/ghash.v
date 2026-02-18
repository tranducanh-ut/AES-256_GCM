`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2026 10:37:43 PM
// Design Name: 
// Module Name: ghash
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


module ghash(
 input  wire        clk,
    input  wire        rst,        // active high
    input  wire        start,      // pulse 1 cycle
    input  wire [127:0] data_in,
    input  wire [127:0] h_key,
    input  wire [127:0] y_prev,
    output reg         done,       // pulse 1 cycle
    output reg  [127:0] y_out
);

    reg [127:0] x;
    reg [127:0] v;
    reg [127:0] z;
    reg [6:0]   cnt;
    reg         busy;

    wire        x_bit;
    wire [127:0] z_next;
    wire        v_lsb;
    wire [127:0] v_shift;
    wire [127:0] v_next;

    assign x_bit   = x[127 - cnt];
    assign z_next  = x_bit ? (z ^ v) : z;
    assign v_lsb   = v[0];
    assign v_shift = v >> 1;
    assign v_next  = v_lsb ? 
                     (v_shift ^ 128'hE1000000000000000000000000000000) :
                     v_shift;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x      <= 0;
            v      <= 0;
            z      <= 0;
            cnt    <= 0;
            busy   <= 0;
            done   <= 0;
            y_out  <= 0;
        end else begin
            done <= 0;

            if (start && !busy) begin
                x    <= data_in ^ y_prev;
                v    <= h_key;
                z    <= 0;
                cnt  <= 0;
                busy <= 1;
            end
            else if (busy) begin
                z <= z_next;
                v <= v_next;

                if (cnt == 7'd127) begin
                    y_out <= z_next;   
                    done  <= 1;
                    busy  <= 0;
                end
                else begin
                    cnt <= cnt + 1;
                end
            end
        end
    end

endmodule
