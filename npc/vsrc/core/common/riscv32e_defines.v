`ifndef __RISCV32E_DEFINES_V__
`define __RISCV32E_DEFINES_V__

`include "generated/autoconf.vh"

`define RISCV_CORE_NUM      1
`define RISCV_INST_WIDTH    32
`define RISCV_CSR_COUNT     32

`define TYPE_R              3'd0
`define TYPE_I              3'd1
`define TYPE_S              3'd2
`define TYPE_B              3'd3
`define TYPE_U              3'd4
`define TYPE_J              3'd5
`define TYPE_INVALID        3'b111

`define INST_LUI            16'd0
`define INST_AUIPC          16'd1
`define INST_JAL            16'd2
`define INST_JALR           16'd3
`define INST_BEQ            16'd4
`define INST_BNE            16'd5
`define INST_BLT            16'd6
`define INST_BGE            16'd7
`define INST_BLTU           16'd8
`define INST_BGEU           16'd9
`define INST_LB             16'd10
`define INST_LH             16'd11
`define INST_LW             16'd12
`define INST_LBU            16'd13
`define INST_LHU            16'd14
`define INST_SB             16'd15
`define INST_SH             16'd16
`define INST_SW             16'd17
`define INST_ADDI           16'd18
`define INST_SLTI           16'd19
`define INST_SLTIU          16'd20
`define INST_XORI           16'd21
`define INST_ORI            16'd22
`define INST_ANDI           16'd23
`define INST_SLLI           16'd24
`define INST_SRLI           16'd25
`define INST_SRAI           16'd26
`define INST_ADD            16'd27
`define INST_SUB            16'd28
`define INST_SLL            16'd29
`define INST_SLT            16'd30
`define INST_SLTU           16'd31
`define INST_XOR            16'd32
`define INST_SRL            16'd33
`define INST_SRA            16'd34
`define INST_OR             16'd35
`define INST_AND            16'd36
`define INST_FENCE          16'd37
`define INST_FENCE_I        16'd38
`define INST_ECALL          16'd39
`define INST_EBREAK         16'd40
`define INST_CSRRW          16'd41
`define INST_CSRRS          16'd42
`define INST_CSRRC          16'd43
`define INST_CSRRWI         16'd44
`define INST_CSRRSI         16'd45
`define INST_CSRRCI         16'd46
`define INST_MUL            16'd47
`define INST_MULH           16'd48
`define INST_MULHSU         16'd49
`define INST_MULHU          16'd50
`define INST_DIV            16'd51
`define INST_DIVU           16'd52
`define INST_REM            16'd53
`define INST_REMU           16'd54
`define INST_MRET           16'd55
`define INST_INVALID        16'hffff

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
    input logic [15:0] inst_code;
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
    input logic [15:0] inst_code;
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

function void get_unalign_addr_data;
    input   logic [7:0]         idx;
    input   logic               is_sign;
    input   logic [2:0]         size;
    input   logic [31:0]        in_data;
    input   logic [1:0]         shift_val;
    output  logic [31:0]        result;
    begin
        logic [31:0] s_data;
        logic [31:0] data0;
        logic [31:0] size0;
        case (idx)
            0: s_data = in_data >> (8*shift_val);
            1: s_data = s_data | (in_data<<(32-8*shift_val));

            `ifndef IN_YOSYS_STA
            default: $error("read unalign in_data is error idx %x", idx);
            `endif
        endcase

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
        func_read_raw_csr = global_csrs[imm[11:0]];
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
        // 使用异步方式写入csr
        // global_csrs[imm[11:0]] = src1;
        gloabl_csr_write_addr = imm[11:0];
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
