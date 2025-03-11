module i2c_master #(
    parameter CLK_FREQ = 50_000_000,  // 系统时钟频率 (Hz)
    parameter I2C_FREQ = 100_000,     // I2C时钟频率 (Hz)
    parameter MAX_BYTES = 256         // 最大传输字节数
)(
    // 系统信号
    input wire clk,           // 系统时钟
    input wire rst_n,         // 低电平复位
    
    // 控制接口
    input wire start,         // 开始传输
    input wire rw,           // 1:读, 0:写
    input wire [7:0] addr,   // 从机地址(7位)
    input wire [7:0] reg_addr, // 起始寄存器地址
    input wire [7:0] byte_count, // 要传输的字节数
    
    // 数据接口
    input wire [7:0] wdata,      // 写数据输入
    input wire wdata_valid,      // 写数据有效
    output reg wdata_req,        // 写数据请求
    output reg [7:0] rdata,      // 读数据输出
    output reg rdata_valid,      // 读数据有效
    
    // 状态指示
    output reg busy,             // 忙状态指示
    output reg done,             // 传输完成指示
    output reg ack_error,        // 应答错误指示
    output reg irq,              // 中断请求
    
    // I2C接口
    output reg scl,              // I2C时钟线
    inout wire sda              // I2C数据线
);

    // I2C时钟分频参数
    localparam CLKS_PER_HALF_BIT = (CLK_FREQ / (2 * I2C_FREQ)) - 1;
    
    // 状态机定义
    localparam IDLE = 4'd0;
    localparam START = 4'd1;
    localparam ADDR = 4'd2;
    localparam ACK1 = 4'd3;
    localparam REG = 4'd4;
    localparam ACK2 = 4'd5;
    localparam RESTART = 4'd6;
    localparam ADDR_R = 4'd7;
    localparam ACK3 = 4'd8;
    localparam DATA = 4'd9;
    localparam ACK4 = 4'd10;
    localparam STOP = 4'd11;
    
    reg [3:0] state;
    reg [15:0] clk_cnt;          // 时钟计数器
    reg [3:0] bit_cnt;           // 位计数器
    reg [7:0] byte_cnt;          // 字节计数器
    reg sda_out;                 // SDA输出控制
    reg sda_oen;                 // SDA输出使能
    reg [7:0] shift_reg;         // 移位寄存器
    reg scl_enable;              // SCL使能
    reg [7:0] current_reg_addr;  // 当前寄存器地址
    
    // SDA三态控制
    assign sda = sda_oen ? 1'bz : sda_out;
    wire sda_in = sda;
    
    // SCL生成逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            scl <= 1;
        end else if (scl_enable) begin
            if (clk_cnt == CLKS_PER_HALF_BIT) begin
                clk_cnt <= 0;
                scl <= ~scl;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end else begin
            clk_cnt <= 0;
            scl <= 1;
        end
    end

    // 中断请求生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            irq <= 0;
        end else begin
            if (state == DATA && clk_cnt == 0 && scl && bit_cnt == 0) begin
                irq <= 1;  // 每完成一个字节传输产生中断
            end else if (state == IDLE) begin
                irq <= 0;  // 回到空闲状态清除中断
            end
        end
    end

    // 主状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 0;
            done <= 0;
            ack_error <= 0;
            sda_out <= 1;
            sda_oen <= 1;
            bit_cnt <= 0;
            byte_cnt <= 0;
            shift_reg <= 0;
            rdata <= 0;
            rdata_valid <= 0;
            wdata_req <= 0;
            scl_enable <= 0;
            current_reg_addr <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= START;
                        busy <= 1;
                        done <= 0;
                        ack_error <= 0;
                        scl_enable <= 1;
                        byte_cnt <= byte_count;
                        current_reg_addr <= reg_addr;
                    end
                    rdata_valid <= 0;
                    wdata_req <= 0;
                end

                START: begin
                    if (clk_cnt == 0) begin
                        if (scl) begin
                            sda_out <= 0;  // 开始条件
                            sda_oen <= 0;
                        end else begin
                            state <= ADDR;
                            bit_cnt <= 7;
                            shift_reg <= {addr, 1'b0};  // 地址 + 写位
                        end
                    end
                end

                ADDR: begin
                    if (clk_cnt == 0) begin
                        if (!scl) begin
                            sda_out <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            if (bit_cnt == 0) begin
                                state <= ACK1;
                                sda_oen <= 1;
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                            end
                        end
                    end
                end

                ACK1: begin
                    if (clk_cnt == 0 && scl) begin
                        if (sda_in) begin  // 无应答
                            state <= STOP;
                            ack_error <= 1;
                        end else begin
                            state <= REG;
                            bit_cnt <= 7;
                            shift_reg <= current_reg_addr;
                            sda_oen <= 0;
                        end
                    end
                end

                REG: begin
                    if (clk_cnt == 0) begin
                        if (!scl) begin
                            sda_out <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            if (bit_cnt == 0) begin
                                state <= ACK2;
                                sda_oen <= 1;
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                            end
                        end
                    end
                end

                ACK2: begin
                    if (clk_cnt == 0 && scl) begin
                        if (sda_in) begin
                            state <= STOP;
                            ack_error <= 1;
                        end else if (rw) begin
                            state <= RESTART;
                            sda_oen <= 0;
                        end else begin
                            state <= DATA;
                            bit_cnt <= 7;
                            wdata_req <= 1;  // 请求第一个写数据
                            sda_oen <= 0;
                        end
                    end
                end

                RESTART: begin
                    if (clk_cnt == 0) begin
                        if (!scl) begin
                            sda_out <= 1;
                        end else begin
                            state <= START;
                            shift_reg <= {addr, 1'b1};  // 地址 + 读位
                        end
                    end
                end

                DATA: begin
                    if (clk_cnt == 0) begin
                        if (!scl) begin
                            if (rw) begin
                                sda_oen <= 1;  // 读模式释放SDA
                            end else if (wdata_valid) begin
                                shift_reg <= wdata;
                                sda_out <= wdata[7];
                                sda_oen <= 0;
                                wdata_req <= 0;
                            end
                            if (bit_cnt == 0) begin
                                state <= ACK4;
                                if (!rw) sda_oen <= 1;
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                                if (!rw) begin
                                    shift_reg <= {shift_reg[6:0], 1'b0};
                                end
                            end
                        end else if (rw) begin
                            shift_reg <= {shift_reg[6:0], sda_in};
                        end
                    end
                end

                ACK4: begin
                    if (clk_cnt == 0 && scl) begin
                        if (rw) begin
                            rdata <= shift_reg;
                            rdata_valid <= 1;
                            sda_out <= (byte_cnt == 1) ? 1'b1 : 1'b0;  // 最后一个字节发送NACK
                            sda_oen <= 0;
                        end else if (sda_in) begin
                            ack_error <= 1;
                            state <= STOP;
                        end
                        
                        if (byte_cnt > 1 && !ack_error) begin
                            byte_cnt <= byte_cnt - 1;
                            current_reg_addr <= current_reg_addr + 1;
                            state <= DATA;
                            bit_cnt <= 7;
                            if (!rw) wdata_req <= 1;
                        end else begin
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (clk_cnt == 0) begin
                        if (!scl) begin
                            sda_out <= 0;
                            sda_oen <= 0;
                        end else begin
                            sda_out <= 1;  // 停止条件
                            state <= IDLE;
                            busy <= 0;
                            done <= 1;
                            scl_enable <= 0;
                        end
                    end
                end

            endcase
        end
    end

endmodule