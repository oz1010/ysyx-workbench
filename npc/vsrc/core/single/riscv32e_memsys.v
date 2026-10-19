module riscv32e_memsys #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                         clk,
    input  wire                         rst,

    // 复位
    output reg  [ADDR_WIDTH-1:0]        reset_pc,

    // 取指接口
    input wire                          if_req_valid,
    output reg                          if_req_ready,
    input wire  [ADDR_WIDTH-1:0]        if_req_addr,
    input wire  [DATA_WIDTH-1:0]        if_req_wdata,
    input wire  [DATA_WIDTH/8-1:0]      if_req_wstrb,
    input wire                          if_req_iswrite,
    output reg                          if_rsp_valid,
    input wire                          if_rsp_ready,
    output reg [DATA_WIDTH-1:0]         if_rsp_data,
    
    // 访问存储接口
    input wire                          mem_req_valid,
    output reg                          mem_req_ready,
    input wire  [ADDR_WIDTH-1:0]        mem_req_addr,
    input wire  [DATA_WIDTH-1:0]        mem_req_wdata,
    input wire  [DATA_WIDTH/8-1:0]      mem_req_wstrb,
    input wire                          mem_req_iswrite,
    output reg                          mem_rsp_valid,
    input wire                          mem_rsp_ready,
    input wire  [DATA_WIDTH-1:0]        mem_rsp_data,

    /* AXI4 Master总线 */
    input  wire                         io_master_awready,
    output wire                         io_master_awvalid,
    output wire [31:0]                  io_master_awaddr,
    output wire [3:0]                   io_master_awid,
    output wire [7:0]                   io_master_awlen,
    output wire [2:0]                   io_master_awsize,
    output wire [1:0]                   io_master_awburst,
    input  wire                         io_master_wready,
    output wire                         io_master_wvalid,
    output wire [31:0]                  io_master_wdata,
    output wire [3:0]                   io_master_wstrb,
    output wire                         io_master_wlast,
    output wire                         io_master_bready,
    input  wire                         io_master_bvalid,
    input  wire [1:0]                   io_master_bresp,
    input  wire [3:0]                   io_master_bid,
    input  wire                         io_master_arready,
    output wire                         io_master_arvalid,
    output wire [31:0]                  io_master_araddr,
    output wire [3:0]                   io_master_arid,
    output wire [7:0]                   io_master_arlen,
    output wire [2:0]                   io_master_arsize,
    output wire [1:0]                   io_master_arburst,
    output wire                         io_master_rready,
    input  wire                         io_master_rvalid,
    input  wire [1:0]                   io_master_rresp,
    input  wire [31:0]                  io_master_rdata,
    input  wire                         io_master_rlast,
    input  wire [3:0]                   io_master_rid,

    output wire                         done
);

    wire core_ready = !rst;

    // 单周期不需要通过axi4总线访问外部设备
    assign io_master_awvalid = 0;
    assign io_master_awaddr = 0;
    assign io_master_awid = 0;
    assign io_master_awlen = 0;
    assign io_master_awsize = 4;
    assign io_master_awburst = 0;
    assign io_master_wvalid = 0;
    assign io_master_wdata = 0;
    assign io_master_wstrb = 0;
    assign io_master_wlast = 0;
    assign io_master_bready = 0;
    assign io_master_arvalid = 0;
    assign io_master_araddr = 0;
    assign io_master_arid = 0;
    assign io_master_arlen = 0;
    assign io_master_arsize = 0;
    assign io_master_arburst = 0;
    assign io_master_rready = 0;

    // 复位逻辑
    generate
        if (`RISCV_RESET_PC_EN) begin // 直接使用静态值
            assign reset_pc = `RISCV_RESET_PC;
        end else begin // 从镜像读取值
            always @(posedge clk) begin
                if (rst) begin
                    reset_pc <= func_get_reset_pc();
                end
            end
        end
    endgenerate

    // 硬件性能监控
    hw_monitor #(
        .INST_WIDTH(INST_WIDTH)
    ) m_hw_monitor (
        .clk(clk),
        .rst(rst),
        .hw_monitor_icache_en(0),
        .hw_monitor_icache_hit(0),
        .hw_monitor_dcache_en(0),
        .hw_monitor_dcache_hit(0),
        .hw_monitor_ls_en(0),
        .hw_monitor_ls_iswrite(0),
        .hw_monitor_ls_data(0),
        .done()
    );

    // TODO 暂时屏蔽信号
    assign mem_req_ready = 0;
    assign mem_rsp_valid = 0;

    generate
        if (`CONFIG_ISA_RISCV_SINGLE) begin
        // 单周期组合取指
        always @(*) begin
            if (rst) begin
                if_req_ready = 0;
                if_rsp_valid = 0;
                if_rsp_data = 0;
            end else begin
                if_req_ready = 1;
                if_rsp_valid = 0;
                if_rsp_data = 0;
                if (if_req_valid && if_req_ready) begin
                    if_rsp_valid = 1;
                    if_rsp_data = func_vdev_read(if_req_addr, 4);
                end
            end
        end

        end else begin
        // TODO 非单周期取指，需要转换为axi4信号
        assign if_req_ready = 0;
        assign if_rsp_valid = 0;
        assign if_rsp_data = 0;

        end
    endgenerate
endmodule
