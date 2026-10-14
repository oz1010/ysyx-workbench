// integer control and status register
module csrs #(
    parameter DATA_WIDTH = 32
) (
    input   wire                        clk,
    input   wire                        rst,

    /* 读寄存器接口 */
    input   wire [`CSR_ADDR_W-1:0]      raddr,
    output  wire [DATA_WIDTH-1:0]       rdata,
    
    /* 写寄存器接口 */
    input   wire [`CSR_WCH_W-1:0]       csr_wch,

    output  wire [`CORE_STATUS_W-1:0]   cscode
);

    localparam CSR_INDEX_COUNT = `CSR_RO_COUNT + `CSR_WRITE_COUNT + 1;
    localparam CSR_INDEX_W = log2up(CSR_INDEX_COUNT);

    assign cscode = 0;

    /* 寄存器组 */
    reg [DATA_WIDTH-1:0] csrs[0:CSR_INDEX_COUNT-1];
    /* 寄存器别名 */
    wire [DATA_WIDTH-1:0] csr_mstatus = csrs[func_get_csr_index(`CSR_MSTATUS)];
    wire [DATA_WIDTH-1:0] csr_mtvec = csrs[func_get_csr_index(`CSR_MTVEC)];
    wire [DATA_WIDTH-1:0] csr_mepc = csrs[func_get_csr_index(`CSR_MEPC)];
    wire [DATA_WIDTH-1:0] csr_mcause = csrs[func_get_csr_index(`CSR_MCAUSE)];
    wire [DATA_WIDTH-1:0] csr_mvendorid = csrs[func_get_csr_index(`CSR_MVENDORID)];
    wire [DATA_WIDTH-1:0] csr_marchid = csrs[func_get_csr_index(`CSR_MARCHID)];

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


    /* 访问读取 */
    assign rdata = csrs[func_get_csr_index(raddr)];

    /* 写入通道拆分 */
    wire                            csr_wen[0:`CSR_WCH_ITEM_COUNT-1];
    wire  [`CSR_ADDR_W-1:0]         csr_waddr[0:`CSR_WCH_ITEM_COUNT-1];
    wire  [31:0]                    csr_wdata[0:`CSR_WCH_ITEM_COUNT-1];
    assign {
        csr_wen[2], csr_wen[1], csr_wen[0],
        csr_waddr[2], csr_waddr[1], csr_waddr[0],
        csr_wdata[2], csr_wdata[1], csr_wdata[0]
    } = csr_wch;

    /* 
    * 减低延时（提高频率）优化策略：
    *   - 使用onehot编码，避免使用多位比较器
    *   - generate循环可以用MUX代替解码器
    */
    wire [CSR_INDEX_COUNT-1:0] wen_onehot[0:`CSR_WCH_ITEM_COUNT-1];
    initial begin
        `ifdef CONFIG_RV64
        func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MSTATUS}, DATA_WIDTH'('ha00001800));
        `else
        func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MSTATUS}, DATA_WIDTH'('h000001800));
        `endif
        `ifdef CONFIG_DIFFTEST
        // 开diff后，需要将数据同步写入cpu.csr，用于同步到ref中。
        func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MVENDORID}, csr_mvendorid_data);
        func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), `CSR_MARCHID}, csr_marchid_data);
        `endif
    end
    /* TODO 只读寄存器，这里仿真使用寄存器方便取值；实际推荐使用组合电路直接固定值 */
    assign csrs[0] = 0;
    assign csrs[func_get_csr_index(`CSR_MVENDORID)] = csr_mvendorid_data;
    assign csrs[func_get_csr_index(`CSR_MARCHID)] = csr_marchid_data;
    genvar i, j;
    for (j=0; j<`CSR_WCH_ITEM_COUNT; ++j) begin
        assign wen_onehot[j] = csr_wen[j] ? (1 << func_get_csr_index(csr_waddr[j])) : 0;
    end
`ifdef FORMAL_VERIFY
    /* 
    * 形式化验证要求DUT与REF的CSR具有相同的初始状态，复位时初始化可写CSR。
    * 索引约定与func_get_csr_index一致：1=mstatus 2=mtvec 3=mepc 4=mcause
    * mvendorid(5)/marchid(6)为只读常量，不在此处驱动。
    */
    always @(posedge clk) begin
        if (rst) begin
            csrs[1] <= 32'h0000_1800;
            csrs[2] <= 32'h0000_1000;
            csrs[3] <= 32'h0000_1000;
            csrs[4] <= 0;
        end else begin
            for (integer jj=0; jj<`CSR_WCH_ITEM_COUNT; ++jj) begin
                for (integer ii=1; ii<CSR_INDEX_COUNT; ++ii) begin
                    if (ii!=func_get_csr_index(`CSR_MVENDORID) &&
                        ii!=func_get_csr_index(`CSR_MARCHID) &&
                        wen_onehot[jj][ii]) begin
                        csrs[ii] <= csr_wdata[jj];
                    end
                end
            end
        end
    end
`else
    for (j=0; j<`CSR_WCH_ITEM_COUNT; ++j) begin
        for (i=1 ; i<CSR_INDEX_COUNT; ++i) begin
            always @(posedge clk) begin
                if (!(
                    i==0 ||
                    i==func_get_csr_index(`CSR_MVENDORID) ||
                    i==func_get_csr_index(`CSR_MARCHID)
                )) begin
                    // csrs[i] <= wen_onehot[j][i] ? wdata : csrs[i];
                    if (wen_onehot[j][i]) begin
                        csrs[i] <= csr_wdata[j];

                        `ifdef CONFIG_DIFFTEST
                        // 开diff后，需要将数据同步写入cpu.csr，用于同步到ref中。
                        func_write_raw_csr({(32-`CSR_ADDR_W)'('h0), csr_waddr[j]}, csr_wdata[j]);
                        `endif
                    end
                        
                end
            end
        end
    end
`endif

endmodule
