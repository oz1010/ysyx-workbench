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

wire in_write_mode = (aw_ready || w_ready || b_valid);
wire write_enable = (aw_valid || w_ready || b_valid);

wire read_enable = (ar_valid || r_ready);

`ifdef IN_YOSYS_STA
reg [31:0] exter_dev_regs[0:31];
`endif

wire [ADDR_WIDTH-1:0]       write_addr;
wire [DATA_WIDTH-1:0]       write_data;
wire [2:0]                  write_size;
wire                        write_valid;

wire [ADDR_WIDTH-1:0]       read_addr;
reg  [DATA_WIDTH-1:0]       r_read_data;
wire [2:0]                  read_size;
wire [1:0]                  read_state;

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

axi4_salve_reader #(
    `ifndef IN_YOSYS_STA
    .NAME("exter_dev"),
    `endif
    .BURST(1), // burst类型，0--FIXED 1--INCR 2--WRAP
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_axi4_salve_reader (
    .clk(clk),
    .rst(rst),
    .ar_ready(ar_ready),
    .ar_valid(ar_valid),
    .ar_addr(ar_addr),
    .ar_id(ar_id),
    .ar_len(ar_len),
    .ar_size(ar_size),
    .ar_burst(ar_burst),
    .r_ready(r_ready),
    .r_valid(r_valid),
    .r_resp(r_resp),
    .r_data(r_data),
    .r_last(r_last),
    .r_id(r_id),
    .enable(read_enable),
    .read_addr(read_addr),
    .read_data(r_read_data),
    .read_len(),
    .read_size(read_size),
    .read_state(read_state)
);

wire [31:0] w_real_read_size = 1<<read_size;
/* 使用组合逻辑读取数据，否则一个周期的ar信号可能无法满足要求 */
always @(*) begin
    r_read_data = 0;
    if (read_enable) begin
        if (ar_valid && ar_ready) begin
            `ifndef IN_YOSYS_STA
            if (w_real_read_size != 4) $error("extra dev only support read 4bytes, addr:%x size:%x", ar_addr, read_size);
            r_read_data = dpi_vdev_read(read_addr, w_real_read_size);
            `else
            r_read_data = exter_dev_regs[read_addr[4:0]];
            `endif
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
    end else begin
        if (in_write_mode && w_valid && w_ready) begin
            `ifndef IN_YOSYS_STA
            dpi_vdev_write(write_addr, write_data, 1<<write_size);
            `else
            exter_dev_regs[write_addr[4:0]] <= write_data;
            `endif
        end
    end
end

endmodule
