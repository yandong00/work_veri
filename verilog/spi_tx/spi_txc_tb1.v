`timescale 1ns/1ps

module spi_txc_tb;

// 参数定义
parameter CLK_PERIOD = 10;  // 时钟周期为10ns (100MHz)

// 被测试模块的信号
reg         sclk_tx;
reg         spi_tx_rstn;
reg  [31:0] spi_tx_data;
reg  [1:0]  df;
reg  [12:0] spi_tnum_max;
reg         lsbf;
reg         crc_en;
reg         rxonly;
reg  [31:0] crc_poly;
wire [31:0] tx_crc_data_out;
wire        tx_start;
wire        tx_num_max_en;
wire        tx_crc_en;
wire        shift_out;

// 实例化被测试模块
spi_txc u_spi_txc (
    .sclk_tx          (sclk_tx),
    .spi_tx_rstn      (spi_tx_rstn),
    .spi_tx_data      (spi_tx_data),
    .df               (df),
    .spi_tnum_max     (spi_tnum_max),
    .lsbf             (lsbf),
    .crc_en           (crc_en),
    .rxonly           (rxonly),
    .crc_poly         (crc_poly),
    .tx_crc_data_out  (tx_crc_data_out),
    .tx_start         (tx_start),
    .tx_num_max_en    (tx_num_max_en),
    .tx_crc_en        (tx_crc_en),
    .shift_out        (shift_out)
);

// FSDB波形文件输出设置
initial begin
    $fsdbDumpfile("spi_txc_tb.fsdb");
    $fsdbDumpvars(0, spi_txc_tb);
    $fsdbDumpMDA();
end

// 控制局部变量
reg clock_enable = 0;  // 控制时钟是否运行
integer i;

// 时钟生成器 - 只在clock_enable=1时产生时钟
always begin
    if (clock_enable) begin
        sclk_tx = 0;
        #(CLK_PERIOD/2);
        sclk_tx = 1;
        #(CLK_PERIOD/2);
    end else begin
        sclk_tx = 0;
        #(CLK_PERIOD);
    end
end

// 测试任务：初始化信号
task initialize;
    begin
        clock_enable = 0;
        sclk_tx = 0;
        spi_tx_rstn = 0;  // 初始复位
        spi_tx_data = 32'h0;
        df = 2'b00;       // 默认8位模式
        spi_tnum_max = 13'h1;
        lsbf = 0;         // MSB优先
        crc_en = 0;       // CRC禁用
        rxonly = 0;       // 非只接收模式
        crc_poly = 32'h04C11DB7;  // 标准CRC-32多项式
        
        #100;
        spi_tx_rstn = 1;  // 释放复位
        #50;
    end
endtask

// 测试任务：复位模块
task reset_module;
    begin
        $display("【复位模块】");
        clock_enable = 0;
        spi_tx_rstn = 0;
        #100;
        spi_tx_rstn = 1;
        #50;
    end
endtask

// 测试任务：发送数据
task send_data;
    input [31:0] data;
    input [1:0]  data_format;
    input        is_lsbf;
    input [5:0]  cycles;
    begin
        $display("【发送数据】data=0x%h, 格式=%d, LSB优先=%d", data, data_format, is_lsbf);
        spi_tx_data = data;
        df = data_format;
        lsbf = is_lsbf;
        
        clock_enable = 1;  // 启动时钟
        
        // 等待指定的时钟周期
        for (i = 0; i < cycles; i = i + 1) begin
            @(posedge sclk_tx);
        end
        
        clock_enable = 0;  // 停止时钟
        #50;
    end
endtask

// 测试任务：测试CRC功能
task test_crc;
    input [31:0] data;
    input [1:0]  data_format;
    input [12:0] tnum_max;
    input [31:0] polynomial;
    input [5:0]  cycles;
    begin
        $display("【测试CRC】data=0x%h, 格式=%d, 最大帧数=%d", data, data_format, tnum_max);
        spi_tx_data = data;
        df = data_format;
        spi_tnum_max = tnum_max;
        crc_en = 1;
        crc_poly = polynomial;
        
        clock_enable = 1;  // 启动时钟
        
        // 等待指定的时钟周期
        for (i = 0; i < cycles; i = i + 1) begin
            @(posedge sclk_tx);
        end
        
        clock_enable = 0;  // 停止时钟
        #50;
    end
endtask

// 测试任务：测试只接收模式
task test_rxonly;
    input [5:0] cycles;
    begin
        $display("【测试只接收模式】");
        rxonly = 1;
        
        clock_enable = 1;  // 启动时钟
        
        // 等待指定的时钟周期
        for (i = 0; i < cycles; i = i + 1) begin
            @(posedge sclk_tx);
        end
        
        clock_enable = 0;  // 停止时钟
        rxonly = 0;
        #50;
    end
endtask

// 主测试流程
initial begin
    $display("【SPI发送控制器测试开始】");
    
    // 初始化
    initialize;
    
    // 测试项1：8位模式，MSB优先
    send_data(32'h12345678, 2'b00, 0, 20);
    reset_module();
    
    // 测试项2：8位模式，LSB优先
    send_data(32'h12345678, 2'b00, 1, 20);
    reset_module();
    
    // 测试项3：16位模式，MSB优先
    send_data(32'hAABBCCDD, 2'b01, 0, 30);
    reset_module();
    
    // 测试项4：32位模式，MSB优先
    send_data(32'h55AA55AA, 2'b10, 0, 50);
    reset_module();
    
    // 测试项5：测试CRC功能（8位模式）
    test_crc(32'h12345678, 2'b00, 13'h1, 32'h04C11DB7, 40);
    reset_module();
    
    // 测试项6：测试CRC功能（16位模式）
    test_crc(32'hAABBCCDD, 2'b01, 13'h2, 32'h1021, 60);  // CRC-16
    reset_module();
    
    // 测试项7：测试只接收模式
    test_rxonly(20);
    
    $display("【SPI发送控制器测试完成】");
    $finish;
end

// 监视输出信号
initial begin
    $monitor("时间=%t: shift_out=%b, tx_start=%b, tx_num_max_en=%b, tx_crc_en=%b", 
             $time, shift_out, tx_start, tx_num_max_en, tx_crc_en);
end

endmodule
