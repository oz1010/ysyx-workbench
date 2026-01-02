module cache_block #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    /* 
        w > 0
        n > 0
        m+n < 31
        m > 1
     */
    parameter W = 2,
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
localparam line_count = W;
localparam line_count_width = log2up(W);
localparam line_count_max = W-1;
localparam line_read_flag_max = W-1;
localparam tag_width = 32 - (M+N);
localparam index_width = N;
localparam offset_width = M;
localparam line_width = 8*(1<<M);
localparam write_offset_width = M-2;
localparam write_offset_count = (1<<write_offset_width);

wire [tag_width-1:0] tag = addr[index_width+offset_width +: tag_width];
// wire [index_width-1:0] index = addr[offset_width +: index_width];
wire [offset_width-1:0] offset = addr[0 +: offset_width];

reg  [line_count-1:0] line_update_en;
wire [line_count-1:0] line_read_en;
wire [DATA_WIDTH-1:0] line_read_data[0:line_count-1];
reg  [line_count_width-1:0] line_read_index;
reg  [line_count_width-1:0] line_read_index_last;
reg  [line_count_width-1:0] line_update_index;
reg  [line_count_width-1:0] line_read_flag[0:line_count-1];
reg  [line_count_width-1:0] line_read_min_flag;

generate
    for (genvar i=0; i<line_count; ++i) begin : genline
        cache_line #(
            .W(W),
            .N(N),
            .M(M)
        ) line (
            .clk(clk),
            .rst(rst),
            .addr(addr),
            .update_en(line_update_en[i]),
            .write_en(write_en),
            .write_data(write_data),
            .read_en(line_read_en[i]),
            .read_data(line_read_data[i])
        );
    end
endgenerate
assign read_data = line_read_data[line_read_index];
assign read_en = |line_read_en;
always @(*) begin
    line_read_index = 0;
    for (integer i = 1; i<line_count; ++i) begin
        if (line_read_en[i] && line_read_index==0) begin
            line_read_index = i[$bits(line_read_index)-1:0];
        end
    end
end
always @(*) begin
    line_update_index = 0;
    line_update_en = 0;
    line_read_min_flag = line_read_flag[line_update_index];
    for (integer i=1; i<line_count; ++i) begin
        if (line_read_flag[i] < line_read_min_flag) begin
            line_update_index = i[$bits(line_update_index)-1:0];
            line_read_min_flag = line_read_flag[i];
        end
    end
    if (update_en) line_update_en[line_update_index] = 1;
end

always @(posedge clk) begin
    if (rst) begin
        for (integer i=0; i<line_count; ++i) begin
            line_read_flag[i] <= 0;
        end
        line_read_index_last <= {$bits(line_read_index_last){1'b1}};
    end else begin
        // 命中缓存
        if (!update_en &&read_en) begin
            // line_read_index与之前不一致则更新未命中flag
            if (line_read_index != line_read_index_last) begin
                for (integer i=0; i<line_count; ++i) begin
                    if (line_read_flag[i] > 0) begin
                        line_read_flag[i] <= line_read_flag[i] - 1;
                    end
                end
                line_read_index_last <= line_read_index;
            end
            line_read_flag[line_read_index] <= line_read_flag_max[line_count_width-1:0];
        end
    end
end

endmodule