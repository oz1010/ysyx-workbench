// integer control and status register
module csrs #(
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input   wire                        clk,
    input   wire                        rst,

    /* 读寄存器接口 */
    input   wire [`CSR_ADDR_W-1:0]      raddr,
    output  wire [DATA_WIDTH-1:0]       rdata,
    
    // 普通csr写入
    input   wire                        wen,
    input   wire [`CSR_ADDR_W-1:0]      waddr,
    input   wire [DATA_WIDTH-1:0]       wdata,

    /* 异常写入接口 */
    input   wire                        expt_en,
    input   wire [INST_WIDTH-1:0]       expt_epc,
    input   wire [DATA_WIDTH-1:0]       expt_cause,
    input   wire [DATA_WIDTH-1:0]       expt_tval
);

    localparam CSR_INDEX_COUNT = `CSR_RO_COUNT + `CSR_WRITE_COUNT + 1;
    localparam CSR_INDEX_W = log2up(CSR_INDEX_COUNT);

    /* 寄存器组 */
    // TODO 增加一个寄存器读写权限数组，避免映射地址
    reg [DATA_WIDTH-1:0] csrs[0:CSR_INDEX_COUNT-1];

    /* 访问读取 */
    assign rdata = csrs[func_get_csr_index(raddr)];

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
    always @(posedge clk ) begin
        if (rst) begin
            csrs[0] <= 0;
            csrs[func_get_csr_index(`CSR_MSTATUS)] <= csr_mstatus_data;
            csrs[func_get_csr_index(`CSR_MVENDORID)] <= csr_mvendorid_data;
            csrs[func_get_csr_index(`CSR_MARCHID)] <= csr_marchid_data;
            csrs[func_get_csr_index(`CSR_MTVEC)] <= 0;
            csrs[func_get_csr_index(`CSR_MEPC)] <= 0;
            csrs[func_get_csr_index(`CSR_MCAUSE)] <= 0;

            // TODO 后面需要改为一个通知接口，用于同步更新cpu中数据，包含gpr csr pc dnpc等等
            // 开diff后，需要将初始数据写入cpu.csr
            `ifdef CONFIG_DIFFTEST
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MSTATUS}, csr_mstatus_data);
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MTVEC}, 0);
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MEPC}, 0);
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MCAUSE}, 0);
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MVENDORID}, csr_mvendorid_data);
            func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MARCHID}, csr_marchid_data);
            `endif
        end else begin
            // 响应异常写（在普通写之后执行，若普通写未覆盖则生效
            if (expt_en) begin
                csrs[func_get_csr_index(`CSR_MEPC)] <= expt_epc;
                csrs[func_get_csr_index(`CSR_MCAUSE)] <= expt_cause;
                csrs[func_get_csr_index(`CSR_MTVAL)] <= expt_tval;

                `ifdef CONFIG_DIFFTEST
                // 开diff后，需要将数据同步写入cpu.csr
                func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MEPC}, expt_epc);
                func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MCAUSE}, expt_cause);
                func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MTVAL}, expt_tval);
                `endif
            end

            // 优先响应普通 CSR 写，异常写入后，相同寄存器会被覆盖
            if (wen) begin
                csrs[func_get_csr_index(waddr)] <= wdata;

                `ifdef CONFIG_DIFFTEST
                // 开diff后，需要将数据同步写入cpu.csr
                func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), waddr}, wdata);
                `endif
            end

            /* 只读寄存器赋值 */
            csrs[0] <= 0;
            csrs[func_get_csr_index(`CSR_MVENDORID)] <= csr_mvendorid_data;
            csrs[func_get_csr_index(`CSR_MARCHID)] <= csr_marchid_data;
        end
    end
endmodule
