module sync_fifo #(
    parameter WIDTH = 8,          // 数据宽度
    parameter DEPTH = 64,         // FIFO深度
    parameter ADDR_WIDTH = 6      // 地址宽度（log2(DEPTH)）
)(
    input                     clk,        // 时钟
    input                     rst_n,      // 低电平有效复位
    input                     wr_en,      // 写使能
    input                     rd_en,      // 读使能
    input      [WIDTH-1:0]    data_in,    // 输入数据
    output     [WIDTH-1:0]    data_out,   // 输出数据
    output reg                empty,      // FIFO空标志
    output reg                full,       // FIFO满标志
    output reg                underflow,  // 下溢标志
    output reg                overflow,   // 上溢标志
    output reg [ADDR_WIDTH:0] data_count  // 数据计数器
);

    // 内部变量声明
    reg [WIDTH-1:0]      mem [0:DEPTH-1];  // 存储器阵列
    reg [ADDR_WIDTH-1:0] rd_ptr;           // 读指针
    reg [ADDR_WIDTH-1:0] wr_ptr;           // 写指针

    // 数据输出
    assign data_out = mem[rd_ptr];

    // 写指针逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end 
        else if (wr_en && !full) begin
            // 执行写入，更新写指针
            mem[wr_ptr] <= data_in;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // 读指针逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end 
        else if (rd_en && !empty) begin
            // 执行读取，更新读指针
            rd_ptr <= rd_ptr + 1;
        end
    end

    // 数据计数逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_count <= 0;
        end 
        else begin
            // 根据读写操作更新数据计数
            if (wr_en && !full && rd_en && !empty) begin
                // 同时读写，计数不变
                data_count <= data_count;
            end
            else if (wr_en && !full) begin
                // 只写不读，计数增加
                data_count <= data_count + 1;
            end
            else if (rd_en && !empty) begin
                // 只读不写，计数减少
                data_count <= data_count - 1;
            end
        end
    end

    // 下溢标志处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            underflow <= 0;
        end 
        else if (rd_en && empty) begin
            // 检测到下溢条件时置位
            underflow <= 1;
        end
        else begin
            // 没有下溢条件时清零（只持续一个周期）
            underflow <= 0;
        end
    end

    // 上溢标志处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            overflow <= 0;
        end 
        else if (wr_en && full) begin
            // 检测到上溢条件时置位
            overflow <= 1;
        end
        else begin
            // 没有上溢条件时清零（只持续一个周期）
            overflow <= 0;
        end
    end

    // empty标志更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            empty <= 1;  // 复位后FIFO为空
        end 
        else if (data_count == 0 || (data_count == 1 && rd_en && !wr_en)) begin
            empty <= 1;
        end 
        else begin
            empty <= 0;
        end
    end

    // full标志更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            full <= 0;  // 复位后FIFO不满
        end 
        else if (data_count == DEPTH || (data_count == DEPTH-1 && wr_en && !rd_en)) begin
            full <= 1;
        end 
        else begin
            full <= 0;
        end
    end

endmodule