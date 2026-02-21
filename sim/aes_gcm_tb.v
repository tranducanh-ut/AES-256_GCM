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
    reg start;
    reg [255:0] key;
    reg [95:0] nonce;
    reg [127:0] pt1, pt2, pt3;
    reg [223:0] aad;
    wire [127:0] ct1, ct2, ct3;
    wire [127:0] tag;
    wire done;

    // =====================================================
    // 🔥 Cycle Counter (THÊM PHẦN NÀY)
    // =====================================================
    integer cycle_counter;
    integer start_cycle;
    integer end_cycle;

    reg start_d;

    always @(posedge clk) begin
        if (rst)
            cycle_counter <= 0;
        else
            cycle_counter <= cycle_counter + 1;
    end

    // Detect rising edge of start
    always @(posedge clk) begin
        start_d <= start;
        if (start && !start_d)
            start_cycle <= cycle_counter;
    end

    // Capture done
    always @(posedge clk) begin
        if (done)
            end_cycle <= cycle_counter;
    end
    // =====================================================


    initial begin
        $display("\n=== TEST VECTOR 2.2.2: 60-byte Packet Encryption ===");
        $display("From: MACsec GCM-AES Test Vectors, pages 10-12\n");

        clk = 0;
        rst = 1;
        start = 0;

        key = 256'hE3C08A8F06C6E3AD95A70557B23F75483CE33021A9C72B7025666204C69C0B72;
        nonce = 96'h12153524C0895E81B2C28465;
        aad = 224'hD609B1F056637A0D46DF998D88E52E00B2C2846512153524C0895E81;

        pt1 = 128'h08000F101112131415161718191A1B1C;
        pt2 = 128'h1D1E1F202122232425262728292A2B2C;
        pt3 = 128'h2D2E2F303132333435363738393A0002;

        #10 rst = 0;
        #10;

        $display("Starting encryption at time %0t", $time);
        start = 1;
        #10;
        start = 0;

        wait(done == 1);

        $display("Encryption completed at time %0t", $time);

        // 🔥 In cycle result
        $display("Total Cycles = %0d", end_cycle - start_cycle);
        $display("Total Time (ns) = %0d", (end_cycle - start_cycle)*10);

        #10;

        $display("\n=== RESULTS ===\n");

        $display("Ciphertext Block 1:");
        $display("  Got:      %h", ct1);
        $display("  Expected: e2006eb42f5277022d9b19925bc419d7");

        $display("Ciphertext Block 2:");
        $display("  Got:      %h", ct2);
        $display("  Expected: a592666c925fe2ef718eb4e308efeaa7");

        $display("Ciphertext Block 3:");
        $display("  Got:      %h", ct3);
        $display("  Expected: c5273b394118860a5be2a97f56ab7836");

        $display("Authentication Tag:");
        $display("  Got:      %h", tag);
        $display("  Expected: 5ca597cdbb3edb8d1a1151ea0af7b436");

        #50;
        $finish;
    end

    always #5 clk = ~clk;

    aes_gcm_top dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .key(key),
        .nonce(nonce),
        .plaintext1(pt1),
        .plaintext2(pt2),
        .plaintext3(pt3),
        .aad(aad),
        .ciphertext1(ct1),
        .ciphertext2(ct2),
        .ciphertext3(ct3),
        .tag(tag),
        .done(done)
    );
endmodule
