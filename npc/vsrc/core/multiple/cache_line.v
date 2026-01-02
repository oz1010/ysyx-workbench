module cache_line #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    /* 
        w > 0
        n > 0
        m+n < 31
        m > 1
     */
    parameter W = 1,
    parameter N = 2,
    parameter M = 3
) (
    input   wire                        clk,
    input   wire                        rst,
    
    input   wire [ADDR_WIDTH-1:0]       addr,
    input   wire                        update_en,
    input   wire                        write_en,
    input   wire [DATA_WIDTH-1:0]       write_data,
    output  wire                        read_en,
    output  wire [DATA_WIDTH-1:0]       read_data
);

/*
 31    m+n m+n-1   m m-1    0
+---------+---------+--------+
|   tag   |  index  | offset |
+---------+---------+--------+
*/
localparam tag_width = 32 - (M+N);
localparam index_width = N;
localparam offset_width = M;
localparam line_width = 8*(1<<M);
localparam write_offset_width = M-2;
localparam write_offset_max = (1<<write_offset_width)-1;

wire [tag_width-1:0] tag = addr[index_width+offset_width +: tag_width];
wire [index_width-1:0] index = addr[offset_width +: index_width];
wire [offset_width-1:0] offset = addr[0 +: offset_width];

reg  valid;
reg  [line_width-1:0] line;
reg  [tag_width-1:0] line_tag;
reg  [write_offset_width:0] write_offset;

assign read_en = valid && tag==line_tag;
assign read_data = read_en ? line[8*offset +: DATA_WIDTH] : 0;

always @(posedge clk) begin
    if (rst) begin
        valid <= 0;
        line <= 0;
        line_tag <= 0;
        write_offset <= 0;
    end else begin
        if (update_en) begin
            // 单次write信号应该只存在一个周期，直到写入预期次数的数据
            if (write_en) begin
                line[write_offset*DATA_WIDTH +: DATA_WIDTH] <= write_data;
                write_offset <= write_offset + 1;
                if (write_offset == write_offset_max) begin
                    valid <= 1;
                    write_offset <= write_offset;
                    line_tag <= tag;
                end
            end
        end else begin
            write_offset <= 0;
        end
        
    end
end


endmodule
