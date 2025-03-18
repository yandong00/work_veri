`timescale 1ns/1ps

module tb_serial_crc();
    // 测试平台信号
    reg clk;
    reg rst_n;
    reg data_in;
    reg data_valid;
    reg init;
    reg crc_mode;
    reg [15:0] polynomial;
    wire [15:0] crc_out;
    
    // 用于测试的变量
    reg [31:0] test_data;
    integer i;
    reg [15:0] expected_crc;
    
    // 实例化被测试模块
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
        crc_mode = 0;
        polynomial = 16'h0000;
        
        // 复位
        #20;
        rst_n = 1;
        #10;
        
        // 测试1：CRC-8计算
        $display("测试1：CRC-8计算");
        crc_mode = 0;           // CRC-8模式
        polynomial = 16'h0007;  // CRC-8多项式 (0x07)
        test_data = 32'h12345678;
        expected_crc = 16'h0000; // 预期的CRC-8值（需要根据实际算法计算）
        
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
                 crc_out & 16'h00FF, 
                 expected_crc, 
                 ((crc_out & 16'h00FF) == expected_crc) ? "通过" : "失败");
        
        // 测试2：CRC-16计算
        $display("测试2：CRC-16计算");
        crc_mode = 1;            // CRC-16模式
        polynomial = 16'h8005;   // CRC-16多项式 (0x8005)
        test_data = 32'hAABBCCDD;
        expected_crc = 16'h0000; // 预期的CRC-16值（需要根据实际算法计算）
        
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
                 crc_out, 
                 expected_crc, 
                 (crc_out == expected_crc) ? "通过" : "失败");
        
        // 测试3：测试不同多项式
        $display("测试3：不同多项式测试");
        crc_mode = 0;           // CRC-8模式
        polynomial = 16'h001D;  // 不同的CRC-8多项式
        test_data = 32'h55AA55AA;
        expected_crc = 16'h0000; // 预期值
        
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
        $display("使用多项式0x%h的CRC-8结果: 0x%h", polynomial, crc_out & 16'h00FF);
        
        // 测试4：自动化测试用例
        $display("测试4：自动化测试");
        
        // CRC-8测试向量
        crc_mode = 0;
        polynomial = 16'h0007;  // 标准CRC-8
        
        // 测试向量：{输入数据, 预期CRC}
        automatic reg [39:0] crc8_test_vectors[0:4];
        
        crc8_test_vectors[0] = {32'h00000000, 8'hFF};  // 全0输入
        crc8_test_vectors[1] = {32'hFFFFFFFF, 8'hFF};  // 全1输入
        crc8_test_vectors[2] = {32'h12345678, 8'hDF};  // 随机数据
        crc8_test_vectors[3] = {32'hA5A5A5A5, 8'h1D};  // 交替模式
        crc8_test_vectors[4] = {32'h01020304, 8'h91};  // 递增模式
        
        for (i = 0; i < 5; i = i + 1) begin
            test_data = crc8_test_vectors[i][39:8];
            expected_crc = {8'h00, crc8_test_vectors[i][7:0]};
            
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
            
            // 验证CRC-8结果
            #10;
            $display("测试向量 %0d: 输入=0x%h, CRC-8结果=0x%h, 预期=0x%h, %s", 
                     i, test_data, crc_out & 16'h00FF, expected_crc & 16'h00FF,
                     ((crc_out & 16'h00FF) == (expected_crc & 16'h00FF)) ? "通过" : "失败");
        end
        
        // 测试5：连续数据处理
        $display("测试5：连续数据处理");
        crc_mode = 1;            // CRC-16模式
        polynomial = 16'h8005;   // CRC-16多项式
        
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
        $display("连续数据计算的CRC-16结果: 0x%h", crc_out);
        
        // 完成测试
        #100;
        $display("所有测试完成");
        $finish;
    end
    
    // 波形生成
    initial begin
        $dumpfile("tb_serial_crc.vcd");
        $dumpvars(0, tb_serial_crc);
    end
    
endmodule