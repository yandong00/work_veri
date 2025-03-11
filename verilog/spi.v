module spi #(
    parameter MAX_DATA_WIDTH = 32,  // 最大数据位宽
    parameter CLK_DIV = 4           // 系统时钟分频比
)(
    // 系统信号
    input wire clk,           // 系统时钟
    input wire rst_n,         // 低电平复位
    
    // 配置接口
    input wire [$clog2(MAX_DATA_WIDTH):0] data_width,  // 实际数据位宽
    input wire lsb_first,     // 1: LSB优先, 0: MSB优先
    input wire receive_only,  // 1: 仅接收模式, 0: 正常收发模式
    input wire cpol,         // 时钟极性: 0-空闲低电平, 1-空闲高电平
    input wire cpha,         // 时钟相位: 0-第一个边沿采样, 1-第二个边沿采样
    input wire cs_sw_ctrl,   // CS控制模式选择: 1-软件控制, 0-硬件控制
    input wire cs_sw_value,  // 软件控制时的CS值
    
    // 控制接口
    input wire start,         // 开始传输信号
    input wire txe,          // 发送缓冲区空标志，0表示有新数据待发送
    input wire [MAX_DATA_WIDTH-1:0] tx_data,  // 要发送的数据
    output reg [MAX_DATA_WIDTH-1:0] rx_data,  // 接收到的数据
    output reg busy,          // 忙状态指示
    output reg done,          // 传输完成指示
    output reg tx_ready,      // 准备接收下一个发送数据
    
    // SPI接口
    output wire sclk,         // SPI时钟
    output reg mosi,          // 主机输出
    input wire miso,          // 主机输入
    output wire cs_n         // 片选信号，低电平有效
);

    // 状态机定义
    localparam IDLE = 2'b00;
    localparam TRANSFER = 2'b01;
    localparam DONE = 2'b10;
    localparam CHECK_NEXT = 2'b11;
    
    reg [1:0] state;
    reg [MAX_DATA_WIDTH-1:0] tx_shift;
    reg [MAX_DATA_WIDTH-1:0] rx_shift;
    reg [$clog2(MAX_DATA_WIDTH)-1:0] bit_cnt;
    reg [$clog2(CLK_DIV)-1:0] clk_cnt;
    reg sclk_en;
    reg sclk_reg;

    // CS输出控制逻辑
    reg cs_hw_value;  // 硬件控制的CS值

    // CS输出多路选择器
    assign cs_n = cs_sw_ctrl ? cs_sw_value : cs_hw_value;

    // SCLK生成
    assign sclk = cpol ? ~sclk_reg : sclk_reg;

    // 边沿检测信号
    wire sample_edge;
    wire shift_edge;
    assign sample_edge = cpha ? ~sclk_reg : sclk_reg;
    assign shift_edge = cpha ? sclk_reg : ~sclk_reg;

    // 用于MSB/LSB选择的位索引
    wire [$clog2(MAX_DATA_WIDTH)-1:0] current_bit_index;
    assign current_bit_index = lsb_first ? bit_cnt : (data_width - 1 - bit_cnt);

    // 时钟分频和SCLK生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            sclk_reg <= cpol;
            cs_hw_value <= 1;
        end else if (sclk_en) begin
            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt <= 0;
                sclk_reg <= ~sclk_reg;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end else begin
            clk_cnt <= 0;
            sclk_reg <= cpol;
        end
    end

    // 数据发送和接收逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 0;
            done <= 0;
            tx_ready <= 1;
            cs_hw_value <= 1;
            sclk_en <= 0;
            bit_cnt <= 0;
            tx_shift <= 0;
            rx_shift <= 0;
            rx_data <= 0;
            mosi <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= TRANSFER;
                        busy <= 1;
                        tx_ready <= 0;
                        cs_hw_value <= 0;
                        sclk_en <= 1;
                        bit_cnt <= 0;
                        tx_shift <= tx_data;
                        // 根据CPHA设置初始MOSI值
                        if (!cpha) begin
                            mosi <= receive_only ? 1'b0 : 
                                   (lsb_first ? tx_data[0] : tx_data[data_width-1]);
                        end
                    end
                end

                TRANSFER: begin
                    if (clk_cnt == CLK_DIV - 1) begin
                        // 采样边沿
                        if (sclk_reg == sample_edge) begin
                            if (lsb_first) begin
                                rx_shift[bit_cnt] <= miso;
                            end else begin
                                rx_shift[data_width-1-bit_cnt] <= miso;
                            end
                            
                            if (bit_cnt == data_width - 1) begin
                                state <= CHECK_NEXT;
                                rx_data <= rx_shift;
                                done <= 1;
                            end
                        end 
                        // 移位边沿
                        else if (sclk_reg == shift_edge && !receive_only) begin
                            if (bit_cnt < data_width - 1) begin
                                bit_cnt <= bit_cnt + 1;
                                mosi <= lsb_first ? 
                                       tx_shift[bit_cnt + 1] : 
                                       tx_shift[data_width-2-bit_cnt];
                            end
                        end
                    end
                end

                CHECK_NEXT: begin
                    done <= 0;
                    if (!txe) begin  // 有新数据待发送
                        state <= TRANSFER;
                        tx_ready <= 1;
                        bit_cnt <= 0;
                        tx_shift <= tx_data;
                        if (!cpha) begin
                            mosi <= receive_only ? 1'b0 : 
                                   (lsb_first ? tx_data[0] : tx_data[data_width-1]);
                        end
                    end else begin  // 没有新数据，结束传输
                        state <= DONE;
                    end
                end

                DONE: begin
                    state <= IDLE;
                    busy <= 0;
                    tx_ready <= 1;
                    cs_hw_value <= 1;
                    sclk_en <= 0;
                    mosi <= 0;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule