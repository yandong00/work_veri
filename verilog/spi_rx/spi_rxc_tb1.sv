`timescale 1ns/1ps

module spi_rxc_tb;

    // 参数定义
    parameter CLK_PERIOD = 10; // 100MHz时钟

    // 被测设备信号
    reg         clk_rx;
    reg         spi_rx_rstn;
    reg [1:0]   df;
    reg [12:0]  spi_tnum;
    reg         lsbf;
    reg         crc_en;
    reg         shift_in;
    reg [31:0]  crc_poly;
    
    wire [31:0] rx_crc_data_out;
    wire [31:0] spi_rx_data;
    wire        rx_num_max_en;
    wire        rx_busy;

    // 测试数据
    reg [31:0] test_data_8bit  = 32'hA5;
    reg [31:0] test_data_16bit = 32'hB971;
    reg [31:0] test_data_32bit = 32'hC3D2F1E8;

    // 实例化被测设备
    spi_rxc u_spi_rxc (
        .clk_rx         (clk_rx),
        .spi_rx_rstn    (spi_rx_rstn),
        .df             (df),
        .spi_tnum       (spi_tnum),
        .lsbf           (lsbf),
        .crc_en         (crc_en),
        .shift_in       (shift_in),
        .crc_poly       (crc_poly),
        .rx_crc_data_out(rx_crc_data_out),
        .spi_rx_data    (spi_rx_data),
        .rx_num_max_en  (rx_num_max_en),
        .rx_busy        (rx_busy)
    );

    // 生成时钟信号
    initial begin
        clk_rx = 0;
        forever #(CLK_PERIOD/2) clk_rx = ~clk_rx;
    end

    // FSDB波形文件输出设置
    initial begin
        $fsdbDumpfile("spi_rxc_tb.fsdb");
        $fsdbDumpvars(0, spi_rxc_tb);
        $fsdbDumpMDA();
    end

    // 发送比特序列任务
    task send_bits;
        input [31:0] data;
        input integer bits;
        input  is_lsb_first;
        integer i;
        begin
            for (i = 0; i < bits; i = i + 1) begin
                if (is_lsb_first)
                    shift_in = data[i];
                else
                    shift_in = data[bits-1-i];
                    
                @(posedge clk_rx);
            end
        end
    endtask

    // 测试序列
    initial begin
        // 初始值设置
        clk_rx = 0;
        spi_rx_rstn = 0;
        df = 2'b00;
        spi_tnum = 13'd0;
        lsbf = 1'b0;
        crc_en = 1'b0;
        shift_in = 1'b0;
        crc_poly = 32'h04C11DB7; // 标准以太网CRC-32多项式
        
        // 复位序列
        #(CLK_PERIOD*5);
        spi_rx_rstn = 1;
        #(CLK_PERIOD*2);
        
        // 测试用例1: 8位数据接收 (MSB优先)
        $display("测试用例1: 8位数据接收 (MSB优先)");
        df = 2'b00;         // 8位模式
        spi_tnum = 13'd1;   // 2帧
        lsbf = 1'b0;        // MSB优先
        crc_en = 1'b0;      // 无CRC
        
        send_bits(test_data_8bit, 8, 0);
        #(CLK_PERIOD*2);
        $display("接收数据: %h", spi_rx_data);
        
        // 测试用例2: 16位数据接收 (LSB优先)
        $display("测试用例2: 16位数据接收 (LSB优先)");
        df = 2'b01;         // 16位模式
        spi_tnum = 13'd1;   // 2帧
        lsbf = 1'b1;        // LSB优先
        crc_en = 1'b0;      // 无CRC
        
        send_bits(test_data_16bit, 16, 1);
        #(CLK_PERIOD*2);
        $display("接收数据: %h", spi_rx_data);
        
        // 测试用例3: 32位数据接收 (MSB优先)
        $display("测试用例3: 32位数据接收 (MSB优先)");
        df = 2'b10;         // 32位模式
        spi_tnum = 13'd1;   // 2帧
        lsbf = 1'b0;        // MSB优先
        crc_en = 1'b0;      // 无CRC
        
        send_bits(test_data_32bit, 32, 0);
        #(CLK_PERIOD*2);
        $display("接收数据: %h", spi_rx_data);
        
        // 测试用例4: 带CRC的多帧接收
        $display("测试用例4: 带CRC的多帧接收");
        df = 2'b00;         // 8位模式
        spi_tnum = 13'd3;   // 4帧
        lsbf = 1'b0;        // MSB优先
        crc_en = 1'b1;      // 启用CRC
        
        send_bits(32'hA1, 8, 0);
        #(CLK_PERIOD*2);
        $display("帧1接收数据: %h", spi_rx_data);
        
        send_bits(32'hB2, 8, 0);
        #(CLK_PERIOD*2);
        $display("帧2接收数据: %h", spi_rx_data);
        
        send_bits(32'hC3, 8, 0);
        #(CLK_PERIOD*2);
        $display("帧3接收数据: %h", spi_rx_data);
        
        send_bits(32'hD4, 8, 0);
        #(CLK_PERIOD*2);
        $display("帧4接收数据: %h", spi_rx_data);
        $display("CRC计算结果: %h", rx_crc_data_out);
        
        // 完成仿真
        #(CLK_PERIOD*10);
        $display("仿真成功完成");
        $finish;
    end

    // 监控输出
    initial begin
        $monitor("时间=%0t: 接收数据=%h, rx_busy=%b, rx_num_max_en=%b", 
                 $time, spi_rx_data, rx_busy, rx_num_max_en);
    end

endmodule
