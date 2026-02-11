`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2026 10:40:30 PM
// Design Name: 
// Module Name: aes_gcm_tb
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


module aes_gcm_tb;
   reg clk, rst;
    reg [255:0] key;
    reg [95:0] nonce;
    reg [127:0] pt1, pt2, pt3;
    reg [223:0] aad;  // AAD is 224 bits (28 bytes)
    wire [127:0] ct1, ct2, ct3;
    wire [127:0] tag;
    
    // Test Vector 2.2.2 parameters
    initial begin
        $display("\n=== TEST VECTOR 2.2.2: 60-byte Packet Encryption ===");
        $display("From: MACsec GCM-AES Test Vectors, pages 10-12\n");
        
        // Key (256-bit) - từ paper page 11
        key = 256'hE3C08A8F06C6E3AD95A70557B23F75483CE33021A9C72B7025666204C69C0B72;
        
        // IV (96-bit) = SCI || PN - từ paper page 10
        // SCI: 12153524C0895E81, PN: B2C28465
        nonce = 96'h12153524C0895E81B2C28465;
        
        // AAD (224 bits = 28 bytes) - từ paper page 10
        // MAC DA || MAC SA || Security Tag
        // D609B1F056637A0D46DF998D || 88E52E00B2C2846512153524C0895E81
        aad = 224'hD609B1F056637A0D46DF998D88E52E00B2C2846512153524C0895E81;
        
        // Plaintext (3 blocks, 384 bits total) - từ paper page 10-11
        pt1 = 128'h08000F101112131415161718191A1B1C;
        pt2 = 128'h1D1E1F202122232425262728292A2B2C;
        pt3 = 128'h2D2E2F303132333435363738393A0002;
        
        clk = 0;
        rst = 1;
        #10 rst = 0;
        
        // Chờ kết quả
        #200;
        
        // Kiểm tra kết quả
        $display("=== RESULTS ===\n");
        
        $display("Ciphertext Block 1:");
        $display("  Got:      %h", ct1);
        $display("  Expected: e2006eb42f5277022d9b19925bc419d7");
        if (ct1 == 128'he2006eb42f5277022d9b19925bc419d7)
            $display("  Status: ✓ PASS\n");
        else
            $display("  Status: ✗ FAIL\n");
        
        $display("Ciphertext Block 2:");
        $display("  Got:      %h", ct2);
        $display("  Expected: a592666c925fe2ef718eb4e308efeaa7");
        if (ct2 == 128'ha592666c925fe2ef718eb4e308efeaa7)
            $display("  Status: ✓ PASS\n");
        else
            $display("  Status: ✗ FAIL\n");
        
        $display("Ciphertext Block 3:");
        $display("  Got:      %h", ct3);
        $display("  Expected: c5273b394118860a5be2a97f56ab7836");
        if (ct3 == 128'hc5273b394118860a5be2a97f56ab7836)
            $display("  Status: ✓ PASS\n");
        else
            $display("  Status: ✗ FAIL\n");
        
        $display("Authentication Tag:");
        $display("  Got:      %h", tag);
        $display("  Expected: 5ca597cdbb3edb8d1a1151ea0af7b436");
        if (tag == 128'h5ca597cdbb3edb8d1a1151ea0af7b436)
            $display("  Status: ✓ PASS\n");
        else
            $display("  Status: ✗ FAIL\n");
        
        // Overall result
        if (ct1 == 128'he2006eb42f5277022d9b19925bc419d7 &&
            ct2 == 128'ha592666c925fe2ef718eb4e308efeaa7 &&
            ct3 == 128'hc5273b394118860a5be2a97f56ab7836 &&
            tag == 128'h5ca597cdbb3edb8d1a1151ea0af7b436) begin
            $display("=== ALL TESTS PASSED ✓✓✓ ===");
        end else begin
            $display("=== SOME TESTS FAILED ✗✗✗ ===");
        end
        
        $finish;
    end
    
    always #5 clk = ~clk;
    
    // Instantiate DUT
    aes_gcm_top dut (
        .clk(clk),
        .rst(rst),
        .key(key),
        .nonce(nonce),
        .plaintext1(pt1),
        .plaintext2(pt2),
        .plaintext3(pt3),
        .aad(aad),
        .ciphertext1(ct1),
        .ciphertext2(ct2),
        .ciphertext3(ct3),
        .tag(tag)
    );
endmodule
