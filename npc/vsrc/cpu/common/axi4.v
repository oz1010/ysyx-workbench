module axi4_base (
    input wire enable,
    input wire ready,
    input wire valid,
    output wire [1:0] status
);
    
assign status = 
    (enable==0) ? `AXI4_WAIT :
    {valid, ready};

endmodule

module axi4_manager #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clock,
    input wire reset,
    input wire enable,

    output wire aw_valid,
    input wire aw_ready,
    output wire [ADDR_WIDTH-1:0] aw_addr,

    output wire w_valid,
    input wire w_ready,
    output wire [DATA_WIDTH-1:0] w_data,
    output wire [DATA_WIDTH/8-1:0] w_strb,

    input wire b_valid,
    output wire b_ready,
    input wire [BRESP_WIDTH-1:0] b_resp,

    output wire ar_valid,
    input wire ar_ready,
    output wire [ADDR_WIDTH-1:0] ar_addr,

    input wire r_valid,
    output wire r_ready,
    input wire [DATA_WIDTH-1:0] r_data,
    input wire [RRESP_WIDTH-1:0] r_resp,

    output wire [1:0] aw_status,
    output wire [1:0] w_status,
    output wire [1:0] b_status,
    output wire [1:0] ar_status,
    output wire [1:0] r_status
);

reg r_aw_valid;
reg [ADDR_WIDTH-1:0] r_aw_addr;
reg r_w_valid;
reg [DATA_WIDTH-1:0] r_w_data;
reg [DATA_WIDTH/8-1:0] r_w_strb;
reg r_b_ready;
reg r_ar_valid;
reg [ADDR_WIDTH-1:0] r_ar_addr;
reg r_r_ready;

assign aw_valid = r_aw_valid;
assign aw_addr = r_aw_addr;
assign w_valid = r_w_valid;
assign w_data = r_w_data;
assign w_strb = r_w_strb;
assign b_ready = r_b_ready;
assign ar_valid = r_ar_valid;
assign ar_addr = r_ar_addr;
assign r_ready = r_r_ready;

axi4_base aw_base(
    .enable(1),
    .ready(aw_ready),
    .valid(aw_valid),
    .status(aw_status)
);
axi4_base w_base(
    .enable(1),
    .ready(w_ready),
    .valid(w_valid),
    .status(w_status)
);
axi4_base b_base(
    .enable(1),
    .ready(b_ready),
    .valid(b_valid),
    .status(b_status)
);
axi4_base ar_base(
    .enable(1),
    .ready(ar_ready),
    .valid(ar_valid),
    .status(ar_status)
);
axi4_base r_base(
    .enable(1),
    .ready(r_ready),
    .valid(r_valid),
    .status(r_status)
);

always @(posedge clock or posedge reset) begin
    if (reset) begin
        r_aw_valid <= 0;
        r_aw_addr <= 0;
        r_w_valid <= 0;
        r_w_data <= 0;
        r_w_strb <= 0;
        r_b_ready <= 0;
        r_ar_valid <= 0;
        r_ar_addr <= 0;
        r_r_ready <= 0;
    end else begin
        if (enable) begin
            r_aw_valid <= r_aw_valid;
            r_w_valid <= r_w_valid;
            r_b_ready <= r_b_ready;
            r_ar_valid <= r_ar_valid;
            r_r_ready <= r_r_ready;
        end else begin
            r_aw_valid <= 0;
            r_w_valid <= 0;
            r_b_ready <= 0;
            r_ar_valid <= 0;
            r_r_ready <= 0;
        end
    end
end

endmodule


module axi4_subordinate #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clock,
    input wire reset,
    input wire enable,

    input wire aw_valid,
    output wire aw_ready,
    input wire [ADDR_WIDTH-1:0] aw_addr,

    input wire w_valid,
    output wire w_ready,
    input wire [DATA_WIDTH-1:0] w_data,
    input wire [DATA_WIDTH/8-1:0] w_strb,

    output wire b_valid,
    input wire b_ready,
    output wire [BRESP_WIDTH-1:0] b_resp,

    input wire ar_valid,
    output wire ar_ready,
    input wire [ADDR_WIDTH-1:0] ar_addr,

    output wire r_valid,
    input wire r_ready,
    output wire [DATA_WIDTH-1:0] r_data,
    output wire [RRESP_WIDTH-1:0] r_resp,

    output wire [1:0] aw_status,
    output wire [1:0] w_status,
    output wire [1:0] b_status,
    output wire [1:0] ar_status,
    output wire [1:0] r_status
);

reg r_aw_ready;
reg r_w_ready;
reg r_b_valid;
reg [BRESP_WIDTH-1:0] r_b_resp;
reg r_ar_ready;
reg r_r_valid;
reg [DATA_WIDTH-1:0] r_r_data;
reg [RRESP_WIDTH-1:0] r_r_resp;

assign aw_ready = r_aw_ready;
assign w_ready = r_w_ready;
assign b_valid = r_b_valid;
assign b_resp = r_b_resp;
assign ar_ready = r_ar_ready;
assign r_valid = r_r_valid;
assign r_data = r_r_data;
assign r_resp = r_r_resp;

axi4_base aw_base(
    .enable(1),
    .ready(aw_ready),
    .valid(aw_valid),
    .status(aw_status)
);
axi4_base w_base(
    .enable(1),
    .ready(w_ready),
    .valid(w_valid),
    .status(w_status)
);
axi4_base b_base(
    .enable(1),
    .ready(b_ready),
    .valid(b_valid),
    .status(b_status)
);
axi4_base ar_base(
    .enable(1),
    .ready(ar_ready),
    .valid(ar_valid),
    .status(ar_status)
);
axi4_base r_base(
    .enable(1),
    .ready(r_ready),
    .valid(r_valid),
    .status(r_status)
);

always @(posedge clock or posedge reset) begin
    if (reset) begin
        r_aw_ready <= 0;
        r_w_ready <= 0;
        r_b_valid <= 0;
        r_b_resp <= 0;
        r_ar_ready <= 0;
        r_r_valid <= 0;
        r_r_data <= 0;
        r_r_resp <= 0;
    end else begin
        if (enable) begin
            r_aw_ready <= r_aw_ready;
            r_w_ready <= r_w_ready;
            r_b_valid <= r_b_valid;
            r_ar_ready <= r_ar_ready;
            r_r_valid <= r_r_valid;
        end else begin
            r_aw_ready <= 0;
            r_w_ready <= 0;
            r_b_valid <= 0;
            r_ar_ready <= 0;
            r_r_valid <= 0;
        end
    end
end

endmodule
