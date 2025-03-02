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
    input wire clk,
    input wire rst,
    input wire enable,

    output wire aw_valid,
    input wire aw_ready,
    output wire [ADDR_WIDTH-1:0] aw_addr,
    output wire [2:0] aw_prot,

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
    output wire [2:0] ar_prot,

    input wire r_valid,
    output wire r_ready,
    input wire [DATA_WIDTH-1:0] r_data,
    input wire [RRESP_WIDTH-1:0] r_resp
);

reg r_aw_valid;
reg [ADDR_WIDTH-1:0] r_aw_addr;
reg [2:0] r_aw_prot;
reg r_w_valid;
reg [DATA_WIDTH-1:0] r_w_data;
reg [DATA_WIDTH/8-1:0] r_w_strb;
reg r_b_ready;
reg r_ar_valid;
reg [ADDR_WIDTH-1:0] r_ar_addr;
reg [2:0] r_ar_prot;
reg r_r_ready;

assign aw_valid = r_aw_valid;
assign aw_addr = r_aw_addr;
assign aw_prot = r_aw_prot;
assign w_valid = r_w_valid;
assign w_data = r_w_data;
assign w_strb = r_w_strb;
assign b_ready = r_b_ready;
assign ar_valid = r_ar_valid;
assign ar_addr = r_ar_addr;
assign ar_prot = r_ar_prot;
assign r_ready = r_r_ready;

wire [1:0] aw_status,w_status,b_status,ar_status,r_status;

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

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_aw_valid <= 0;
        r_aw_addr <= 0;
        r_aw_prot <= 0;
        r_w_valid <= 0;
        r_w_data <= 0;
        r_w_strb <= 0;
        r_b_ready <= 0;
        r_ar_valid <= 0;
        r_ar_addr <= 0;
        r_ar_prot <= 0;
        r_r_ready <= 0;
    end else begin
        if (enable) begin
            r_aw_valid <= r_aw_valid;
            r_aw_addr <= r_aw_addr;
            r_aw_prot <= r_aw_prot;
            r_w_valid <= r_w_valid;
            r_w_data <= r_w_data;
            r_w_strb <= r_w_strb;
            r_b_ready <= r_b_ready;
            r_ar_valid <= r_ar_valid;
            r_ar_addr <= r_ar_addr;
            r_ar_prot <= r_ar_prot;
            r_r_ready <= r_r_ready;
        end else begin
            r_aw_valid <= 0;
            r_aw_addr <= 0;
            r_aw_prot <= 0;
            r_w_valid <= 0;
            r_w_data <= 0;
            r_w_strb <= 0;
            r_b_ready <= 0;
            r_ar_valid <= 0;
            r_ar_addr <= 0;
            r_ar_prot <= 0;
            r_r_ready <= 0;
        end
    end
end

endmodule
