module spi_tx_ctrl (
    input wire clk,                  // 系统时钟
    input wire rst_n,                // 低电平复位
    input wire [31:0] data_in,       // 输入数据，最大32位
    input wire [31:0] crc_data,      // CRC数据输入
    input wire [4:0] data_len,       // 数据长度配置 (8-32)
    input wire txe,                  // 发送使能信号，低电平有效
    input wire tx_cnt_max,           // CRC加载控制信号
    
    output reg data_out,             // 串行数据输出
    output reg txe_flag,             // 当bit_cnt=1时拉高的指示信号
    output reg tx_done,              // 全部数据发送完成
    output reg [4:0] bit_count       // 当前已发送的位数计数器
);

    reg [4:0] bit_cnt;               // 位计数器
    reg [31:0] shift_reg;            // 移位寄存器
    reg [4:0] tx_len;                // 存储当前传输的数据长度
    
    // bit_cnt 计数器逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt <= 5'd0;
        end else begin
            bit_cnt <= (bit_cnt == tx_len - 1) ? 5'd0 : bit_cnt + 1'b1;
        end
    end
    
    // bit_count 输出逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count <= 5'd0;
        end else begin
            bit_count <= bit_cnt;
        end
    end
    
    // shift_reg 移位寄存器逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 32'd0;
        end else if (tx_cnt_max == 1'b1 && bit_cnt == 5'd0) begin
            // 当tx_cnt_max为1且bit_cnt为0时，优先加载crc_data
            shift_reg <= crc_data;
        end else if (bit_cnt == 5'd0 && txe == 1'b0) begin
            // 在计数值为0且txe为低时加载新数据
            shift_reg <= data_in;
        end else begin
            // 正常移位操作
            shift_reg <= {1'b0, shift_reg[31:1]};
        end
    end
    
    // data_out 输出逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 1'b0;
        end else begin
            data_out <= shift_reg[0];
        end
    end
    
    // txe_flag 标志逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            txe_flag <= 1'b0;
        end else begin
            txe_flag <= (bit_cnt == 5'd1);
        end
    end
    
    // tx_done 完成标志逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_done <= 1'b0;
        end else begin
            tx_done <= (bit_cnt == tx_len - 1);
        end
    end
    
    // tx_len 数据长度逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_len <= 5'd8;  // 默认最小长度
        end else if (bit_cnt == 5'd0 && txe == 1'b0) begin
            // 在计数值为0且txe为低时更新数据长度
            if (data_len < 5'd8)
                tx_len <= 5'd8;
            else if (data_len > 5'd32)
                tx_len <= 5'd32;
            else
                tx_len <= data_len;
        end
    end

endmodule
