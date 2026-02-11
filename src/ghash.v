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
input [127:0] data_in,   // Khối dữ liệu đầu vào (AAD, Ciphertext hoặc Length Block)
    input [127:0] h_key,      // Hash Key H = AES_enc(Key, 0)
    input [127:0] y_prev,     // Kết quả GHASH của khối trước đó
    output [127:0] y_out      // Kết quả GHASH cho khối hiện tại
);

    // 1. Phép XOR dữ liệu vào với kết quả trước đó
    wire [127:0] x_in = data_in ^ y_prev;

    // 2. Thực hiện phép nhân trong trường Galois GF(2^128)
    assign y_out = gf_mult(x_in, h_key);

    function [127:0] gf_mult;
        input [127:0] x; // Dữ liệu đã XOR
        input [127:0] h; // Hash Key
        reg [127:0] v, z;
        integer i;
        begin
            z = 128'b0;
            v = h; 
            
            // QUAN TRỌNG: Duyệt từ LSB (bit 0) lên MSB (bit 127)
            // Đây là thứ tự đúng theo chuẩn GCM
            for (i = 0; i < 128; i = i + 1) begin
                // Kiểm tra bit thứ i của x (từ LSB lên MSB)
                if (x[127-i]) begin
                    z = z ^ v;
                end
                
                // Phép nhân v với x (Dịch phải và XOR với đa thức tối giản nếu cần)
                // Đa thức tối giản GCM: f = 1 + x + x^2 + x^7 + x^128
                if (v[0] == 1'b0) begin
                    v = v >> 1;
                end else begin
                    v = (v >> 1) ^ 128'hE1000000000000000000000000000000;
                end
            end
            gf_mult = z;
        end
    endfunction
endmodule
