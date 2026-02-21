`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/28/2026 09:43:59 PM
// Design Name: 
// Module Name: encryt
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


module encryptRound(
 input [127:0] in,
output [127:0] out,
input [127:0] key
    );
    wire [127:0] afterSubBytes;
wire [127:0] afterShiftRows;
wire [127:0] afterMixColumns;
wire [127:0] afterAddroundKey;

subbyte sub(in,afterSubBytes);
shiftrow sh(afterSubBytes,afterShiftRows);
mixcol mx(afterShiftRows,afterMixColumns);
addroundkey add(afterMixColumns, key, out);
endmodule
