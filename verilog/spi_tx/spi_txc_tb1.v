`timescale 1ns/1ps

module spi_txc_tb;

    // Parameters
    parameter CLK_PERIOD = 10; // 100MHz clock

    // DUT signals
    reg         sclk_tx;
    reg         spi_tx_rstn;
    reg [31:0]  spi_tx_data;
    reg [1:0]   df;
    reg [12:0]  spi_tnum;
    reg         lsbf;
    reg         crc_en;
    reg         txe;
    reg         rxonly;
    reg [31:0]  crc_poly;
    
    wire [31:0] crc_data_out;
    wire        tx_start;
    wire        tx_num_max_en;
    wire        shift_out;

    // Instantiate the DUT
    spi_txc u_spi_txc (
        .sclk_tx      (sclk_tx),
        .spi_tx_rstn  (spi_tx_rstn),
        .spi_tx_data  (spi_tx_data),
        .df           (df),
        .spi_tnum     (spi_tnum),
        .lsbf         (lsbf),
        .crc_en       (crc_en),
        .txe          (txe),
        .rxonly       (rxonly),
        .crc_poly     (crc_poly),
        .crc_data_out (crc_data_out),
        .tx_start     (tx_start),
        .tx_num_max_en(tx_num_max_en),
        .shift_out    (shift_out)
    );

    // Clock generation
    initial begin
        sclk_tx = 0;
        forever #(CLK_PERIOD/2) sclk_tx = ~sclk_tx;
    end

    // FSDB dump
    initial begin
        $fsdbDumpfile("spi_txc_tb.fsdb");
        $fsdbDumpvars(0, spi_txc_tb);
        $fsdbDumpMDA();
    end

    // Test sequence
    initial begin
        // Initial values
        spi_tx_rstn = 0;
        spi_tx_data = 32'h0;
        df = 2'b00;
        spi_tnum = 13'd0;
        lsbf = 1'b0;
        crc_en = 1'b0;
        txe = 1'b0;
        rxonly = 1'b0;
        crc_poly = 32'h04C11DB7; // Standard Ethernet CRC-32 polynomial
        
        // Reset sequence
        #(CLK_PERIOD*5);
        spi_tx_rstn = 1;
        #(CLK_PERIOD*2);
        
        // Test case 1: 8-bit transfer without CRC (MSB first)
        df = 2'b00;         // 8-bit mode
        spi_tnum = 13'd4;   // 5 frames
        lsbf = 1'b0;        // MSB first
        crc_en = 1'b0;      // No CRC
        txe = 1'b1;         // Transmit enable
        rxonly = 1'b0;      // Normal mode
        spi_tx_data = 32'h12345678;
        
        #(CLK_PERIOD*50);
        
        // Test case 2: 16-bit transfer without CRC (LSB first)
        df = 2'b01;         // 16-bit mode
        spi_tnum = 13'd2;   // 3 frames
        lsbf = 1'b1;        // LSB first
        crc_en = 1'b0;      // No CRC
        txe = 1'b1;         // Transmit enable
        rxonly = 1'b0;      // Normal mode
        spi_tx_data = 32'hAABBCCDD;
        
        #(CLK_PERIOD*50);
        
        // Test case 3: 32-bit transfer with CRC (MSB first)
        df = 2'b10;         // 32-bit mode
        spi_tnum = 13'd1;   // 2 frames
        lsbf = 1'b0;        // MSB first
        crc_en = 1'b1;      // With CRC
        txe = 1'b1;         // Transmit enable
        rxonly = 1'b0;      // Normal mode
        spi_tx_data = 32'h87654321;
        
        #(CLK_PERIOD*50);
        
        // Test case 4: Receive only mode
        df = 2'b00;         // 8-bit mode
        spi_tnum = 13'd0;   // 1 frame
        lsbf = 1'b0;        // MSB first
        crc_en = 1'b0;      // No CRC
        txe = 1'b1;         // Transmit enable
        rxonly = 1'b1;      // Receive only mode
        spi_tx_data = 32'hFFFFFFFF; // This should not be transmitted
        
        #(CLK_PERIOD*50);
        
        // Finish simulation
        #(CLK_PERIOD*10);
        $display("Simulation completed successfully");
        $finish;
    end

    // Monitor output
    initial begin
        $monitor("Time=%0t: shift_out=%b, tx_start=%b, tx_num_max_en=%b", 
                 $time, shift_out, tx_start, tx_num_max_en);
    end

endmodule