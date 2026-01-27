module cache #(
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
    input   wire                        reset_en, // addr会选中特定的line，只要reset_en激活即可无效对应数据
    input   wire                        write_en,
    input   wire [DATA_WIDTH-1:0]       write_data,
    output  wire                        read_en,
    output  wire [DATA_WIDTH-1:0]       read_data
);

`ifndef IN_YOSYS_STA

/*
 31    m+n m+n-1   m m-1    0
+---------+---------+--------+
|   tag   |  index  | offset |
+---------+---------+--------+
*/
localparam block_count = (1<<N);
localparam block_count_max = N>0 ? block_count-1 : 0;
localparam block_count_width = N==0 ? 1 : N;
localparam block_count_bit_high = N>0 ? N-1 : 0;
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

reg  [block_count-1:0]          block_update_en;
wire [block_count-1:0]          block_reset_en;
wire [block_count-1:0]          block_read_en_inner; // 未包含index比较的信号
wire [block_count-1:0]          block_read_en; // 包含index比较的信号
wire [DATA_WIDTH-1:0]           block_read_data[0:block_count-1];
wire [block_count_bit_high:0]   block_index;

assign block_index = block_count==1 ? 0 : addr[offset_width +: block_count_width];
assign read_en = block_read_en[block_index];
assign read_data = block_read_data[block_index];

generate
    for (genvar i=0; i<block_count; ++i) begin : genblock
        assign block_reset_en[i] = block_index==i && reset_en;
        cache_block #(
            .W(W),
            .N(N),
            .M(M)
        ) block (
            .clk(clk),
            .rst(rst),
            .addr(addr),
            .update_en(block_update_en[i]),
            .reset_en(block_reset_en[i]),
            .write_en(write_en),
            .write_data(write_data),
            .read_en(block_read_en_inner[i]),
            .read_data(block_read_data[i])
        );
        assign block_read_en[i] = block_read_en_inner[i] & (i==block_index);
    end
endgenerate

always @(*) begin
    block_update_en = 0;
    if (update_en) block_update_en[block_index] = 1;
end

`endif

endmodule

