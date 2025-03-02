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
    output wire[ADDR_WIDTH-1:0] ar_addr,
    output wire [2:0] ar_prot,

    input wire r_valid,
    output wire r_ready,
    input wire [DATA_WIDTH-1:0] r_data,
    input wire [RRESP_WIDTH-1:0] r_resp
);
    
endmodule
