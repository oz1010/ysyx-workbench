module uart #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clk,
    input wire rst,

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
    output wire [RRESP_WIDTH-1:0] r_resp
);



endmodule