// 时间单位为1ps，没有缩放
`timescale 1ps/1ps

module test_cache_block(
    input wire [7:0] case_num
);
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    reg clk, rst;

    reg [ADDR_WIDTH-1:0]       addr;
    reg                        update_en;
    reg                        write_en;
    reg [DATA_WIDTH-1:0]       write_data;
    wire                       read_en;
    wire [DATA_WIDTH-1:0]      read_data;

    cache_block #(
        .W(2),
        .N(1),
        .M(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .addr(addr),
        .update_en(update_en),
        .reset_en(0),
        .write_en(write_en),
        .write_data(write_data),
        .read_en(read_en),
        .read_data(read_data)
    );

    `define CHECK_OUTPUT(actual_read_en, actual_read_data, expected_read_en, expected_read_data) begin\
            if (actual_read_en !== expected_read_en) begin \
                $error("FAIL: read_en - Expected %h, Got %h", expected_read_en, actual_read_en); \
                $finish; \
            end else if (actual_read_data !== expected_read_data) begin \
                $error("FAIL: read_data - Expected %h, Got %h", expected_read_data, actual_read_data); \
                $finish; \
            end \
        end

    // 时钟生成
    initial begin
        clk = 0;
        forever #1 clk = ~clk;  // 每个时间单位变化一次
    end
    
    // Test procedure
    initial begin
        $display("Case%d: test_cache_block start", case_num);

        rst = 1;
        #10;
        rst = 0;

        update_en = 0;
        write_en = 0;
        addr = 32'h80001234;
        #2;
        `CHECK_OUTPUT(read_en, read_data, 0, 0);

        update_en = 1; #4;
        write_en = 1;
        addr = 32'h80001234;
        write_data = 32'h80001230; #2; write_en = 0; #4; write_en = 1;
        write_data = 32'h80001234; #2; write_en = 0; #4; write_en = 1;
        write_data = 32'h80001238; #2; write_en = 0; #4; write_en = 1;
        write_data = 32'h8000123c; #2; write_en = 0; #4; write_en = 1;
        update_en = 0;
        write_en = 0; #4;
        `CHECK_OUTPUT(read_en, read_data, 1, 32'h80001234);

        addr = 32'h8000123c; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h80001238; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h80001234; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h80001230; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        
        addr = 32'h90001234; #2; `CHECK_OUTPUT(read_en, read_data, 0, 0);
        
        addr = 32'h8000123c; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h80001238; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h80001234; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h80001230; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);

        update_en = 1; #4;
        write_en = 1;
        addr = 32'h90001234;
        write_data = 32'h90001230; #2; write_en = 0; #4; write_en = 1;
        write_data = 32'h90001234; #2; write_en = 0; #4; write_en = 1;
        write_data = 32'h90001238; #2; write_en = 0; #4; write_en = 1;
        write_data = 32'h9000123c; #2; write_en = 0; #4; write_en = 1;
        update_en = 0;
        write_en = 0; #4;
        `CHECK_OUTPUT(read_en, read_data, 1, 32'h90001234);

        addr = 32'h9000123c; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h90001238; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h90001234; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h90001230; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h8000123c; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h80001238; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h80001234; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h80001230; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        
        // 结束仿真
        $display("Case%d: test_cache_block done", case_num);
    end

    reg [ADDR_WIDTH-1:0]       addr1;
    reg                        update_en1;
    reg                        write_en1;
    reg [DATA_WIDTH-1:0]       write_data1;
    wire                       read_en1;
    wire [DATA_WIDTH-1:0]      read_data1;

    cache_block #(
        .W(4),
        .N(1),
        .M(4)
    ) dut1 (
        .clk(clk),
        .rst(rst),
        .addr(addr1),
        .update_en(update_en1),
        .reset_en(0),
        .write_en(write_en1),
        .write_data(write_data1),
        .read_en(read_en1),
        .read_data(read_data1)
    );

    // 测试缓存更新机制
    initial begin
        #10
        update_en1 = 0;

        update_en1 = 1; #4;
        write_en1 = 1;
        addr1 = 32'h80001234;
        write_data1 = 32'h80001230; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'h80001234; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'h80001238; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'h8000123c; #2; write_en1 = 0; #4; write_en1 = 1;
        update_en1 = 0;
        write_en1 = 0; #4;
        `CHECK_OUTPUT(read_en1, read_data1, 1, 32'h80001234);

        update_en1 = 1; #4;
        write_en1 = 1;
        addr1 = 32'h90001234;
        write_data1 = 32'h90001230; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'h90001234; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'h90001238; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'h9000123c; #2; write_en1 = 0; #4; write_en1 = 1;
        update_en1 = 0;
        write_en1 = 0; #4;
        `CHECK_OUTPUT(read_en1, read_data1, 1, 32'h90001234);

        update_en1 = 1; #4;
        write_en1 = 1;
        addr1 = 32'ha0001234;
        write_data1 = 32'ha0001230; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'ha0001234; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'ha0001238; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'ha000123c; #2; write_en1 = 0; #4; write_en1 = 1;
        update_en1 = 0;
        write_en1 = 0; #4;
        `CHECK_OUTPUT(read_en1, read_data1, 1, 32'ha0001234);

        update_en1 = 1; #4;
        write_en1 = 1;
        addr1 = 32'hb0001234;
        write_data1 = 32'hb0001230; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'hb0001234; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'hb0001238; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'hb000123c; #2; write_en1 = 0; #4; write_en1 = 1;
        update_en1 = 0;
        write_en1 = 0; #4;
        `CHECK_OUTPUT(read_en1, read_data1, 1, 32'hb0001234);

        // 检查所有数据
        addr1 = 32'ha000123c; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'ha0001238; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'ha0001234; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'ha0001230; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        
        addr1 = 32'h9000123c; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'h90001238; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'h90001234; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'h90001230; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        
        addr1 = 32'h8000123c; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'h80001238; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'h80001234; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'h80001230; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        
        addr1 = 32'hb000123c; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'hb0001238; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'hb0001234; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'hb0001230; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);

        // 触发更新策略
        update_en1 = 1; #4;
        write_en1 = 1;
        addr1 = 32'ha1001234;
        write_data1 = 32'ha1001230; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'ha1001234; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'ha1001238; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'ha100123c; #2; write_en1 = 0; #4; write_en1 = 1;
        update_en1 = 0;
        write_en1 = 0; #4;
        `CHECK_OUTPUT(read_en1, read_data1, 1, 32'ha1001234);

        addr1 = 32'ha000123c; #2; `CHECK_OUTPUT(read_en1, read_data1, 0, 0);

        update_en1 = 1; #4;
        write_en1 = 1;
        addr1 = 32'h91001234;
        write_data1 = 32'h91001230; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'h91001234; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'h91001238; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'h9100123c; #2; write_en1 = 0; #4; write_en1 = 1;
        update_en1 = 0;
        write_en1 = 0; #4;
        `CHECK_OUTPUT(read_en1, read_data1, 1, 32'h91001234);

        addr1 = 32'h9000123c; #2; `CHECK_OUTPUT(read_en1, read_data1, 0, 0);

        update_en1 = 1; #4;
        write_en1 = 1;
        addr1 = 32'h81001234;
        write_data1 = 32'h81001230; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'h81001234; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'h81001238; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'h8100123c; #2; write_en1 = 0; #4; write_en1 = 1;
        update_en1 = 0;
        write_en1 = 0; #4;
        `CHECK_OUTPUT(read_en1, read_data1, 1, 32'h81001234);

        addr1 = 32'h8000123c; #2; `CHECK_OUTPUT(read_en1, read_data1, 0, 0);

        update_en1 = 1; #4;
        write_en1 = 1;
        addr1 = 32'hb1001234;
        write_data1 = 32'hb1001230; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'hb1001234; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'hb1001238; #2; write_en1 = 0; #4; write_en1 = 1;
        write_data1 = 32'hb100123c; #2; write_en1 = 0; #4; write_en1 = 1;
        update_en1 = 0;
        write_en1 = 0; #4;
        `CHECK_OUTPUT(read_en1, read_data1, 1, 32'hb1001234);

        addr1 = 32'hb000123c; #2; `CHECK_OUTPUT(read_en1, read_data1, 0, 0);

        // 检查所有数据
        addr1 = 32'ha100123c; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'ha1001238; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'ha1001234; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'ha1001230; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        
        addr1 = 32'h9100123c; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'h91001238; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'h91001234; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'h91001230; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        
        addr1 = 32'h8100123c; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'h81001238; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'h81001234; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'h81001230; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        
        addr1 = 32'hb100123c; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'hb1001238; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'hb1001234; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
        addr1 = 32'hb1001230; #2; `CHECK_OUTPUT(read_en1, read_data1, 1, addr1);
    end

endmodule
