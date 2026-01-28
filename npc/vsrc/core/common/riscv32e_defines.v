`ifndef __RISCV32E_DEFINES_V__
`define __RISCV32E_DEFINES_V__

`include "generated/autoconf.vh"

`define RISCV_CORE_NUM      1
`define RISCV_INST_WIDTH    32
`define RISCV_GPR_COUNT     32

`define TYPE_R              3'd0
`define TYPE_I              3'd1
`define TYPE_S              3'd2
`define TYPE_B              3'd3
`define TYPE_U              3'd4
`define TYPE_J              3'd5
`define TYPE_INVALID        3'b111

`define INST_CODE_W         10
`define INST_CODE_JUMP      `INST_CODE_W'h100 /* 跳转指令 */
`define INST_CODE_MEM       `INST_CODE_W'h200 /* 存储访问指令 */
`define INST_LUI            (`INST_CODE_W'h001)
`define INST_AUIPC          (`INST_CODE_W'h002)
`define INST_JAL            (`INST_CODE_W'h003|`INST_CODE_JUMP)
`define INST_JALR           (`INST_CODE_W'h004|`INST_CODE_JUMP)
`define INST_BEQ            (`INST_CODE_W'h005|`INST_CODE_JUMP)
`define INST_BNE            (`INST_CODE_W'h006|`INST_CODE_JUMP)
`define INST_BLT            (`INST_CODE_W'h007|`INST_CODE_JUMP)
`define INST_BGE            (`INST_CODE_W'h008|`INST_CODE_JUMP)
`define INST_BLTU           (`INST_CODE_W'h009|`INST_CODE_JUMP)
`define INST_BGEU           (`INST_CODE_W'h00A|`INST_CODE_JUMP)
`define INST_LB             (`INST_CODE_W'h00B|`INST_CODE_MEM)
`define INST_LH             (`INST_CODE_W'h00C|`INST_CODE_MEM)
`define INST_LW             (`INST_CODE_W'h00D|`INST_CODE_MEM)
`define INST_LBU            (`INST_CODE_W'h00E|`INST_CODE_MEM)
`define INST_LHU            (`INST_CODE_W'h00F|`INST_CODE_MEM)
`define INST_SB             (`INST_CODE_W'h010|`INST_CODE_MEM)
`define INST_SH             (`INST_CODE_W'h011|`INST_CODE_MEM)
`define INST_SW             (`INST_CODE_W'h012|`INST_CODE_MEM)
`define INST_ADDI           (`INST_CODE_W'h013)
`define INST_SLTI           (`INST_CODE_W'h014)
`define INST_SLTIU          (`INST_CODE_W'h015)
`define INST_XORI           (`INST_CODE_W'h016)
`define INST_ORI            (`INST_CODE_W'h017)
`define INST_ANDI           (`INST_CODE_W'h018)
`define INST_SLLI           (`INST_CODE_W'h019)
`define INST_SRLI           (`INST_CODE_W'h01A)
`define INST_SRAI           (`INST_CODE_W'h01B)
`define INST_ADD            (`INST_CODE_W'h01C)
`define INST_SUB            (`INST_CODE_W'h01D)
`define INST_SLL            (`INST_CODE_W'h01E)
`define INST_SLT            (`INST_CODE_W'h01F)
`define INST_SLTU           (`INST_CODE_W'h020)
`define INST_XOR            (`INST_CODE_W'h021)
`define INST_SRL            (`INST_CODE_W'h022)
`define INST_SRA            (`INST_CODE_W'h023)
`define INST_OR             (`INST_CODE_W'h024)
`define INST_AND            (`INST_CODE_W'h025)
`define INST_FENCE          (`INST_CODE_W'h026|`INST_CODE_MEM)
`define INST_FENCE_I        (`INST_CODE_W'h027|`INST_CODE_MEM)
`define INST_ECALL          (`INST_CODE_W'h028|`INST_CODE_JUMP)
`define INST_EBREAK         (`INST_CODE_W'h029)
`define INST_CSRRW          (`INST_CODE_W'h02A)
`define INST_CSRRS          (`INST_CODE_W'h02B)
`define INST_CSRRC          (`INST_CODE_W'h02C)
`define INST_CSRRWI         (`INST_CODE_W'h02D)
`define INST_CSRRSI         (`INST_CODE_W'h02E)
`define INST_CSRRCI         (`INST_CODE_W'h02F)
`define INST_MUL            (`INST_CODE_W'h030)
`define INST_MULH           (`INST_CODE_W'h031)
`define INST_MULHSU         (`INST_CODE_W'h032)
`define INST_MULHU          (`INST_CODE_W'h033)
`define INST_DIV            (`INST_CODE_W'h034)
`define INST_DIVU           (`INST_CODE_W'h035)
`define INST_REM            (`INST_CODE_W'h036)
`define INST_REMU           (`INST_CODE_W'h037)
`define INST_MRET           (`INST_CODE_W'h038|`INST_CODE_JUMP)
`define INST_INVALID        (`INST_CODE_W'h0FF) // TODO 若定义为0，某些判断有问题

