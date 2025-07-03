module exter_dev #(
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

reg                                     r_ar_ready;
reg                                     r_r_valid;
reg [RRESP_WIDTH-1:0]                   r_r_resp;
reg [DATA_WIDTH-1:0]                    r_r_data;
reg                                     r_r_last;
reg [3:0]                               r_r_id;

assign ar_ready = r_ar_ready;
assign r_valid = r_r_valid;
assign r_resp = r_r_resp;
assign r_data = r_r_data;
assign r_last = r_r_last;
assign r_id = r_r_id;

wire [31:0] read_len = 1<<ar_len;       // burst读取数量，2^n字节
wire [31:0] read_size = 1<<ar_size;     // 单个burst读取数据大小，2^n字节

wire in_write_mode = (aw_ready || w_ready || b_valid);
wire write_enable = (aw_valid || w_ready || b_valid);

`ifdef IN_YOSYS_STA
reg [31:0] exter_dev_regs[0:31];
`endif

wire [ADDR_WIDTH-1:0]       write_addr;
wire [DATA_WIDTH-1:0]       write_data;
wire [2:0]                  write_size;
wire                        write_valid;

axi4_salve_writer #(
    `ifndef IN_YOSYS_STA
    .NAME("exter_dev"),
    `endif
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_axi4_salve_writer (
    .clk(clk),
    .rst(rst),
    .aw_ready(aw_ready),
    .aw_valid(aw_valid),
    .aw_addr(aw_addr),
    .aw_id(aw_id),
    .aw_len(aw_len),
    .aw_size(aw_size),
    .aw_burst(aw_burst),
    .w_ready(w_ready),
    .w_valid(w_valid),
    .w_data(w_data),
    .w_strb(w_strb),
    .w_last(w_last),
    .b_ready(b_ready),
    .b_valid(b_valid),
    .b_resp(b_resp),
    .b_id(b_id),
    .enable(write_enable),
    .write_addr(write_addr),
    .write_data(write_data),
    .write_size(write_size),
    .write_valid(write_valid)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_ar_ready <= 0;
        r_r_valid <= 0;
        r_r_resp <= 0;
        r_r_data <= 0;
        r_r_last <= 0;
        r_r_id <= 0;
    end else begin
        r_ar_ready <= r_ar_ready;
        r_r_valid <= r_r_valid;
        r_r_resp <= r_r_resp;
        r_r_data <= r_r_data;
        r_r_last <= r_r_last;
        r_r_id <= r_r_id;

        if (in_write_mode && w_valid && w_ready) begin
            `ifndef IN_YOSYS_STA
            dpi_vdev_write(write_addr, write_data, 1<<write_size);
            `else
            exter_dev_regs[write_addr[4:0]] <= write_data;
            `endif
        end

        // read request
        if (ar_valid) begin
            r_ar_ready <= 1;
        end
        if (ar_valid && ar_ready) begin
            r_ar_ready <= 0;
        end

        // read data
        if (ar_valid && ar_ready) begin
`ifndef IN_YOSYS_STA
            if (read_size != 4) $error("extra dev only support read 4bytes, addr:%x size:%x", ar_addr, read_size);

            r_r_data <= dpi_vdev_read(ar_addr, read_size);
`else
            r_r_data <= exter_dev_regs[ar_addr[4:0]];
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
