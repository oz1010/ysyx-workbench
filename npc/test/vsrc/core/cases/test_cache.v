// 时间单位为1ps，没有缩放
`timescale 1ps/1ps

module test_cache(
    input wire [7:0] case_num
);
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    reg clk, rst;

    reg [ADDR_WIDTH-1:0]       addr;
    reg                        update_en;
    reg                        reset_en;
    reg                        write_en;
    reg [DATA_WIDTH-1:0]       write_data;
    wire                       read_en;
    wire [DATA_WIDTH-1:0]      read_data;

    cache #(
        .W(1),
        .N(1),
        .M(2)
    ) dut (
        .clk(clk),
        .rst(rst),
        .addr(addr),
        .update_en(update_en),
        .reset_en(reset_en),
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
        $display("Case%d: test_cache start", case_num);

        rst = 1;
        #10;
        rst = 0;

        update_en = 0;
        reset_en = 0;
        write_en = 0;
        addr = 32'h80001234;
        #2;
        `CHECK_OUTPUT(read_en, read_data, 0, 0);

        update_en = 1; #4;
        write_en = 1;
        addr = 32'h80001230;
        write_data = 32'h80001230; #2; write_en = 0; #4; write_en = 1;
        update_en = 0;
        write_en = 0; #4;
        `CHECK_OUTPUT(read_en, read_data, 1, 32'h80001230);

        update_en = 1; #4;
        write_en = 1;
        addr = 32'h80001234;
        write_data = 32'h80001234; #2; write_en = 0; #4; write_en = 1;
        update_en = 0;
        write_en = 0; #4;
        `CHECK_OUTPUT(read_en, read_data, 1, 32'h80001234);

        addr = 32'h90001240; #2; `CHECK_OUTPUT(read_en, read_data, 0, 0);
        addr = 32'h80001230; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h80001234; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);

        addr = 32'h90001238; #2; `CHECK_OUTPUT(read_en, read_data, 0, 0);
        addr = 32'h80001230; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h80001234; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);

        update_en = 1; #4;
        write_en = 1;
        addr = 32'h81001230;
        write_data = 32'h81001230; #2; write_en = 0; #4; write_en = 1;
        update_en = 0;
        write_en = 0; #4;
        `CHECK_OUTPUT(read_en, read_data, 1, 32'h81001230);

        addr = 32'h80001230; #2; `CHECK_OUTPUT(read_en, read_data, 0, 0);
        addr = 32'h81001230; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h80001234; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);

        update_en = 1; #4;
        write_en = 1;
        addr = 32'h81001234;
        write_data = 32'h81001234; #2; write_en = 0; #4; write_en = 1;
        update_en = 0;
        write_en = 0; #4;
        `CHECK_OUTPUT(read_en, read_data, 1, 32'h81001234);

        addr = 32'h80001230; #2; `CHECK_OUTPUT(read_en, read_data, 0, 0);
        addr = 32'h80001234; #2; `CHECK_OUTPUT(read_en, read_data, 0, 0);
        addr = 32'h81001230; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h81001234; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);

        addr = 32'h81001234; reset_en = 1; #2; reset_en = 0; #2

        addr = 32'h81001230; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h81001234; #2; `CHECK_OUTPUT(read_en, read_data, 0, 0);

        update_en = 1; #4;
        write_en = 1;
        addr = 32'h8100123c;
        write_data = 32'h8100123c; #2; write_en = 0; #4; write_en = 1;
        update_en = 0;
        write_en = 0; #4;
        `CHECK_OUTPUT(read_en, read_data, 1, 32'h8100123c);

        addr = 32'h81001230; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        addr = 32'h8100123c; #2; `CHECK_OUTPUT(read_en, read_data, 1, addr);
        
        // 结束仿真
        $display("Case%d: test_cache done", case_num);
    end

endmodule