`define ERR_INV_OPN         -2

`define SCOM_INVALID        2'b00
`define SCOM_FOUND          2'b01
`define SCOM_OTHER          2'b10
`define SCOM_RESET          2'b11

`define AXI4_STATE_ADDR     0
`define AXI4_STATE_DATA     1
`define AXI4_STATE_RESPONSE 2
`define AXI4_STATE_ERROR    3

`define AXI4_ID_IFU         4'h1
`define AXI4_ID_IDU         4'h2
`define AXI4_ID_LSU         4'h3
`define AXI4_ID_EXU         4'h4
`define AXI4_ID_WBU         4'h5
`define AXI4_ID_ICACHE      4'h6
`define AXI4_ID_DCACHE      4'h7

`define SRAM_TYPE_AXI4_LITE 0
`define SRAM_TYPE_AXI4      1
`define SRAM_TYPE_SCOM      2

`define DEV_SRAM_IDX        0
`define DEV_SRAM_ADDR_BASE  32'h8000_0000
`define DEV_SRAM_ADDR_END   32'h80ff_ffff

`define DEV_UART_IDX        1
`define DEV_UART_ADDR_BASE  32'ha000_03f8
`define DEV_UART_ADDR_END   32'ha000_03ff

`define DEV_RTC_IDX         2
`define DEV_RTC_ADDR_BASE   32'h0200_0048
`define DEV_RTC_ADDR_END    32'h0200_0057

