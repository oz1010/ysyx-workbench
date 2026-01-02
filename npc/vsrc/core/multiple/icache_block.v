/* 单个缓存块 */
module icache_block #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter block_count = 16
) (
    input   wire                        clk,
    input   wire                        rst,
    input   wire [ADDR_WIDTH-1:0]       write_addr,
    input   wire                        write_en,
    input   wire [log2(block_count)-1:0] write_index,
    input   wire [INST_WIDTH-1:0]       write_inst,
    input   wire [ADDR_WIDTH-1:0]       read_addr,
    output  wire                        read_en,
    output  wire [INST_WIDTH-1:0]       read_inst
);

localparam check_cache_t = 0;
localparam return_cache_t = 1;
localparam update_cache_t = 2;

/*
 31    m+n m+n-1   m m-1    0
+---------+---------+--------+
|   tag   |  index  | offset |
+---------+---------+--------+
*/
localparam tag_width = ADDR_WIDTH - (offset_width+index_width);
localparam block_width = INST_WIDTH*block_count;
localparam offset_width = log2(INST_WIDTH/8);
localparam index_width = log2(block_count);
localparam index_max = {index_width{1'h1}};

reg [block_width-1:0] block = 0;
wire valid = tag==rtag;
reg [tag_width-1:0] tag = 0;
reg [log2(block_count)-1:0] current_write_index = 0;
reg [1:0] cache_state = check_cache_t;

wire [tag_width-1:0] rtag = read_addr[index_width+offset_width +: tag_width];
wire [index_width-1:0] rindex = read_addr[offset_width +: index_width];
wire [offset_width-1:0] roffset = read_addr[0 +: offset_width];

wire [tag_width-1:0] wtag = write_addr[index_width+offset_width +: tag_width];
wire [index_width-1:0] windex = write_addr[offset_width +: index_width];
wire [offset_width-1:0] woffset = write_addr[0 +: offset_width];

assign read_en = valid && rtag==tag && cache_state==check_cache_t;
generate
    for (genvar offset=0; offset<(INST_WIDTH/8); ++offset) begin
        assign read_inst[offset*8 +: 8] = read_en ? block[((offset + {rindex, roffset})*8)%block_width +: 8] : 0;
    end
endgenerate

always @(posedge clk) begin
    if (rst || valid) begin
        current_write_index <= 0;
        cache_state <= check_cache_t;
    end else begin
        case (cache_state)
        check_cache_t: begin
            if (write_en) begin
                cache_state <= update_cache_t;
                tag <= rtag^{tag_width{1'h1}};
            end
        end

        update_cache_t: begin
            if (write_en) begin
                if (current_write_index == write_index) begin
                    current_write_index <= write_index + 1;
                    for (integer offset=0; offset<(INST_WIDTH/8); ++offset) begin
                        block[((offset[0 +: offset_width+index_width] + {windex, woffset})*8)%block_width +: 8] <= write_inst[offset*8 +: 8];
                    end

                    if (write_index == index_max && !valid) begin
                        tag <= wtag;
                        current_write_index <= 0;
                        cache_state <= check_cache_t;
                    end
                end
            end
        end

        endcase
    end
end

endmodule
