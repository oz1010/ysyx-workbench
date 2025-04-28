`ifndef __RISCV32E_DEFINES_V__
`define __RISCV32E_DEFINES_V__

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

`define AXI4_WAIT           2'b00
`define AXI4_VALID          2'b01
`define AXI4_READY          2'b10
`define AXI4_COMPLETE       2'b11

`define AXI4_ID_IFU         4'h1
`define AXI4_ID_IDU         4'h2
`define AXI4_ID_LSU         4'h3
`define AXI4_ID_EXU         4'h4
`define AXI4_ID_WBU         4'h5

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
`define DEV_RTC_ADDR_BASE   32'ha000_0048
`define DEV_RTC_ADDR_END    32'ha000_0057

`define DEV_ATTR_READ       4'b0001
`define DEV_ATTR_WRITE      4'b0010
`define DEV_ATTR_EXEC       4'b0100

typedef struct {
    string name;
    logic [3:0] attr;
    logic [31:0] startaddr;
    logic [31:0] endaddr;
} device_info_t;

typedef enum logic [1:0] {
    AXI4_COM_ADDR,
    AXI4_COM_DATA,
    AXI4_COM_RESPONSE
} axi4_com_state_t;

task check_dev_addr(
    input logic [31:0] addr,
    input logic [3:0] attr,
    // output int match_dev_id,
);
    static device_info_t dev_infos[] = '{
        '{name:"SRAM",          startaddr:32'h0f00_0000,    endaddr:32'h0fff_ffff,  attr:(`DEV_ATTR_READ|`DEV_ATTR_WRITE|`DEV_ATTR_EXEC)},
        '{name:"UART16550",     startaddr:32'h1000_0000,    endaddr:32'h1000_0fff,  attr:(`DEV_ATTR_WRITE)},
        '{name:"MROM",          startaddr:32'h2000_0000,    endaddr:32'h2000_0fff,  attr:(`DEV_ATTR_READ|`DEV_ATTR_EXEC)}
    };
    static logic [3:0] device_attrs[] = '{`DEV_ATTR_READ, `DEV_ATTR_WRITE, `DEV_ATTR_EXEC};
    static int match_dev_id;

    match_dev_id = -1;
    foreach (dev_infos[dev_id]) begin
        if (addr>=dev_infos[dev_id].startaddr && addr<=dev_infos[dev_id].endaddr) begin
            match_dev_id = dev_id;
            break;
        end
    end

    if (match_dev_id < 0) begin
        $display("valid dev info is below:");
        for (integer dev_id=0; dev_id<dev_infos.size; ++dev_id) begin
            $display("    %-12s - [0x%08x 0x%08x] 0x%x", 
                dev_infos[dev_id].name, 
                dev_infos[dev_id].startaddr, 
                dev_infos[dev_id].endaddr, 
                dev_infos[dev_id].attr);
        end
        $error("Access Fault, requested addr(0x%x) is out of range.", addr);
    end

    foreach (device_attrs[attr_id]) begin
        if ((attr&device_attrs[attr_id])==0) continue;

        if ((dev_infos[match_dev_id].attr&device_attrs[attr_id])==0) begin
            $display("matched dev info is below:");
            $display("    %-12s - [0x%08x 0x%08x] 0x%x", 
                dev_infos[match_dev_id].name, 
                dev_infos[match_dev_id].startaddr, 
                dev_infos[match_dev_id].endaddr, 
                dev_infos[match_dev_id].attr);
            $error("Access Fault, requested attr(0x%x) does not match dev attr(0x%x) at addr(0x%x).", attr, dev_infos[match_dev_id].attr, addr);
        end
    end

endtask

task get_unalign_parameter(
    input logic [15:0] inst_code,
    input logic [31:0] addr,
    output logic [7:0] len,
    output logic [2:0] size,
    output logic [3:0] strb[0:1],
    output logic [1:0] shift_val
);
    static logic [31:0] s_addr;
    s_addr = addr & (~32'h03); // 4字节对齐
    len = 0; // 数据总burst数量，2^n
    size = 0; // 单个burst数据大小，2^n字节
    // strb = 0;
    shift_val = addr[1:0]; // 4字节对齐
    case (inst_code)
        `INST_SB:           begin size=0; strb[0]=4'h1; end
        `INST_SH:           begin size=1; strb[0]=4'h3; end
        `INST_SW:           begin size=2; strb[0]=4'hf; end
        `INST_LB:           begin size=0; strb[0]=4'h1; end
        `INST_LH:           begin size=1; strb[0]=4'h3; end
        `INST_LW:           begin size=2; strb[0]=4'hf; end
        `INST_LBU:          begin size=0; strb[0]=4'h1; end
        `INST_LHU:          begin size=1; strb[0]=4'h3; end
        default: ;
    endcase

    if ((4-shift_val)<(1<<size)) begin
        len = 1;
        strb[1] = strb[0] >> (4-shift_val);
        strb[0] = strb[0] << shift_val;
    end else begin
        len = 0;
        strb[1] = 0;
        strb[0] = strb[0] << shift_val;
    end
endtask

task read_unalign_data(
    input logic [7:0] idx,
    input logic [15:0] inst_code,
    input logic [31:0] data,
    input logic [1:0] shift_val,
    output logic [31:0] result
);
    static logic [31:0] s_data;
    case (idx)
        0: s_data = data >> (8*shift_val);
        1: s_data = s_data | (data<<(32-8*shift_val));
        default: $error("read unalign data is error");
    endcase

    // 处理符号位
    case (inst_code)
        `INST_LB:           result = sext((s_data) & 32'h000000FF, 8);
        `INST_LH:           result = sext((s_data) & 32'h0000FFFF, 16);
        `INST_LW:           result = sext((s_data) & 32'hFFFFFFFF, 32);
        `INST_LBU:          result = (s_data) & 32'hFF;
        `INST_LHU:          result = (s_data) & 32'hFFFF;
        default: ;
    endcase
endtask

`endif