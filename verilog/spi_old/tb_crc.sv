`timescale 1ns/1ps

module tb_serial_crc();
    // 测试平台信号
    reg clk;
    reg rst_n;
    reg data_in;
    reg data_valid;
    reg init;
    reg [1:0] crc_mode;     // 00-CRC8, 01-CRC16, 10-CRC32
    reg [31:0] polynomial;  // 扩展到32位以支持CRC32
    wire [31:0] crc_out;    // 扩展到32位以支持CRC32
    
    // 用于测试的变量
    reg [31:0] test_data;
    integer i;
    reg [31:0] expected_crc;
    
    // 实例化被测试模块 - 假设已修改以支持CRC32
    serial_crc u_serial_crc (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_valid(data_valid),
        .init(init),
        .crc_mode(crc_mode),
        .polynomial(polynomial),
        .crc_out(crc_out)
    );
    
    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz时钟
    end
    
    // 测试过程
    initial begin
        // 初始化
        rst_n = 0;
        data_in = 0;
        data_valid = 0;
        init = 0;
        crc_mode = 2'b00;
        polynomial = 32'h00000000;
        
        // 复位
        #20;
        rst_n = 1;
        #10;
        
        // 测试1：CRC-8计算
        $display("测试1：CRC-8计算");
        crc_mode = 2'b00;           // CRC-8模式
        polynomial = 32'h00000007;  // CRC-8多项式 (0x07)
        test_data = 32'h12345678;
        expected_crc = 32'h000000DF; // 预期的CRC-8值
        
        // 初始化CRC
        @(posedge clk);
        init = 1;
        @(posedge clk);
        init = 0;
        
        // 串行输入测试数据
        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk);
            data_in = test_data[31-i];
            data_valid = 1;
            @(posedge clk);
        end
        data_valid = 0;
        
        // 验证CRC-8结果
        #10;
        $display("CRC-8计算结果: 0x%h, 预期: 0x%h, %s", 
                 crc_out & 32'h000000FF, 
                 expected_crc & 32'h000000FF, 
                 ((crc_out & 32'h000000FF) == (expected_crc & 32'h000000FF)) ? "通过" : "失败");
        
        // 测试2：CRC-16计算
        $display("测试2：CRC-16计算");
        crc_mode = 2'b01;            // CRC-16模式
        polynomial = 32'h00008005;   // CRC-16多项式 (0x8005)
        test_data = 32'hAABBCCDD;
        expected_crc = 32'h0000BB3D; // 预期的CRC-16值
        
        // 初始化CRC
        @(posedge clk);
        init = 1;
        @(posedge clk);
        init = 0;
        
        // 串行输入测试数据
        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk);
            data_in = test_data[31-i];
            data_valid = 1;
            @(posedge clk);
        end
        data_valid = 0;
        
        // 验证CRC-16结果
        #10;
        $display("CRC-16计算结果: 0x%h, 预期: 0x%h, %s", 
                 crc_out & 32'h0000FFFF, 
                 expected_crc & 32'h0000FFFF, 
                 ((crc_out & 32'h0000FFFF) == (expected_crc & 32'h0000FFFF)) ? "通过" : "失败");
        
        // 测试3：CRC-32计算
        $display("测试3：CRC-32计算");
        crc_mode = 2'b10;            // CRC-32模式
        polynomial = 32'h04C11DB7;   // CRC-32标准多项式
        test_data = 32'h01234567;
        expected_crc = 32'hCBF43926; // 预期的CRC-32值
        
        // 初始化CRC
        @(posedge clk);
        init = 1;
        @(posedge clk);
        init = 0;
        
        // 串行输入测试数据
        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk);
            data_in = test_data[31-i];
            data_valid = 1;
            @(posedge clk);
        end
        data_valid = 0;
        
        // 验证CRC-32结果
        #10;
        $display("CRC-32计算结果: 0x%h, 预期: 0x%h, %s", 
                 crc_out, 
                 expected_crc, 
                 (crc_out == expected_crc) ? "通过" : "失败");
        
        // 测试4：不同多项式测试
        $display("测试4：不同多项式测试");
        // CRC-8自定义多项式
        crc_mode = 2'b00;
        polynomial = 32'h0000001D;  // 不同的CRC-8多项式
        test_data = 32'h55AA55AA;
        expected_crc = 32'h00000017; // 预期值
        
        // 初始化CRC
        @(posedge clk);
        init = 1;
        @(posedge clk);
        init = 0;
        
        // 串行输入测试数据
        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk);
            data_in = test_data[31-i];
            data_valid = 1;
            @(posedge clk);
        end
        data_valid = 0;
        
        #10;
        $display("使用多项式0x%h的CRC-8结果: 0x%h", polynomial, crc_out & 32'h000000FF);
        
        // CRC-32自定义多项式
        crc_mode = 2'b10;
        polynomial = 32'h82F63B78;  // CRC-32C (Castagnoli)多项式
        test_data = 32'h55AA55AA;
        expected_crc = 32'h4851927D; // 预期值
        
        // 初始化CRC
        @(posedge clk);
        init = 1;
        @(posedge clk);
        init = 0;
        
        // 串行输入测试数据
        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk);
            data_in = test_data[31-i];
            data_valid = 1;
            @(posedge clk);
        end
        data_valid = 0;
        
        #10;
        $display("使用多项式0x%h的CRC-32结果: 0x%h", polynomial, crc_out);
        
        // 测试5：自动化测试用例
        $display("测试5：自动化测试");
        
        // 各种CRC测试向量
        automatic struct {
            reg [1:0] mode;
            reg [31:0] poly;
            reg [31:0] data;
            reg [31:0] expected;
        } test_vectors[0:8];
        
        // CRC-8测试向量
        test_vectors[0] = '{2'b00, 32'h00000007, 32'h00000000, 32'h000000FF}; // 全0输入
        test_vectors[1] = '{2'b00, 32'h00000007, 32'hFFFFFFFF, 32'h000000FF}; // 全1输入
        test_vectors[2] = '{2'b00, 32'h00000007, 32'h12345678, 32'h000000DF}; // 随机数据
        
        // CRC-16测试向量
        test_vectors[3] = '{2'b01, 32'h00008005, 32'h00000000, 32'h0000FFFF}; // 全0输入
        test_vectors[4] = '{2'b01, 32'h00008005, 32'hFFFFFFFF, 32'h0000FFFF}; // 全1输入
        test_vectors[5] = '{2'b01, 32'h00008005, 32'hAABBCCDD, 32'h0000BB3D}; // 随机数据
        
        // CRC-32测试向量
        test_vectors[6] = '{2'b10, 32'h04C11DB7, 32'h00000000, 32'hFFFFFFFF}; // 全0输入
        test_vectors[7] = '{2'b10, 32'h04C11DB7, 32'hFFFFFFFF, 32'hFFFFFFFF}; // 全1输入
        test_vectors[8] = '{2'b10, 32'h04C11DB7, 32'h01234567, 32'hCBF43926}; // 随机数据
        
        for (i = 0; i < 9; i = i + 1) begin
            crc_mode = test_vectors[i].mode;
            polynomial = test_vectors[i].poly;
            test_data = test_vectors[i].data;
            expected_crc = test_vectors[i].expected;
            
            // 初始化CRC
            @(posedge clk);
            init = 1;
            @(posedge clk);
            init = 0;
            
            // 串行输入测试数据
            for (integer j = 0; j < 32; j = j + 1) begin
                @(posedge clk);
                data_in = test_data[31-j];
                data_valid = 1;
                @(posedge clk);
            end
            data_valid = 0;
            
            // 验证CRC结果
            #10;
            case (crc_mode)
                2'b00: begin // CRC-8
                    $display("测试向量 %0d (CRC-8): 输入=0x%h, 结果=0x%h, 预期=0x%h, %s", 
                        i, test_data, crc_out & 32'h000000FF, expected_crc & 32'h000000FF,
                        ((crc_out & 32'h000000FF) == (expected_crc & 32'h000000FF)) ? "通过" : "失败");
                end
                2'b01: begin // CRC-16
                    $display("测试向量 %0d (CRC-16): 输入=0x%h, 结果=0x%h, 预期=0x%h, %s", 
                        i, test_data, crc_out & 32'h0000FFFF, expected_crc & 32'h0000FFFF,
                        ((crc_out & 32'h0000FFFF) == (expected_crc & 32'h0000FFFF)) ? "通过" : "失败");
                end
                2'b10: begin // CRC-32
                    $display("测试向量 %0d (CRC-32): 输入=0x%h, 结果=0x%h, 预期=0x%h, %s", 
                        i, test_data, crc_out, expected_crc,
                        (crc_out == expected_crc) ? "通过" : "失败");
                end
            endcase
        end
        
        // 测试6：连续数据处理
        $display("测试6：连续数据处理");
        crc_mode = 2'b10;            // CRC-32模式
        polynomial = 32'h04C11DB7;   // CRC-32多项式
        
        // 初始化CRC
        @(posedge clk);
        init = 1;
        @(posedge clk);
        init = 0;
        
        // 第一个数据块
        test_data = 32'h11223344;
        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk);
            data_in = test_data[31-i];
            data_valid = 1;
            @(posedge clk);
        end
        
        // 第二个数据块（不重置CRC）
        test_data = 32'h55667788;
        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk);
            data_in = test_data[31-i];
            data_valid = 1;
            @(posedge clk);
        end
        data_valid = 0;
        
        #10;
        $display("连续数据计算的CRC-32结果: 0x%h", crc_out);
        
        // 完成测试
        #100;
        $display("所有测试完成");
        $finish;
    end
    
    // 波形生成（FSDB格式）
    initial begin
        $fsdbDumpfile("tb_serial_crc.fsdb");
        $fsdbDumpvars(0, tb_serial_crc);
        $fsdbDumpMDA();  // 转储多维数组
    end
    
endmodule