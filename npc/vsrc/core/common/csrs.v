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
    input   wire                        wen,
    input   wire [`CSR_ADDR_W-1:0]      waddr,
    input   wire [DATA_WIDTH-1:0]       wdata,

    output  wire [`CORE_STATUS_W-1:0]   cscode
);

localparam CSR_INDEX_COUNT = `CSR_RO_COUNT + `CSR_WRITE_COUNT + 1;
localparam CSR_INDEX_W = log2up(CSR_INDEX_COUNT);

assign cscode = 0;

/*
* csr数量最大为4K，为减少综合逻辑，采用重映射方式，只实现当前需要的寄存器
*/
function automatic[CSR_INDEX_W-1:0] get_csr_index;
    input [`CSR_ADDR_W-1:0] addr;
    begin
        logic [CSR_INDEX_W-1:0] csr_index;
        case (addr)
            `CSR_MSTATUS: csr_index = 1;
            `CSR_MTVEC: csr_index = 2;
            `CSR_MEPC: csr_index = 3;
            `CSR_MCAUSE: csr_index = 4;
            `CSR_MVENDORID: csr_index = 5;
            `CSR_MARCHID: csr_index = 6;
            default: csr_index = 0;
        endcase
        get_csr_index = csr_index;
    end
endfunction

/* 寄存器组 */
reg [DATA_WIDTH-1:0] csrs[0:CSR_INDEX_COUNT-1];
/* 寄存器别名 */
wire [DATA_WIDTH-1:0] csr_mstatus = csrs[get_csr_index(`CSR_MSTATUS)];
wire [DATA_WIDTH-1:0] csr_mtvec = csrs[get_csr_index(`CSR_MTVEC)];
wire [DATA_WIDTH-1:0] csr_mepc = csrs[get_csr_index(`CSR_MEPC)];
wire [DATA_WIDTH-1:0] csr_mcause = csrs[get_csr_index(`CSR_MCAUSE)];
wire [DATA_WIDTH-1:0] csr_mvendorid = csrs[get_csr_index(`CSR_MVENDORID)];
wire [DATA_WIDTH-1:0] csr_marchid = csrs[get_csr_index(`CSR_MARCHID)];

/* 访问读取 */
assign rdata = csrs[get_csr_index(raddr)];

/* 
* 减低延时（提高频率）优化策略：
*   - 使用onehot编码，避免使用多位比较器
*   - generate循环可以用MUX代替解码器
*/
reg [CSR_INDEX_W-1:0] windex;
always @(*) begin
    windex = get_csr_index(waddr);
end
wire [CSR_INDEX_COUNT-1:0] wen_onehot;
assign wen_onehot = wen ? (1 << windex) : 0;
initial begin
    `ifdef CONFIG_RV64
    csrs[get_csr_index(`CSR_MSTATUS)] = DATA_WIDTH'('ha00001800);
    `else
    csrs[get_csr_index(`CSR_MSTATUS)] = DATA_WIDTH'('h000001800);
    `endif
end
/* TODO 只读寄存器，这里仿真使用寄存器方便取值；实际推荐使用组合电路直接固定值 */
assign csrs[0] = 0;
/**
* https://ysyx.oscc.cc/docs/2306/basic/1.8.html#%E4%BB%8Eflash%E4%B8%AD%E5%8F%96%E6%8C%87 添加学号CSR并输出学号
* DATA_WIDTH'('h79737978)
*/
assign csrs[get_csr_index(`CSR_MVENDORID)] = "ysyx";
/**
* DATA_WIDTH'('h15FDF47)
*/
assign csrs[get_csr_index(`CSR_MARCHID)] = DATA_WIDTH'('h15FDF47);
genvar i;
for (i=1 ; i<CSR_INDEX_COUNT; ++i) begin
    always @(posedge clk) begin
        if (!(
            i==0 ||
            i==`CSR_MVENDORID ||
            i==`CSR_MARCHID
        )) begin
            csrs[i] <= wen_onehot[i] ? wdata : csrs[i];
        end
    end
end

endmodule
