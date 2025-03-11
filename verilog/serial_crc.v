module serial_crc (
    input wire clk,
    input wire rst_n,
    input wire data_in,    // 串行输入数据
    input wire data_valid, // 数据有效信号
    input wire init,       // 初始化信号
    input wire [1:0] crc_mode, // CRC模式选择: 2'b00-CRC8, 2'b01-CRC16, 2'b10-CRC32
    input wire [31:0] polynomial, // CRC多项式，根据mode使用不同位宽
    output reg [31:0] crc_out    // CRC计算结果，根据mode使用不同位宽
);

    // 常用多项式参考值:
    // CRC-32: 0x04C11DB7
    // CRC-16: 0x8005
    // CRC-8:  0x07
    
    // CRC位宽和掩码的计算
    wire [4:0] crc_width;
    wire [31:0] crc_mask;
    
    assign crc_width = (crc_mode == 2'b00) ? 5'd8 :
                      (crc_mode == 2'b01) ? 5'd16 : 5'd32;
                      
    assign crc_mask = (crc_mode == 2'b00) ? 32'h000000FF :
                     (crc_mode == 2'b01) ? 32'h0000FFFF : 32'hFFFFFFFF;

    // 计算下一个CRC值
    wire [31:0] crc_shifted;
    wire feedback;
    wire [31:0] crc_next;
    
    assign crc_shifted = {crc_out[30:0], 1'b0};
    assign feedback = crc_out[crc_width-1] ^ data_in;
    assign crc_next = (feedback ? (crc_shifted ^ polynomial) : crc_shifted) & crc_mask;

    // CRC计算主逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_out <= crc_mask;  // 初始值全1，根据位宽设置
        end
        else if (init) begin
            crc_out <= crc_mask;  // 初始值全1，根据位宽设置
        end
        else if (data_valid) begin
            crc_out <= crc_next;
        end
    end

endmodule
