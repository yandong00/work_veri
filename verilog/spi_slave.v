module spi_slave #(
    parameter MAX_DATA_WIDTH = 32  // 最大数据位宽
)(
    // 系统信号
    input wire clk,           // 系统时钟
    input wire rst_n,         // 低电平复位
    
    // 配置接口
    input wire [$clog2(MAX_DATA_WIDTH):0] data_width,  // 实际数据位宽
    input wire lsb_first,     // 1: LSB优先, 0: MSB优先
    input wire cpol,         // 时钟极性
    input wire cpha,         // 时钟相位
    
    // 数据接口
    input wire [MAX_DATA_WIDTH-1:0] tx_data,  // 要发送的数据
    output reg [MAX_DATA_WIDTH-1:0] rx_data,  // 接收到的数据
    output reg rx_valid,      // 接收数据有效
    output reg tx_ready,      // 准备接收下一个发送数据
    
    // SPI接口
    input wire sclk,          // SPI时钟输入
    input wire mosi,          // 主机输出，从机输入
    output reg miso,          // 从机输出，主机输入
    input wire cs_n          // 片选信号输入，低电平有效
);

    // 状态机定义
    localparam IDLE = 2'b00;
    localparam TRANSFER = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [MAX_DATA_WIDTH-1:0] tx_shift;
    reg [MAX_DATA_WIDTH-1:0] rx_shift_sclk;  // SCLK域的接收移位寄存器
    reg [MAX_DATA_WIDTH-1:0] rx_shift;       // CLK域的接收移位寄存器
    reg [$clog2(MAX_DATA_WIDTH)-1:0] bit_cnt;
    reg rx_done_sclk;                        // SCLK域的接收完成标志
    reg [2:0] rx_done_sync;                  // 接收完成标志同步器

    // CS同步寄存器（防止亚稳态）
    reg [2:0] cs_n_sync;
    wire cs_n_posedge = cs_n_sync[2:1] == 2'b01;
    wire cs_n_negedge = cs_n_sync[2:1] == 2'b10;

    // 添加传输完成标志
    reg transfer_done;        // 单次传输完成标志
    reg data_stored;         // 数据已存储标志

    // CLK域同步逻辑
    always @(posedge clk) begin
        cs_n_sync <= {cs_n_sync[1:0], cs_n};
        rx_done_sync <= {rx_done_sync[1:0], rx_done_sclk};
    end

    // SCLK域的数据采样和发送逻辑
    wire sclk_internal = cpol ? ~sclk : sclk;  // 根据CPOL调整时钟极性

    // SCLK采样逻辑
    always @(posedge sclk_internal or negedge rst_n) begin
        if (!rst_n) begin
            if (!cpha) begin
                rx_shift_sclk <= 0;
                bit_cnt <= 0;
                rx_done_sclk <= 0;
            end
        end else if (!cs_n) begin
            if (!cpha) begin
                // 采样MOSI
                if (lsb_first) begin
                    rx_shift_sclk[bit_cnt] <= mosi;
                end else begin
                    rx_shift_sclk[data_width-1-bit_cnt] <= mosi;
                end
                
                // 位计数器和完成标志控制
                if (bit_cnt == data_width - 1) begin
                    bit_cnt <= 0;
                    rx_done_sclk <= 1;
                end else begin
                    bit_cnt <= bit_cnt + 1;
                    rx_done_sclk <= 0;
                end
            end
        end else begin
            rx_done_sclk <= 0;  // CS无效时清除完成标志
        end
    end

    // SCLK发送逻辑
    always @(negedge sclk_internal or negedge rst_n) begin
        if (!rst_n) begin
            if (cpha) begin
                rx_shift_sclk <= 0;
                bit_cnt <= 0;
                rx_done_sclk <= 0;
            end
            miso <= 0;
        end else if (!cs_n) begin
            if (cpha) begin
                // 采样MOSI
                if (lsb_first) begin
                    rx_shift_sclk[bit_cnt] <= mosi;
                end else begin
                    rx_shift_sclk[data_width-1-bit_cnt] <= mosi;
                end
                
                // 位计数器和完成标志控制
                if (bit_cnt == data_width - 1) begin
                    bit_cnt <= 0;
                    rx_done_sclk <= 1;
                end else begin
                    bit_cnt <= bit_cnt + 1;
                    rx_done_sclk <= 0;
                end
            end

            // 更新MISO输出
            if (!cpha || bit_cnt > 0) begin
                miso <= lsb_first ? 
                       tx_shift[bit_cnt] : 
                       tx_shift[data_width-1-bit_cnt];
            end
        end
    end

    // CLK域的控制逻辑 - 修改以支持连续接收和存储
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rx_valid <= 0;
            tx_ready <= 1;
            tx_shift <= 0;
            rx_shift <= 0;
            rx_data <= 0;
            transfer_done <= 0;
            data_stored <= 0;
        end else begin
            case (state)
                IDLE: begin
                    rx_valid <= 0;
                    data_stored <= 0;
                    if (cs_n_negedge) begin  // CS激活
                        state <= TRANSFER;
                        tx_ready <= 0;
                        tx_shift <= tx_data;
                        if (!cpha) begin
                            miso <= lsb_first ? tx_data[0] : tx_data[data_width-1];
                        end
                    end
                end

                TRANSFER: begin
                    // 检测到一笔数据接收完成
                    if (rx_done_sync[2] && !rx_done_sync[1] && !data_stored) begin
                        // 存储接收到的数据
                        rx_data <= rx_shift_sclk;
                        rx_valid <= 1;
                        data_stored <= 1;  // 标记数据已存储
                        tx_ready <= 1;     // 准备接收下一笔发送数据
                    end else if (data_stored) begin
                        // 清除数据有效标志，准备接收下一笔
                        rx_valid <= 0;
                        data_stored <= 0;
                        // 加载新的发送数据
                        if (tx_ready) begin
                            tx_shift <= tx_data;
                            tx_ready <= 0;
                        end
                    end

                    // 检测CS停止
                    if (cs_n_posedge) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    state <= IDLE;
                    rx_valid <= 0;
                    tx_ready <= 1;
                    data_stored <= 0;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule