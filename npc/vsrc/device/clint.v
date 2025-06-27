module clint #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clk,
    input wire rst,

    output  wire                        aw_ready,
    input   wire                        aw_valid,
    input   wire [ADDR_WIDTH-1:0]       aw_addr,
    input   wire [3:0]                  aw_id,
    input   wire [7:0]                  aw_len,
    input   wire [2:0]                  aw_size,
    input   wire [1:0]                  aw_burst,
    output  wire                        w_ready,
    input   wire                        w_valid,
    input   wire [DATA_WIDTH-1:0]       w_data,
    input   wire [DATA_WIDTH/8-1:0]     w_strb,
    input   wire                        w_last,
    input   wire                        b_ready,
    output  wire                        b_valid,
    output  wire [BRESP_WIDTH-1:0]      b_resp,
    output  wire [3:0]                  b_id,
    output  wire                        ar_ready,
    input   wire                        ar_valid,
    input   wire [ADDR_WIDTH-1:0]       ar_addr,
    input   wire [3:0]                  ar_id,
    input   wire [7:0]                  ar_len,
    input   wire [2:0]                  ar_size,
    input   wire [1:0]                  ar_burst,
    input   wire                        r_ready,
    output  wire                        r_valid,
    output  wire [RRESP_WIDTH-1:0]      r_resp,
    output  wire [DATA_WIDTH-1:0]       r_data,
    output  wire                        r_last,
    output  wire [3:0]                  r_id
);

reg                                     r_aw_ready = 0;
reg                                     r_w_ready = 0;
reg                                     r_b_valid = 0;
reg [BRESP_WIDTH-1:0]                   r_b_resp = 0;
reg [3:0]                               r_b_id = 0;
reg                                     r_ar_ready;
reg                                     r_r_valid;
reg [RRESP_WIDTH-1:0]                   r_r_resp;
reg [DATA_WIDTH-1:0]                    r_r_data;
reg                                     r_r_last;
reg [3:0]                               r_r_id;

reg [ADDR_WIDTH-1:0] r_write_addr;

wire [DATA_WIDTH-1:0] w_write_width = {{DATA_WIDTH-DATA_WIDTH/8{1'b0}}, w_strb};

assign aw_ready = r_aw_ready;
assign w_ready = r_w_ready;
assign b_valid = r_b_valid;
assign b_resp = r_b_resp;
assign b_id = r_b_id;
assign ar_ready = r_ar_ready;
assign r_valid = r_r_valid;
assign r_resp = r_r_resp;
assign r_data = r_r_data;
assign r_last = r_r_last;
assign r_id = r_r_id;

wire [31:0] read_len = 1<<ar_len;      // burst写入数量，2^n字节
wire [31:0] read_size = 1<<ar_size;    // 单个burst写入数据大小，2^n字节

`ifdef IN_YOSYS_STA
reg [31:0] rtc_ticks;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        rtc_ticks <= 0;
    end else begin
        rtc_ticks <= rtc_ticks + 1;
    end
end
`endif


always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_aw_ready <= 0;
        r_w_ready <= 0;
        r_b_valid <= 0;
        r_b_resp <= 0;
        r_b_id <= 0;
        r_ar_ready <= 0;
        r_r_valid <= 0;
        r_r_resp <= 0;
        r_r_data <= 0;
        r_r_last <= 0;
        r_r_id <= 0;

        r_write_addr <= 0;
    end else begin
        r_aw_ready <= r_aw_ready;
        r_w_ready <= r_w_ready;
        r_b_valid <= r_b_valid;
        r_b_resp <= r_b_resp;
        r_b_id <= r_b_id;
        r_ar_ready <= r_ar_ready;
        r_r_valid <= r_r_valid;
        r_r_resp <= r_r_resp;
        r_r_data <= r_r_data;
        r_r_last <= r_r_last;
        r_r_id <= r_r_id;

        r_write_addr <= r_write_addr;

        // read request
        if (ar_valid) begin
            r_ar_ready <= 1;
        end
        if (ar_valid && ar_ready) begin
            r_ar_ready <= 0;
        end

        // read data
        if (ar_valid && ar_ready) begin
`ifdef IN_YOSYS_STA
            r_r_data <= rtc_ticks;
`else
            if (read_size != 4) $error("clint only support read 4bytes, addr:%x size:%x", ar_addr, read_size);

            r_r_data <= dpi_rtc_read(ar_addr, read_size);
`endif

            r_r_valid <= 1;
            r_r_resp <= 0;
            r_r_last <= 1;
            r_r_id <= ar_id;
        end
        if (r_valid && r_ready) begin
            r_r_valid <= 0;
            r_r_resp <= 0;
            r_r_last <= 0;
            r_r_id <= 0;
        end
    end
end

endmodule
