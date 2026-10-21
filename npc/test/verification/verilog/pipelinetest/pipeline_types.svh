`ifndef PIPELINE_CHISEL_TYPES_SVH
`define PIPELINE_CHISEL_TYPES_SVH

// One in-order, non-control-flow instruction; at most one MEM transaction.
typedef struct packed {
    logic [31:0] seq_id;
    logic retired;
    logic gpr_wen;
    logic [3:0] gpr_waddr;
    logic [31:0] gpr_wdata;
    logic mem_req;
    logic mem_rsp;
    logic [31:0] mem_addr;
    logic [3:0] mem_op;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
    logic csr_wen;
    logic [11:0] csr_waddr;
    logic [31:0] csr_wdata;
    logic trap_en;
    logic [31:0] trap_epc;
    logic [31:0] trap_cause;
    logic [31:0] trap_tval;
    logic [31:0] trap_status;
} instruction_record_t;

`endif
