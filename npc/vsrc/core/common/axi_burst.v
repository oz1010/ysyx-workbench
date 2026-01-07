/*
 * 以下模块在axi4_master的基础上，增加burst模式的支持。
 * 并优化模块交互逻辑。
 */

module axi4_salve_burst_reader #(
    `ifndef IN_YOSYS_STA
    parameter NAME,
    `endif
    parameter BURST, // burst类型，0--FIXED 1--INCR 2--WRAP
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
) (
    input   wire                        clk,
    input   wire                        rst,
    /* 通信信号 */
    output  wire                        arready,
    input   wire                        arvalid,
    input   wire [ADDR_WIDTH-1:0]       araddr,
    input   wire [3:0]                  arid,
    input   wire [7:0]                  arlen,
    input   wire [2:0]                  arsize,
    input   wire [1:0]                  arburst,
    input   wire                        rready,
    output  wire                        rvalid,
    output  wire [RRESP_WIDTH-1:0]      rresp,
    output  wire [DATA_WIDTH-1:0]       rdata,
    output  wire                        rlast,
    output  wire [3:0]                  rid,
    /* 模块信号 */
    input   wire                        enable, // 模块使能信号
    input   wire                        read_data_en, // 数据使能信号
    input   wire [DATA_WIDTH-1:0]       read_data, /* 使用组合逻辑读取数据，否则一个周期的ar信号可能无法满足要求 */
    output  wire [ADDR_WIDTH-1:0]       read_addr,
    output  wire [7:0]                  read_len, // burst读取数量，2^n字节
    output  wire [2:0]                  read_size, // 单个burst读取数据大小，2^n字节
    output  wire [31:0]                 read_index, // 当前需要读取的数据偏移量：addr + index*(1<<size)
    output  wire [1:0]                  read_state
);
    reg [1:0]                               r_read_state;
    reg [31:0]                              r_read_index;
    reg [31:0]                              r_read_index_max;

    reg                                     r_arready;
    reg [RRESP_WIDTH-1:0]                   r_rresp;
    reg [3:0]                               r_rid;

    assign arready = r_arready;
    assign rvalid = read_data_en;
    assign rresp = r_rresp;
    assign rdata = read_data;
    assign rlast = r_read_index==r_read_index_max && rvalid && rready;
    assign rid = r_rid;

    /* 使用组合逻辑，外面才能在时序中正常处理 */
    assign read_addr = araddr;
    assign read_len = arlen;
    assign read_size = arsize;
    assign read_index = r_read_index;
    assign read_state = r_read_state;

    always @(posedge clk) begin
        if (rst || !enable) begin
            r_read_state <= `AXI4_STATE_ADDR;
            r_read_index <= 0;
            r_read_index_max <= 0;

            r_arready <= 0;
            r_rresp <= 0;
            r_rid <= 0;
        end else begin
            case (r_read_state)
                `AXI4_STATE_ADDR: begin
                    // read request
                    r_arready <= 1;
                    if (arvalid && arready) begin
                        r_read_state <= `AXI4_STATE_DATA;
                        r_read_index <= 0;
                        r_read_index_max <= (1<<arlen) - 1;
                        r_arready <= 0;
                        r_rid <= arid;
                    end

                end
            
                `AXI4_STATE_DATA: begin
                    if (rvalid && rready) begin
                        r_read_index <= r_read_index + 1;
                        if (rlast) begin
                            r_read_state <= `AXI4_STATE_ADDR;

                            r_arready <= 1;
                            r_rid <= 0;
                        end
                    end
                end
            endcase
        end
    end

endmodule

module axi4_salve_burst_writer #(
    `ifndef IN_YOSYS_STA
    parameter NAME,
    `endif
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
) (
    input   wire                        clk,
    input   wire                        rst,
    /* 通信信号 */
    output  wire                        awready,
    input   wire                        awvalid,
    input   wire [ADDR_WIDTH-1:0]       awaddr,
    input   wire [3:0]                  awid,
    input   wire [7:0]                  awlen,
    input   wire [2:0]                  awsize,
    input   wire [1:0]                  awburst,
    output  wire                        wready,
    input   wire                        wvalid,
    input   wire [DATA_WIDTH-1:0]       wdata,
    input   wire [DATA_WIDTH/8-1:0]     wstrb,
    input   wire                        wlast,
    input   wire                        bready,
    output  wire                        bvalid,
    output  wire [BRESP_WIDTH-1:0]      bresp,
    output  wire [3:0]                  bid,
    /* 模块信号 */
    input   wire                        enable,
    output  wire [ADDR_WIDTH-1:0]       write_addr,
    output  wire [DATA_WIDTH-1:0]       write_data,
    output  wire [DATA_WIDTH/8-1:0]     write_strb,
    output  wire [7:0]                  write_len, // burst写入数据总量，2^n
    output  wire [2:0]                  write_size, // 单个burst写入数据大小，2^n字节
    output  wire [31:0]                 write_index,
    output  wire                        write_valid
);

    reg                                     r_awready;
    reg                                     r_wready;
    reg                                     r_bvalid;
    reg [BRESP_WIDTH-1:0]                   r_bresp;
    reg [3:0]                               r_bid;
    reg [31:0]                              r_write_index;
    wire [31:0]                             write_index_max;

    assign awready = r_awready;
    assign wready = r_wready;
    assign bvalid = r_bvalid;
    assign bresp = r_bresp;
    assign bid = r_bid;

    assign write_addr = awaddr;
    assign write_strb = wstrb;
    assign write_data = wdata;
    assign write_len = awlen;
    assign write_size = awsize;
    assign write_index = r_write_index;
    assign write_valid = wvalid;

    wire in_write_mode = (awready || wready || bvalid);
    assign write_index_max = (1<<awlen) - 1;

    always @(posedge clk) begin
        if (rst || !enable) begin
            r_awready <= 0;
            r_wready <= 0;
            r_bvalid <= 0;
            r_bresp <= 0;
            r_bid <= 0;
            r_write_index <= 0;
        end else begin
            if (!in_write_mode) begin
                r_awready <= 1;
                r_wready <= 1;
            end

            // write request
            if (awvalid && awready) begin
                r_awready <= 0;
            end
            // if (awvalid) begin
            //     `ifndef IN_YOSYS_STA
            //     if (awsize!=2 || awlen!=0) $error("%s only support write 1 burst - 4bytes, addr:%x size:%x len:%x", NAME, awaddr, awsize, awlen);
            //     `endif
            // end

            // write data
            if (wvalid && wready) begin
                r_write_index <= r_write_index + 1;
            end

            // write response
            if (wvalid && wready && wlast) begin
                r_bvalid <= 1;
                r_bresp <= 0;
                r_bid <= awid;
            end
            if (bvalid && bready) begin
                r_bvalid <= 0;
                r_bid <= 0;
                r_awready <= 1;
                r_wready <= 1;
                r_write_index <= 0;
            end

        end
    end

endmodule
