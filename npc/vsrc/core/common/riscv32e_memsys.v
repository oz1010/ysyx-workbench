module riscv32e_memsys #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                         clock,
    input  wire                         reset,

    // 复位
    output reg  [ADDR_WIDTH-1:0]        reset_pc,

    // 取指接口
    input wire                          io_if_req_valid,
    output reg                          io_if_req_ready,
    input wire  [ADDR_WIDTH-1:0]        io_if_req_addr,
    input wire  [`MEMOP_W-1:0]          io_if_req_op,
    input wire  [DATA_WIDTH-1:0]        io_if_req_wdata,
    output reg                          io_if_rsp_valid,
    input wire                          io_if_rsp_ready,
    output reg [DATA_WIDTH-1:0]         io_if_rsp_data,
    // 访问存储接口
    input wire                          io_mem_req_valid,
    output reg                          io_mem_req_ready,
    input wire  [ADDR_WIDTH-1:0]        io_mem_req_addr,
    input wire  [`MEMOP_W-1:0]          io_mem_req_op,
    input wire  [DATA_WIDTH-1:0]        io_mem_req_wdata,
    output reg                          io_mem_rsp_valid,
    input wire                          io_mem_rsp_ready,
    output reg  [DATA_WIDTH-1:0]        io_mem_rsp_data,
    // gpr写入
    input  wire                         gpr_wen,
    input  wire [`RISCV_GPR_ADDR_W-1:0] gpr_waddr,
    input  wire [DATA_WIDTH-1:0]        gpr_wdata,
    // 普通csr写入
    input  wire                         csr_wen,
    input  wire [`CSR_ADDR_W-1:0]       csr_waddr,
    input  wire [DATA_WIDTH-1:0]        csr_wdata,
    // 异常csr写入
    input  wire                         trap_en,
    input  wire [INST_WIDTH-1:0]        trap_epc,
    input  wire [DATA_WIDTH-1:0]        trap_cause,
    input  wire [DATA_WIDTH-1:0]        trap_tval,
    input  wire [DATA_WIDTH-1:0]        trap_status,

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

    wire core_ready = !reset;

    // 复位逻辑
    generate
        if (`RISCV_RESET_PC_EN) begin // 直接使用静态值
            assign reset_pc = `RISCV_RESET_PC;
        end else begin // 从镜像读取值
            // TODO 这里从函数里面读取值需要经历多个周期才有效存在问题
            always @(posedge clock) begin
                if (reset) begin
                    reset_pc <= func_get_reset_pc();
                end
            end
        end
    endgenerate

    // 硬件性能监控
    hw_monitor #(
        .INST_WIDTH(INST_WIDTH)
    ) m_hw_monitor (
        .clock(clock),
        .reset(reset),
        .hw_monitor_icache_en(0),
        .hw_monitor_icache_hit(0),
        .hw_monitor_dcache_en(0),
        .hw_monitor_dcache_hit(0),
        .hw_monitor_ls_en(0),
        .hw_monitor_ls_iswrite(0),
        .hw_monitor_ls_data(0),
        .done()
    );    

    `ifdef CONFIG_ISA_RISCV_SINGLE // 单周期特有逻辑
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

    // 组合取指
    always @(*) begin
        if (reset) begin
            io_if_req_ready = 0;
            io_if_rsp_valid = 0;
            io_if_rsp_data = 0;
        end else begin
            io_if_req_ready = 1;
            io_if_rsp_valid = 0;
            io_if_rsp_data = 0;
            if (io_if_req_valid && io_if_req_ready) begin
                io_if_rsp_valid = 1;
                io_if_rsp_data = func_vdev_read(io_if_req_addr, 4);
            end
        end
    end

    // 访存
    assign io_mem_req_ready = 1;
    assign io_mem_rsp_valid = 
        io_mem_req_op==`MEMOP_LB || 
        io_mem_req_op==`MEMOP_LH || 
        io_mem_req_op==`MEMOP_LW || 
        io_mem_req_op==`MEMOP_LBU || 
        io_mem_req_op==`MEMOP_LHU || 
        0;
    always @(*) begin
        if (reset) begin
            io_mem_rsp_data = 0;
        end else begin
            io_mem_rsp_data = 0;
            if (io_mem_req_valid && io_mem_req_ready) begin
                case (io_mem_req_op)
                    `MEMOP_LB:          begin io_mem_rsp_data = sext(read_raw_mem(io_mem_req_addr, 1), 8); end
                    `MEMOP_LH:          begin io_mem_rsp_data = sext(read_raw_mem(io_mem_req_addr, 2), 16); end
                    `MEMOP_LW:          begin io_mem_rsp_data = sext(read_raw_mem(io_mem_req_addr, 4), 32); end
                    `MEMOP_LBU:         begin io_mem_rsp_data = read_raw_mem(io_mem_req_addr, 1) & 32'hFF; end
                    `MEMOP_LHU:         begin io_mem_rsp_data = read_raw_mem(io_mem_req_addr, 2) & 32'hFFFF; end
                    default: ;
                endcase
            end
        end
    end
    always @(posedge clock) begin
        if (reset) begin
        end else begin
            if (io_mem_req_valid && io_mem_req_ready) begin
                case (io_mem_req_op)
                    `MEMOP_SB:          begin write_raw_mem(io_mem_req_addr, 1, io_mem_req_wdata); func_dev_skip(1, io_mem_req_addr, {24'h0, 4'h0, 4'h1}, io_mem_req_wdata); end
                    `MEMOP_SH:          begin write_raw_mem(io_mem_req_addr, 2, io_mem_req_wdata); func_dev_skip(1, io_mem_req_addr, {24'h0, 4'h1, 4'h3}, io_mem_req_wdata); end
                    `MEMOP_SW:          begin write_raw_mem(io_mem_req_addr, 4, io_mem_req_wdata); func_dev_skip(1, io_mem_req_addr, {24'h0, 4'h2, 4'h7}, io_mem_req_wdata); end
                    `MEMOP_LB:          begin func_dev_skip(0, io_mem_req_addr, {24'h0, 4'h0, 4'h0}, io_mem_rsp_data); end
                    `MEMOP_LH:          begin func_dev_skip(0, io_mem_req_addr, {24'h0, 4'h1, 4'h0}, io_mem_rsp_data); end
                    `MEMOP_LW:          begin func_dev_skip(0, io_mem_req_addr, {24'h0, 4'h2, 4'h0}, io_mem_rsp_data); end
                    `MEMOP_LBU:         begin func_dev_skip(0, io_mem_req_addr, {24'h0, 4'h0, 4'h0}, io_mem_rsp_data); end
                    `MEMOP_LHU:         begin func_dev_skip(0, io_mem_req_addr, {24'h0, 4'h1, 4'h0}, io_mem_rsp_data); end
                    default: ;
                endcase
            end
        end
    end

    `elsif CONFIG_ISA_RISCV_PIPELINE_CHISEL // chisel版本
    `ifndef IN_YOSYS_STA
    // Chisel CSR 文件不调用 DPI，在相同提交沿镜像公开写口和陷阱事件。
    always @(posedge clock) begin
        if (reset) begin
            func_write_raw_csr({20'h0, `CSR_MSTATUS}, 32'h1800);
            func_write_raw_csr({20'h0, `CSR_MTVEC}, 0);
            func_write_raw_csr({20'h0, `CSR_MEPC}, 0);
            func_write_raw_csr({20'h0, `CSR_MCAUSE}, 0);
            func_write_raw_csr({20'h0, `CSR_MTVAL}, 0);
            func_write_raw_csr({20'h0, `CSR_MVENDORID}, 0);
            func_write_raw_csr({20'h0, `CSR_MARCHID}, 0);
        end else begin
            if (csr_wen) begin
                func_write_raw_csr({20'h0, csr_waddr}, csr_wdata);
            end
            if (trap_en) begin
                func_write_raw_csr({20'h0, `CSR_MSTATUS}, trap_status);
                func_write_raw_csr({20'h0, `CSR_MEPC}, {trap_epc[31:2], 2'b0});
                func_write_raw_csr({20'h0, `CSR_MCAUSE}, trap_cause);
                func_write_raw_csr({20'h0, `CSR_MTVAL}, trap_tval);
            end
        end
    end
    `endif
    CacheRouter cache_router(
        .clock(clock),
        .reset(reset),
        .io_if_req_valid(io_if_req_valid),
        .io_if_req_ready(io_if_req_ready),
        .io_if_req_addr(io_if_req_addr),
        .io_if_req_op(io_if_req_op),
        .io_if_req_wdata(io_if_req_wdata),
        .io_if_rsp_valid(io_if_rsp_valid),
        .io_if_rsp_ready(io_if_rsp_ready),
        .io_if_rsp_data(io_if_rsp_data),
        .io_mem_req_valid(io_mem_req_valid),
        .io_mem_req_ready(io_mem_req_ready),
        .io_mem_req_addr(io_mem_req_addr),
        .io_mem_req_op(io_mem_req_op),
        .io_mem_req_wdata(io_mem_req_wdata),
        .io_mem_rsp_valid(io_mem_rsp_valid),
        .io_mem_rsp_ready(io_mem_rsp_ready),
        .io_mem_rsp_data(io_mem_rsp_data),
        .io_master_arvalid(io_master_arvalid),
        .io_master_arready(io_master_arready),
        .io_master_araddr(io_master_araddr),
        .io_master_arid(io_master_arid),
        .io_master_arlen(io_master_arlen),
        .io_master_arsize(io_master_arsize),
        .io_master_arburst(io_master_arburst),
        .io_master_rvalid(io_master_rvalid),
        .io_master_rready(io_master_rready),
        .io_master_rdata(io_master_rdata),
        .io_master_rresp(io_master_rresp),
        .io_master_rlast(io_master_rlast),
        .io_master_rid(io_master_rid),
        .io_master_awvalid(io_master_awvalid),
        .io_master_awready(io_master_awready),
        .io_master_awaddr(io_master_awaddr),
        .io_master_awid(io_master_awid),
        .io_master_awlen(io_master_awlen),
        .io_master_awsize(io_master_awsize),
        .io_master_awburst(io_master_awburst),
        .io_master_wvalid(io_master_wvalid),
        .io_master_wready(io_master_wready),
        .io_master_wdata(io_master_wdata),
        .io_master_wstrb(io_master_wstrb),
        .io_master_wlast(io_master_wlast),
        .io_master_bvalid(io_master_bvalid),
        .io_master_bready(io_master_bready),
        .io_master_bresp(io_master_bresp),
        .io_master_bid(io_master_bid)
    );

    `else
    // TODO 非单周期取指，需要转换为axi4信号
    assign io_if_req_ready = 0;
    assign io_if_rsp_valid = 0;
    assign io_if_rsp_data = 0;

    // TODO 非单周期访存取指，需要转换为axi4信号
    assign io_mem_req_ready = 0;
    assign io_mem_rsp_valid = 0;
    assign io_mem_rsp_data = 0;

    `endif

    // 避免启动diff时，没有跳过外设
    `ifndef IN_YOSYS_STA
    `ifndef FORMAL_VERIFY
    always @(posedge clock) begin
        if (!reset && io_master_arvalid && io_master_arready)
            func_dev_skip(0, io_master_araddr, {21'h0, io_master_arsize, io_master_arlen}, 0);
        if (!reset && io_master_awvalid && io_master_awready)
            func_dev_skip(1, io_master_awaddr, {25'h0, io_master_awsize, io_master_wstrb}, 0);
    end
    `endif
    `endif

    // generate
    //     // if (`CONFIG_ISA_RISCV_SINGLE) begin // 单周期特有逻辑
    //     if (0) begin // 单周期特有逻辑
    //     // 组合取指
    //     always @(*) begin
    //         if (reset) begin
    //             io_if_req_ready = 0;
    //             io_if_rsp_valid = 0;
    //             io_if_rsp_data = 0;
    //         end else begin
    //             io_if_req_ready = 1;
    //             io_if_rsp_valid = 0;
    //             io_if_rsp_data = 0;
    //             if (io_if_req_valid && io_if_req_ready) begin
    //                 io_if_rsp_valid = 1;
    //                 io_if_rsp_data = func_vdev_read(io_if_req_addr, 4);
    //             end
    //         end
    //     end

    //     // 访存
    //     assign io_mem_req_ready = 1;
    //     assign io_mem_rsp_valid = 
    //         io_mem_req_op==`MEMOP_LB || 
    //         io_mem_req_op==`MEMOP_LH || 
    //         io_mem_req_op==`MEMOP_LW || 
    //         io_mem_req_op==`MEMOP_LBU || 
    //         io_mem_req_op==`MEMOP_LHU || 
    //         0;
    //     always @(negedge clock) begin
    //         if (reset) begin
    //         end else begin
    //             io_mem_rsp_data <= 0;
    //             if (io_mem_req_valid && io_mem_req_ready) begin
    //                 case (io_mem_req_op)
    //                     `MEMOP_LB:          begin io_mem_rsp_data <= sext(read_raw_mem(io_mem_req_addr, 1), 8); end
    //                     `MEMOP_LH:          begin io_mem_rsp_data <= sext(read_raw_mem(io_mem_req_addr, 2), 16); end
    //                     `MEMOP_LW:          begin io_mem_rsp_data <= sext(read_raw_mem(io_mem_req_addr, 4), 32); end
    //                     `MEMOP_LBU:         begin io_mem_rsp_data <= read_raw_mem(io_mem_req_addr, 1) & 32'hFF; end
    //                     `MEMOP_LHU:         begin io_mem_rsp_data <= read_raw_mem(io_mem_req_addr, 2) & 32'hFFFF; end
    //                     default: ;
    //                 endcase
    //             end
    //         end
    //     end
    //     always @(posedge clock) begin
    //         if (reset) begin
    //         end else begin
    //             if (io_mem_req_valid && io_mem_req_ready) begin
    //                 case (io_mem_req_op)
    //                     `MEMOP_SB:          begin write_raw_mem(io_mem_req_addr, 1, io_mem_req_wdata); func_dev_skip(1, io_mem_req_addr, {24'h0, 4'h0, 4'h1}, io_mem_req_wdata); end
    //                     `MEMOP_SH:          begin write_raw_mem(io_mem_req_addr, 2, io_mem_req_wdata); func_dev_skip(1, io_mem_req_addr, {24'h0, 4'h1, 4'h3}, io_mem_req_wdata); end
    //                     `MEMOP_SW:          begin write_raw_mem(io_mem_req_addr, 4, io_mem_req_wdata); func_dev_skip(1, io_mem_req_addr, {24'h0, 4'h2, 4'h7}, io_mem_req_wdata); end
    //                     `MEMOP_LB:          begin func_dev_skip(0, io_mem_req_addr, {24'h0, 4'h0, 4'h0}, io_mem_rsp_data); end
    //                     `MEMOP_LH:          begin func_dev_skip(0, io_mem_req_addr, {24'h0, 4'h1, 4'h0}, io_mem_rsp_data); end
    //                     `MEMOP_LW:          begin func_dev_skip(0, io_mem_req_addr, {24'h0, 4'h2, 4'h0}, io_mem_rsp_data); end
    //                     `MEMOP_LBU:         begin func_dev_skip(0, io_mem_req_addr, {24'h0, 4'h0, 4'h0}, io_mem_rsp_data); end
    //                     `MEMOP_LHU:         begin func_dev_skip(0, io_mem_req_addr, {24'h0, 4'h1, 4'h0}, io_mem_rsp_data); end
    //                     default: ;
    //                 endcase
    //             end
    //         end
    //     end

    //     end else begin
    //     // TODO 非单周期取指，需要转换为axi4信号
    //     assign io_if_req_ready = 0;
    //     assign io_if_rsp_valid = 0;
    //     assign io_if_rsp_data = 0;

    //     // TODO 非单周期访存取指，需要转换为axi4信号
    //     assign io_mem_req_ready = 0;
    //     assign io_mem_rsp_valid = 0;
    //     assign io_mem_rsp_data = 0;
    //     end
    // endgenerate
endmodule
