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

localparam check_cache_t = 0;
localparam return_cache_t = 1;
localparam update_cache_t = 2;

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
reg  [1:0] state;
wire [tag_width-1:0] line_tag = line[index_width+offset_width +: tag_width];
reg  [write_offset_width:0] write_offset;

assign read_en = state==check_cache_t && valid && tag==line_tag;
assign read_data = read_en ? line[8*offset +: DATA_WIDTH] : 0;

always @(posedge clk) begin
    if (rst) begin
        valid <= 0;
        line <= 0;
        state <= check_cache_t;
    end else begin
        case (state)
            check_cache_t: begin
                if (update_en) begin
                    write_offset <= 0;
                    state <= update_cache_t;
                    valid <= 0;
                end
            end

            update_cache_t: begin
                if (write_en) begin
                    line[write_offset*DATA_WIDTH +: DATA_WIDTH] <= write_data;
                    write_offset <= write_offset + 1;
                    if (write_offset == write_offset_max) begin
                        valid <= 1;
                        state <= check_cache_t;
                    end
                end
            end

            default: begin
                `ifndef IN_YOSYS_STA
                $error("unknown state %d", state);
                `endif
            end
        endcase
    end
end


endmodule
