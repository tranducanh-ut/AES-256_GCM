`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/15/2026 12:38:29 AM
// Design Name: 
// Module Name: aes_gcm_spi_wrapper
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


module aes_gcm_spi_wrapper(
     input clk,
    input rst,
    
    input spi_sck,
    input spi_mosi,
    output reg spi_miso,
    input spi_cs_n,
    
    output irq
);

    //========================================================================
    // CDC Synchronizers
    //========================================================================
    reg [2:0] spi_sck_sync;
    reg [2:0] spi_mosi_sync;
    reg [2:0] spi_cs_n_sync;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            spi_sck_sync <= 3'b000;
            spi_mosi_sync <= 3'b000;
            spi_cs_n_sync <= 3'b111;
        end else begin
            spi_sck_sync <= {spi_sck_sync[1:0], spi_sck};
            spi_mosi_sync <= {spi_mosi_sync[1:0], spi_mosi};
            spi_cs_n_sync <= {spi_cs_n_sync[1:0], spi_cs_n};
        end
    end
    
    wire spi_sck_rising = (spi_sck_sync[2:1] == 2'b01);
    wire spi_sck_falling = (spi_sck_sync[2:1] == 2'b10);
    wire spi_cs_active = !spi_cs_n_sync[2];
    
    //========================================================================
    // Internal registers
    //========================================================================
    reg [255:0] key_reg;
    reg [95:0] nonce_reg;
    reg [127:0] pt1_reg, pt2_reg, pt3_reg;
    reg [223:0] aad_reg;
    
    wire [127:0] ct1, ct2, ct3, tag;
    wire done;
    
    reg [127:0] ct1_reg, ct2_reg, ct3_reg, tag_reg;
    
    reg [7:0] spi_rx_byte;
    reg [7:0] spi_tx_byte;
    reg [2:0] bit_counter;
    reg [10:0] byte_counter;
    reg [7:0] cmd_reg;
    
    localparam CMD_WRITE_KEY    = 8'h01;
    localparam CMD_WRITE_NONCE  = 8'h02;
    localparam CMD_WRITE_PT     = 8'h03;
    localparam CMD_WRITE_AAD    = 8'h04;
    localparam CMD_START        = 8'h10;
    localparam CMD_READ_CT      = 8'h20;
    localparam CMD_READ_TAG     = 8'h21;
    localparam CMD_READ_STATUS  = 8'hF0;
    
    localparam IDLE       = 3'd0;
    localparam RECV_DATA  = 3'd1;
    localparam EXEC_CMD   = 3'd2;
    localparam SEND_DATA  = 3'd3;
    
    reg [2:0] state;
    reg start_aes;
    reg byte_received;
    reg tx_shift_enable;  // Control khi nào shift
    
    //========================================================================
    // Latch AES outputs
    //========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ct1_reg <= 128'h0;
            ct2_reg <= 128'h0;
            ct3_reg <= 128'h0;
            tag_reg <= 128'h0;
        end else if (done) begin
            ct1_reg <= ct1;
            ct2_reg <= ct2;
            ct3_reg <= ct3;
            tag_reg <= tag;
        end
    end
    
    //========================================================================
    // SPI Receiver
    //========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            spi_rx_byte <= 8'h00;
            bit_counter <= 3'd0;
            byte_received <= 1'b0;
        end else begin
            byte_received <= 1'b0;
            
            if (!spi_cs_active) begin
                bit_counter <= 3'd0;
            end else if (spi_sck_rising) begin
                spi_rx_byte <= {spi_rx_byte[6:0], spi_mosi_sync[2]};
                bit_counter <= bit_counter + 1'b1;
                
                if (bit_counter == 3'd7) begin
                    byte_received <= 1'b1;
                    bit_counter <= 3'd0;
                end
            end
        end
    end
    
    //========================================================================
    // UNIFIED FSM - Handles both TX and state control
    //========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            cmd_reg <= 8'h00;
            byte_counter <= 11'd0;
            key_reg <= 256'h0;
            nonce_reg <= 96'h0;
            pt1_reg <= 128'h0;
            pt2_reg <= 128'h0;
            pt3_reg <= 128'h0;
            aad_reg <= 224'h0;
            start_aes <= 1'b0;
            spi_tx_byte <= 8'h00;
            spi_miso <= 1'b0;
            tx_shift_enable <= 1'b0;
        end else begin
            start_aes <= 1'b0;
            tx_shift_enable <= 1'b0;
            
            // TX shift logic (khi không load data mới)
            if (spi_cs_active && spi_sck_falling && tx_shift_enable) begin
                spi_miso <= spi_tx_byte[7];
                spi_tx_byte <= {spi_tx_byte[6:0], 1'b0};
            end
            
            if (!spi_cs_active) begin
                state <= IDLE;
                byte_counter <= 11'd0;
                spi_tx_byte <= 8'h00;
                spi_miso <= 1'b0;
            end else begin
                case (state)
                    IDLE: begin
                        byte_counter <= 11'd0;
                        if (byte_received) begin
                            cmd_reg <= spi_rx_byte;
                            
                            case (spi_rx_byte)
                                CMD_READ_STATUS: begin
                                    spi_tx_byte <= {7'b0, done};
                                    state <= SEND_DATA;
                                    tx_shift_enable <= 1'b1;
                                end
                                
                                CMD_READ_CT: begin
                                    spi_tx_byte <= ct1_reg[127:120];
                                    state <= SEND_DATA;
                                    tx_shift_enable <= 1'b1;
                                end
                                
                                CMD_READ_TAG: begin
                                    spi_tx_byte <= tag_reg[127:120];
                                    state <= SEND_DATA;
                                    tx_shift_enable <= 1'b1;
                                end
                                
                                CMD_START: begin
                                    state <= EXEC_CMD;
                                end
                                
                                default: begin
                                    state <= RECV_DATA;
                                end
                            endcase
                        end
                    end
                    
                    RECV_DATA: begin
                        if (byte_received) begin
                            byte_counter <= byte_counter + 1'b1;
                            
                            case (cmd_reg)
                                CMD_WRITE_KEY: begin
                                    key_reg <= {key_reg[247:0], spi_rx_byte};
                                    if (byte_counter >= 11'd31)
                                        state <= IDLE;
                                end
                                
                                CMD_WRITE_NONCE: begin
                                    nonce_reg <= {nonce_reg[87:0], spi_rx_byte};
                                    if (byte_counter >= 11'd11)
                                        state <= IDLE;
                                end
                                
                                CMD_WRITE_PT: begin
                                    if (byte_counter < 11'd16)
                                        pt1_reg <= {pt1_reg[119:0], spi_rx_byte};
                                    else if (byte_counter < 11'd32)
                                        pt2_reg <= {pt2_reg[119:0], spi_rx_byte};
                                    else
                                        pt3_reg <= {pt3_reg[119:0], spi_rx_byte};
                                    
                                    if (byte_counter >= 11'd47)
                                        state <= IDLE;
                                end
                                
                                CMD_WRITE_AAD: begin
                                    aad_reg <= {aad_reg[215:0], spi_rx_byte};
                                    if (byte_counter >= 11'd27)
                                        state <= IDLE;
                                end
                            endcase
                        end
                    end
                    
                    EXEC_CMD: begin
                        start_aes <= 1'b1;
                        state <= IDLE;
                    end
                    
                    SEND_DATA: begin
                        tx_shift_enable <= 1'b1;
                        
                        if (byte_received) begin
                            byte_counter <= byte_counter + 1'b1;
                            
                            case (cmd_reg)
                                CMD_READ_CT: begin
                                    if (byte_counter < 11'd15)
                                        spi_tx_byte <= ct1_reg[119 - byte_counter*8 -: 8];
                                    else if (byte_counter < 11'd31)
                                        spi_tx_byte <= ct2_reg[127 - (byte_counter-15)*8 -: 8];
                                    else if (byte_counter < 11'd47)
                                        spi_tx_byte <= ct3_reg[127 - (byte_counter-31)*8 -: 8];
                                    else
                                        state <= IDLE;
                                end
                                
                                CMD_READ_TAG: begin
                                    if (byte_counter < 11'd15)
                                        spi_tx_byte <= tag_reg[119 - byte_counter*8 -: 8];
                                    else
                                        state <= IDLE;
                                end
                                
                                default: state <= IDLE;
                            endcase
                        end
                    end
                endcase
            end
        end
    end
    
    //========================================================================
    // AES-GCM Core
    //========================================================================
    aes_gcm_top aes_core (
        .clk(clk),
        .rst(rst),
        .start(start_aes),
        .key(key_reg),
        .nonce(nonce_reg),
        .plaintext1(pt1_reg),
        .plaintext2(pt2_reg),
        .plaintext3(pt3_reg),
        .aad(aad_reg),
        .ciphertext1(ct1),
        .ciphertext2(ct2),
        .ciphertext3(ct3),
        .tag(tag),
        .done(done)
    );
    
    assign irq = done;


endmodule