`define DEV_ATTR_READ       4'b0001
`define DEV_ATTR_WRITE      4'b0010
`define DEV_ATTR_EXEC       4'b0100

// sdram数据位宽扩展
`define SDRAM_DATA_BITS     32
`define SDRAM_DATA_MASK_BITS (`SDRAM_DATA_BITS/8)
// sdram字扩展，增大容量
`define SDRAM_BLK_BITS      1
`define SDRAM_BLK_NUM      (1<<`SDRAM_BLK_BITS)

`define HW_CPU_STAT_TICK                0
`define HW_CPU_STAT_ICACHE_HIT          1
`define HW_CPU_STAT_ICACHE_MISS         2
`define HW_CPU_STAT_ICACHE_MEM_INDEX    3
`define HW_CPU_STAT_INST                4
`define HW_CPU_STAT_DATA                5
`define HW_CPU_STAT_DCACHE_HIT          6
`define HW_CPU_STAT_DCACHE_MISS         7

`define TRIGGER_EDGE_NEG                0 // 下降沿
`define TRIGGER_EDGE_POS                1 // 上升沿
`define TRIGGER_LEVEL_LOW               2 // 低水平  
`define TRIGGER_LEVEL_HIGH              3 // 高水平

/* axi4总线信号定义 */
`define AXI4_ADDR_W                     32
`define AXI4_DATA_W                     32
`define AXI4_ID_W                       4
`define AXI4_LEN_W                      8
`define AXI4_SIZE_W                     3
`define AXI4_BURST_W                    2
`define AXI4_RESP_W                     2
`define AXI4_AR_CH_W                    (1+1+`AXI4_ADDR_W+`AXI4_ID_W+`AXI4_LEN_W+`AXI4_SIZE_W+`AXI4_BURST_W)
`define AXI4_R_CH_W                     (1+1+`AXI4_RESP_W+`AXI4_DATA_W+1+`AXI4_ID_W)
`define AXI4_BUS_R_W                    (`AXI4_AR_CH_W+`AXI4_R_CH_W)
`define AXI4_BUS_M_IN_W                 (1+1+`AXI4_RESP_W+`AXI4_DATA_W+1+`AXI4_ID_W)
`define AXI4_BUS_M_OUT_W                (1+`AXI4_ADDR_W+`AXI4_ID_W+`AXI4_LEN_W+`AXI4_SIZE_W+`AXI4_BURST_W+1)
`define AXI4_BUS_S_IN_W                 `AXI4_BUS_M_OUT_W
`define AXI4_BUS_S_OUT_W                `AXI4_BUS_M_IN_W
/* 这里不能用inout来实现，否则综合会引入三态电路逻辑
    以下视角为master，slave正好相反
 */
`define AXI4_SIG_DECL(PREFIX) \
    /* input    */  wire                        PREFIX``arready; \
    /* output   */  wire                        PREFIX``arvalid; \
    /* output   */  wire [`AXI4_ADDR_W-1:0]     PREFIX``araddr; \
    /* output   */  wire [`AXI4_ID_W-1:0]       PREFIX``arid; \
    /* output   */  wire [`AXI4_LEN_W-1:0]      PREFIX``arlen; \
    /* output   */  wire [`AXI4_SIZE_W-1:0]     PREFIX``arsize; \
    /* output   */  wire [`AXI4_BURST_W-1:0]    PREFIX``arburst

`define AXI4_BUS_TO_M_SIG(PREFIX, BUS_IN, BUS_OUT) \
    assign BUS_OUT[1 +: 1] = PREFIX``arvalid; \
    assign PREFIX``arready = BUS_IN[0 +: 1]

`define AXI4_BUS_TO_M_SIG_DECL(PREFIX, BUS_IN, BUS_OUT) \
    `AXI4_SIG_DECL(PREFIX); \
    `AXI4_BUS_TO_M_SIG(PREFIX, BUS_IN, BUS_OUT)

`define INNER_CON_STATE_W               1
`define INNER_CON_IDLE                  0
`define INNER_CON_BUSY                  1

`ifdef IN_YOSYS_STA
`else
typedef struct {
    string name;
    logic [31:0] startaddr;
    logic [31:0] endaddr;
} slave_info_t;

typedef struct {
    string name;
    logic [3:0] attr;
    logic [31:0] startaddr;
    logic [31:0] endaddr;
} device_info_t;
`endif

function automatic [31:0] log2;
    input [31:0] value;
    begin
        logic [31:0] result;
        result = 0;
        while (value > 1) begin
            value = value >> 1;
            result = result + 1;
        end
        log2 = result;
    end
endfunction

/* 向上取对数，用于计算最小的数据位宽 */
function automatic [31:0] log2up;
    input [31:0] value;
    begin
        logic [31:0] result;
        result = log2(value);
        log2up = ((value^(1<<result)) > 0) ? result+1 : 
            result==0 ? 1 : result;
    end
endfunction

function void check_dev_addr;
    input logic [31:0] addr;
    input logic [3:0] attr;
    begin

`ifndef IN_YOSYS_STA
        static int ret;
        ret = dpi_check_dev_addr(addr, {28'h0, attr});
        if (ret == 1) $error("Access Fault");
        else if (ret == 2) $error("Access Fault.");
`endif
    end

endfunction

function void get_unalign_parameter;
    input logic [`INST_CODE_W-1:0] inst_code;
    input logic [31:0] addr;
    output logic [7:0] len;
    output logic [2:0] size;
    output logic [7:0] strb;
    output logic [1:0] shift_val;
    begin
        logic [31:0] s_addr;
        s_addr = addr & (~32'h03); // 4字节对齐
        len = 0; // 数据总burst数量，2^n
        size = 0; // 单个burst数据大小，2^n字节
        // strb = 0;
        shift_val = addr[1:0]; // 4字节对齐
        case (inst_code)
            `INST_SB:           begin size=0; strb[0 +: 4]=4'h1; end
            `INST_SH:           begin size=1; strb[0 +: 4]=4'h3; end
            `INST_SW:           begin size=2; strb[0 +: 4]=4'hf; end
            `INST_LB:           begin size=0; strb[0 +: 4]=4'h1; end
            `INST_LH:           begin size=1; strb[0 +: 4]=4'h3; end
            `INST_LW:           begin size=2; strb[0 +: 4]=4'hf; end
            `INST_LBU:          begin size=0; strb[0 +: 4]=4'h1; end
            `INST_LHU:          begin size=1; strb[0 +: 4]=4'h3; end
            default: ;
        endcase

        if ((4-shift_val)<(1<<size)) begin
            len = 1;
            strb[4 +: 4] = strb[0 +: 4] >> (4-shift_val);
            strb[0 +: 4] = strb[0 +: 4] << shift_val;
        end else begin
            len = 0;
            strb[4 +: 4] = 0;
            strb[0 +: 4] = strb[0 +: 4] << shift_val;
        end
    end
endfunction

function void get_unalign_addr_parameter;
    input logic [2:0] size;
    input logic [31:0] addr;
    output logic [7:0] len;
    output logic [7:0] strb;
    output logic [1:0] shift_val;
    begin
        logic [31:0] s_addr;
        s_addr = addr & (~32'h03); // 4字节对齐
        len = 0; // 数据总burst数量，2^n
        shift_val = addr[1:0]; // 4字节对齐
        case (size)
            0:           begin strb[0 +: 4]=4'h1; end
            1:           begin strb[0 +: 4]=4'h3; end
            2:           begin strb[0 +: 4]=4'hf; end
            default: ;
        endcase

        if ((4-shift_val)<(1<<size)) begin
            len = 1;
            strb[4 +: 4] = strb[0 +: 4] >> (4-shift_val);
            strb[0 +: 4] = strb[0 +: 4] << shift_val;
        end else begin
            len = 0;
            strb[4 +: 4] = 0;
            strb[0 +: 4] = strb[0 +: 4] << shift_val;
        end
    end
endfunction

function void read_unalign_data;
    input logic [7:0] idx;
    input logic [`INST_CODE_W-1:0] inst_code;
    input logic [31:0] data;
    input logic [1:0] shift_val;
    output logic [31:0] result;
    begin
        logic [31:0] s_data;
        case (idx)
            0: s_data = data >> (8*shift_val);
            1: s_data = s_data | (data<<(32-8*shift_val));

            `ifndef IN_YOSYS_STA
            default: $error("read unalign data is error");
            `endif
        endcase

        // 处理符号位
        case (inst_code)
            `INST_LB:           result = func_sext((s_data) & 32'h000000FF, 8);
            `INST_LH:           result = func_sext((s_data) & 32'h0000FFFF, 16);
            `INST_LW:           result = func_sext((s_data) & 32'hFFFFFFFF, 32);
            `INST_LBU:          result = (s_data) & 32'hFF;
            `INST_LHU:          result = (s_data) & 32'hFFFF;
            default: ;
        endcase
    end
endfunction

// function void get_unalign_addr_data;
//     input   logic [7:0]         idx;
//     input   logic               is_sign;
//     input   logic [2:0]         size;
//     input   logic [31:0]        in_data;
//     input   logic [1:0]         shift_val;
//     output  logic [31:0]        result;
//     begin
//         logic [31:0] s_data;
//         logic [31:0] data0;
//         logic [31:0] size0;
//         case (idx)
//             0: s_data = in_data >> (8*shift_val);
//             1: s_data = s_data | (in_data<<(32-8*shift_val));

//             `ifndef IN_YOSYS_STA
//             default: $error("read unalign in_data is error idx %x", idx);
//             `endif
//         endcase

//         // 处理大小
//         size0 = 8*(1<<size);
//         case (size)
//             0:  data0 = (s_data) & 32'h000000FF;
//             1:  data0 = (s_data) & 32'h0000FFFF;
//             2:  data0 = (s_data) & 32'hFFFFFFFF;
//             default: ;
//         endcase

//         // 处理符号位
//         result = is_sign ? func_sext(data0, size0) : data0;
//     end
// endfunction

// 直接处理64位数据（拼接的两个数据）
function void get_unalign_addr_data;
    input   logic               is_sign;
    input   logic [2:0]         size;
    input   logic [63:0]        in_data;
    input   logic [1:0]         shift_val;
    output  logic [31:0]        result;
    begin
        logic [31:0] s_data;
        logic [31:0] data0;
        logic [31:0] size0;
        s_data = in_data[8*shift_val +: 32];

        // 处理大小
        size0 = 8*(1<<size);
        case (size)
            0:  data0 = (s_data) & 32'h000000FF;
            1:  data0 = (s_data) & 32'h0000FFFF;
            2:  data0 = (s_data) & 32'hFFFFFFFF;
            default: ;
        endcase

        // 处理符号位
        result = is_sign ? func_sext(data0, size0) : data0;
    end
endfunction

// 由掩码（1为有效位）计算偏移和数据大小
function void get_unalign_from_mask;
    input logic[3:0] mask;
    output logic[1:0] offset;
    output logic[2:0] size;
    begin
        case(mask)
            4'b0001: begin offset=0; size=1; end
            4'b0010: begin offset=1; size=1; end
            4'b0100: begin offset=2; size=1; end
            4'b1000: begin offset=3; size=1; end
            4'b0011: begin offset=0; size=2; end
            4'b0110: begin offset=1; size=2; end
            4'b1100: begin offset=2; size=2; end
            4'b0111: begin offset=0; size=3; end
            4'b1110: begin offset=1; size=3; end
            4'b1111: begin offset=0; size=4; end
            default: begin offset=0; size=0; end
        endcase
    end
endfunction

function void func_exit_simu;
    input [31:0]exit_code;
    begin
`ifdef IN_YOSYS_STA
        global_pc = global_pc + exit_code;
`else
        exit_simu(exit_code);
`endif
    end
endfunction

function void func_invalid_inst;
    input [31:0] current_pc;
    input [31:0] current_inst;
    begin
`ifdef IN_YOSYS_STA
        global_pc = global_pc + current_pc + current_inst;
`else
        invalid_inst(current_pc, current_inst);
`endif
    end
endfunction


function automatic [31:0] func_raise_intr;
    input [31:0] cause;
    input [31:0] current_pc;
    begin
`ifdef IN_YOSYS_STA
        global_ret_pc = current_pc;
        func_raise_intr = global_pc;
`else
        func_raise_intr = dpi_raise_intr(cause, current_pc);
`endif
    end
endfunction

function automatic [31:0] func_read_raw_csr;
    input [31:0] imm;
    begin
`ifdef IN_YOSYS_STA
        logic [2:0] csr_idx;
        case (imm[11:0])
            32'h300: csr_idx = 1; // mstatus寄存器 - 存放处理器的状态
            32'h305: csr_idx = 2; // mtvec寄存器 - 存放trap-handler基地址
            32'h341: csr_idx = 3; // mepc寄存器 - 存放触发异常的PC
            32'h342: csr_idx = 4; // mcause寄存器 - 存放触发异常的原因
            32'hf11: csr_idx = 5; // Vendor ID, ysyx的ASCII码, 即0x79737978
            32'hf12: csr_idx = 6; // Architecture ID, 学号数字部分（23060295）的十进制表示，即0x15FDF47
            default: csr_idx = 0; // Invalid
        endcase
        func_read_raw_csr = global_csrs[csr_idx];
`else
        func_read_raw_csr = read_raw_csr(imm);
`endif
    end
endfunction

function void func_write_raw_csr;
    input [31:0] imm;
    input [31:0] src1;
    begin
`ifdef IN_YOSYS_STA
        logic [2:0] csr_idx;
        case (imm[11:0])
            32'h300: csr_idx = 1; // mstatus寄存器 - 存放处理器的状态
            32'h305: csr_idx = 2; // mtvec寄存器 - 存放trap-handler基地址
            32'h341: csr_idx = 3; // mepc寄存器 - 存放触发异常的PC
            32'h342: csr_idx = 4; // mcause寄存器 - 存放触发异常的原因
            32'hf11: csr_idx = 5; // Vendor ID, ysyx的ASCII码, 即0x79737978
            32'hf12: csr_idx = 6; // Architecture ID, 学号数字部分（23060295）的十进制表示，即0x15FDF47
            default: csr_idx = 0; // Invalid
        endcase
        // 使用异步方式写入csr
        gloabl_csr_write_addr = csr_idx;
        gloabl_csr_write_value = src1;
`else
        write_raw_csr(imm, src1);
`endif
    end
endfunction

function automatic [31:0] func_query_intr;
    begin
`ifdef IN_YOSYS_STA
        func_query_intr = global_ret_pc;
`else
        func_query_intr = dpi_query_intr();
`endif
    end
endfunction

function void func_cpu_stat_ctrl;
    input [31:0] dtype;
    input [31:0] delta;
    begin
`ifdef IN_YOSYS_STA
        global_pc = global_pc + delta;
`else
        dpi_cpu_stat_ctrl(dtype, delta);
`endif
    end
endfunction

function automatic [31:0] func_get_reset_pc;
    begin
`ifdef IN_YOSYS_STA
        func_get_reset_pc = global_pc + 4;
`else
        func_get_reset_pc = get_reset_pc();
`endif
    end
endfunction

function automatic [31:0] func_test_intf;
    input [31:0] write;
    input [31:0] addr;
    input [31:0] len;
    input [31:0] data;
    begin
`ifdef IN_YOSYS_STA
`else
    func_test_intf = dpi_test_intf(write, addr, len, data);
`endif
    end
endfunction

function void func_dev_skip;
    input [31:0] write;
    input [31:0] addr;
    input [31:0] req_info;
    input [31:0] data;
    begin
`ifdef IN_YOSYS_STA
`else
    dpi_dev_skip(write, addr, req_info, data);
`endif
    end
endfunction

function automatic [31:0] func_sext;
    input [31:0] x;
    input [31:0] len;
    begin
`ifdef IN_YOSYS_STA
    func_sext = x;
`else
    func_sext = sext(x, len);
`endif 
    end
endfunction

function void func_monitor_item;
    input [31:0] item_idx;
    input [31:0] id;
    input [31:0] delta;
    begin
`ifdef IN_YOSYS_STA
`else
        dpi_monitor_item(item_idx, id, delta);
`endif
    end
endfunction

`endif
