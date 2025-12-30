// 时间单位为1ps，没有缩放
`timescale 1ps/1ps

module test_cache_line(
    input wire [7:0] case_num
);
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    reg clk, rst;
    reg [7:0] data_in;
    wire [7:0] data_out;

    reg [ADDR_WIDTH-1:0]       addr;
    reg                        update_en;
    reg                        write_en;
    reg [DATA_WIDTH-1:0]       write_data;
    wire                       read_en;
    wire [DATA_WIDTH-1:0]      read_data;

    cache_line #(
        .W(1),
        .N(1),
        .M(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .addr(addr),
        .update_en(update_en),
        .write_en(write_en),
        .write_data(write_data),
        .read_en(read_en),
        .read_data(read_data)
    );

    // 时钟生成
    initial begin
        clk = 0;
        forever #1 clk = ~clk;  // 每个时间单位变化一次
    end
    
    // Test procedure
    initial begin
        $display("Case%d: test_cache_line start", case_num);

        rst = 1;
        #10;
        rst = 0;

        update_en = 0;
        write_en = 0;
        addr = 32'h80001234;
        #2;
        check_output(read_en, read_data, 0, 0);

        update_en = 1; #2;
        write_en = 1;
        addr = 32'h80001234;
        write_data = 32'h80001230; #2;
        write_data = 32'h80001234; #2;
        write_data = 32'h80001238; #2;
        write_data = 32'h8000123c; #2;
        update_en = 0;
        write_en = 0; #2;
        check_output(read_en, read_data, 1, 32'h80001234);

        addr = 32'h8000123c; #2;
        check_output(read_en, read_data, 1, addr);
        addr = 32'h80001238; #2;
        check_output(read_en, read_data, 1, addr);
        addr = 32'h80001234; #2;
        check_output(read_en, read_data, 1, addr);
        addr = 32'h80001230; #2;
        check_output(read_en, read_data, 1, addr);
        
        addr = 32'h80001244; #2;
        check_output(read_en, read_data, 0, 0);
        
        addr = 32'h8000123c; #2;
        check_output(read_en, read_data, 1, addr);
        addr = 32'h80001238; #2;
        check_output(read_en, read_data, 1, addr);
        addr = 32'h80001234; #2;
        check_output(read_en, read_data, 1, addr);
        addr = 32'h80001230; #2;
        check_output(read_en, read_data, 1, addr);
        
        // 结束仿真
        $display("Case%d: test_cache_line done", case_num);
    end
 
    task check_output;
        input                   actual_read_en;
        input [DATA_WIDTH-1:0]  actual_read_data;
        input                   expected_read_en;
        input [DATA_WIDTH-1:0]  expected_read_data;
        begin
            if (actual_read_en !== expected_read_en) begin
                $error("FAIL: read_en - Expected %h, Got %h", 
                          expected_read_en, actual_read_en);
                $finish;
            end

            if (actual_read_data !== expected_read_data) begin
                $error("FAIL: read_data - Expected %h, Got %h", 
                          expected_read_data, actual_read_data);
                $finish;
            end
        end
    endtask

endmodule
