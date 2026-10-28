// integer control and status register
module csrs #(
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input   wire                        clock,
    input   wire                        reset,

    /* 读寄存器接口 */
    input   wire [`CSR_ADDR_W-1:0]      raddr,
    output  reg  [DATA_WIDTH-1:0]       rdata,
    output  wire [DATA_WIDTH-1:0]       status,
    output  wire [DATA_WIDTH-1:0]       mepc,
    output  wire [DATA_WIDTH-1:0]       mtvec,

    // 普通csr写入
    input   wire                        wen,
    input   wire [`CSR_ADDR_W-1:0]      waddr,
    input   wire [DATA_WIDTH-1:0]       wdata,

    /* 异常写入接口 */
    input   wire                        trap_en,
    input   wire [INST_WIDTH-1:0]       trap_epc,
    input   wire [DATA_WIDTH-1:0]       trap_cause,
    input   wire [DATA_WIDTH-1:0]       trap_tval,
    input   wire [DATA_WIDTH-1:0]       trap_status
);

    /* 稀疏寄存器组 */
    reg [DATA_WIDTH-1:0] csr_mstatus;
    reg [DATA_WIDTH-1:0] csr_mtvec;
    reg [DATA_WIDTH-1:0] csr_mepc;
    reg [DATA_WIDTH-1:0] csr_mcause;
    reg [DATA_WIDTH-1:0] csr_mtval;

    /* 常量数据 */
    /**
    * https://ysyx.oscc.cc/docs/2306/basic/1.8.html#%E4%BB%8Eflash%E4%B8%AD%E5%8F%96%E6%8C%87 添加学号CSR并输出学号
    * DATA_WIDTH'('h79737978)
    */
    wire [DATA_WIDTH-1:0] csr_mvendorid_data = "ysyx";
    /**
    * DATA_WIDTH'('h15FDF47)
    */
    wire [DATA_WIDTH-1:0] csr_marchid_data = DATA_WIDTH'('h15FDF47);
    wire [DATA_WIDTH-1:0] csr_mstatus_data;
    `ifdef CONFIG_RV64
    assign csr_mstatus_data = DATA_WIDTH'('ha00001800);
    `else
    assign csr_mstatus_data = DATA_WIDTH'('h000001800);
    `endif

    /* 未实现的地址读零，只读寄存器忽略写入 */
    always @(*) begin
        case (raddr)
            `CSR_MSTATUS:   rdata = csr_mstatus;
            `CSR_MTVEC:     rdata = csr_mtvec;
            `CSR_MEPC:      rdata = csr_mepc;
            `CSR_MCAUSE:    rdata = csr_mcause;
            `CSR_MTVAL:     rdata = csr_mtval;
            `CSR_MVENDORID: rdata = csr_mvendorid_data;
            `CSR_MARCHID:   rdata = csr_marchid_data;
            default:        rdata = {DATA_WIDTH{1'b0}};
        endcase
    end

    assign status = csr_mstatus;
    assign mepc   = csr_mepc;
    assign mtvec  = csr_mtvec;

    wire csr_wen = wen && (
        (waddr == `CSR_MSTATUS) ||
        (waddr == `CSR_MTVEC) ||
        (waddr == `CSR_MEPC) ||
        (waddr == `CSR_MCAUSE) ||
        (waddr == `CSR_MTVAL)
    );

    always @(posedge clock) begin
        if (reset) begin
            csr_mstatus <= csr_mstatus_data;
            csr_mtvec   <= 0;
            csr_mepc    <= 0;
            csr_mcause  <= 0;
            csr_mtval   <= 0;

            // TODO 后面需要改为一个通知接口，用于同步更新cpu中数据，包含gpr csr pc dnpc等等
            // 开diff后，需要将初始数据写入cpu.csr
            `ifdef CONFIG_DIFFTEST
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MSTATUS}, csr_mstatus_data);
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MTVEC}, 0);
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MEPC}, 0);
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MCAUSE}, 0);
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MTVAL}, 0);
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MVENDORID}, csr_mvendorid_data);
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MARCHID}, csr_marchid_data);
            `endif
        end else begin
            if (csr_wen) begin
                case (waddr)
                    `CSR_MSTATUS: csr_mstatus <= wdata;
                    `CSR_MTVEC:   csr_mtvec   <= wdata;
                    `CSR_MEPC:    csr_mepc    <= wdata;
                    `CSR_MCAUSE:  csr_mcause  <= wdata;
                    `CSR_MTVAL:   csr_mtval   <= wdata;
                    default: ;
                endcase

                `ifdef CONFIG_DIFFTEST
                func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), waddr}, wdata);
                `endif
            end

            // 普通写之后响应陷阱，同一拍写同一寄存器时陷阱值优先
            if (trap_en) begin
                csr_mstatus <= trap_status;
                csr_mepc    <= trap_epc;
                csr_mcause  <= trap_cause;
                csr_mtval   <= trap_tval;

                `ifdef CONFIG_DIFFTEST
                func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MSTATUS}, trap_status);
                func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MEPC}, trap_epc);
                func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MCAUSE}, trap_cause);
                func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MTVAL}, trap_tval);
                `endif
            end
        end
    end
endmodule
