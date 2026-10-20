module axi_master ();
endmodule

module axi_master_writer #(
    `ifndef IN_YOSYS_STA
    parameter NAME,
    `endif
    parameter ID,
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
    input   wire                        awready,
    output  wire                        awvalid,
    output  wire [ADDR_WIDTH-1:0]       awaddr,
    output  wire [3:0]                  awid,
    output  wire [7:0]                  awlen,
    output  wire [2:0]                  awsize,
    output  wire [1:0]                  awburst,
    input   wire                        wready,
    output  wire                        wvalid,
    output  wire [DATA_WIDTH-1:0]       wdata,
    output  wire [DATA_WIDTH/8-1:0]     wstrb,
    output  wire                        wlast,
    output  wire                        bready,
    input   wire                        bvalid,
    input   wire [BRESP_WIDTH-1:0]      bresp,
    input   wire [3:0]                  bid,
    /* 模块信号 */
    input   wire                        write_enable,
    input   wire [ADDR_WIDTH-1:0]       write_addr,
    input   wire [DATA_WIDTH-1:0]       write_data,
    input   wire [2:0]                  write_size, // 2^n字节
    output  wire [1:0]                  write_state
);

    reg [1:0] r_write_state;

    reg r_awvalid = 0;
    reg [ADDR_WIDTH-1:0] r_awaddr = 0;
    reg [3:0] r_awid; // 写入数据标识，响应中可以比对是否一致
    reg [7:0] r_awlen; // burst写入数量，2^n字节
    reg [2:0] r_awsize; // 单个burst写入数据大小，2^n字节
    reg [1:0] r_awburst; // 写burst方式，0--FIXED 1--INCR 2--WRAP（地址回绕递增） 11--保留
    reg [2:0] r_record_awsize;
    reg r_wvalid = 0;
    reg [DATA_WIDTH-1:0] r_wdata;
    reg [DATA_WIDTH/8-1:0] r_wstrb;
    reg r_wlast; // 写入最后一个数据时需要拉高
    reg r_bready;

    reg [7:0] s_write_idx;
    reg [7:0] s_write_len;
    reg [7:0] s_write_strb;
    wire [3:0] s_write_strbs[0:1];
    reg [1:0] s_write_shift_val;

    assign write_state = r_write_state;

    assign awvalid = r_awvalid;
    assign awaddr = r_awaddr;
    assign awid = r_awid;
    assign awlen = r_awlen;
    assign awsize = r_awsize;
    assign awburst = r_awburst;
    assign wvalid = r_wvalid;
    assign wdata = r_wdata;
    assign wstrb = r_wstrb;
    assign wlast = r_wlast;
    assign bready = r_bready;

    assign s_write_strbs[0] = s_write_strb[0 +: 4];
    assign s_write_strbs[1] = s_write_strb[4 +: 4];

    `define WRITE_DATA() \
        r_wvalid <= 1; \
        s_write_idx <= s_write_idx + 1; \
        r_wstrb <= s_write_strbs[s_write_idx[0:0]]; \
        case (s_write_idx) \
            0: r_wdata<=write_data<<(8*s_write_shift_val); \
            1: r_wdata<=write_data>>(32-8*s_write_shift_val); \
            `ifndef IN_YOSYS_STA \
            default: $error("%s aw data unalign is error", NAME); \
            `endif \
        endcase \
        if (s_write_idx == ((8'h1<<s_write_len)-1)) r_wlast <= 1;

    initial begin
        s_write_idx = 0;
        s_write_len = 0;
        s_write_strb = 0;
        s_write_shift_val = 0;
    end

    always @(*) begin
        s_write_len = 0;
        s_write_strb = 0;
        s_write_shift_val = 0;
        if (!rst && write_enable) begin
            get_unalign_addr_parameter(write_size, write_addr, s_write_len, s_write_strb, s_write_shift_val);
        end
    end

    always @(posedge clk) begin
        if (rst || !write_enable) begin
            r_write_state <= `AXI4_STATE_ADDR;

            r_awvalid <= 0;
            r_awaddr <= 0;
            r_awid <= 0;
            r_awlen <= 0;
            r_awsize <= 0;
            r_wvalid <= 0;
            r_wdata <= 0;
            r_wstrb <= 0;
            r_wlast <= 0;
            r_bready <= 0;
            s_write_idx <= 0;
            r_awburst <= 1; // 固定为地址环绕方式
        end else begin
            case (r_write_state)
                `AXI4_STATE_ADDR: begin
                    r_awvalid <= 1;
                    r_awaddr <= write_addr; // sram会4字节对齐
                    r_awid <= ID;
                    r_awlen <= s_write_len;
                    r_awsize <= write_size;
                    r_record_awsize <= write_size;
                    check_dev_addr(write_addr, `DEV_ATTR_WRITE);


                    r_write_state <= `AXI4_STATE_DATA;
                    /* 写下第一个字 */
                    `WRITE_DATA();
                end

                `AXI4_STATE_DATA: begin
                    if (awvalid && awready) begin
                        r_awvalid <= 0;
                    end

                    if (s_write_idx <= ((8'h1<<s_write_len)-1) && wvalid && wready) begin
                        /* 写下第二个字 */
                        `WRITE_DATA();
                    end

                    if (wvalid && wready && wlast) begin
                        func_dev_skip(1, write_addr, {25'h0, r_record_awsize, s_write_strbs[0]|s_write_strbs[1]}, write_data);

                        r_wvalid <= 0;
                        r_wstrb <= 0;
                        r_wdata <= 0;
                        r_wlast <= 0;
                        s_write_idx <= 0;

                        // switch to write response
                        r_write_state <= `AXI4_STATE_RESPONSE;
                        r_bready <= 1;
                    end
                end

                `AXI4_STATE_RESPONSE: begin
                    if (bvalid && bready) begin
                        // switch to init
                        r_write_state <= `AXI4_STATE_ADDR;
                        r_bready <= 0;

                        // clear write request
                        r_awaddr <= 0;
                        r_awid <= 0;
                        r_awlen <= 0;
                        r_awsize <= 0;

                        `ifndef IN_YOSYS_STA
                        // check error response
                        if (bresp!=0 || bid!=ID) begin
                            $error("%s Write data error, addr:%x data:%x resp:%x id:%x\n", NAME, write_addr, write_data, bresp, bid);
                        end
                        `endif
                    end
                end

                `ifndef IN_YOSYS_STA
                default: $error("%s found unknown write write_state(%d)", NAME, r_write_state);
                `endif
            endcase
        end
    end

endmodule

module axi4_salve_writer #(
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
    output  wire [2:0]                  write_size,
    output  wire                        write_valid
);

    reg                                     r_awready;
    reg                                     r_wready;
    reg                                     r_bvalid;
    reg [BRESP_WIDTH-1:0]                   r_bresp;
    reg [3:0]                               r_bid;

    reg [ADDR_WIDTH-1:0]                    r_write_addr;
    reg [3:0]                               r_write_id;
    reg [7:0]                               r_write_len; // 单个burst写入数据大小，2^n字节
    reg [2:0]                               r_write_size; // burst写入数量，2^n字节

    assign awready = r_awready;
    assign wready = r_wready;
    assign bvalid = r_bvalid;
    assign bresp = r_bresp;
    assign bid = r_bid;

    assign write_addr = r_write_addr;
    assign write_data = wdata;
    assign write_size = r_write_size;
    assign write_valid = wvalid;

    wire in_write_mode = (awready || wready || bvalid);

    always @(posedge clk) begin
        if (rst || !enable) begin
            r_awready <= 0;
            r_wready <= 0;
            r_bvalid <= 0;
            r_bresp <= 0;
            r_bid <= 0;

            r_write_addr <= 0;
            r_write_size <= 0;
            r_write_len <= 0;
            r_write_id <= 0;
        end else begin
            // write request
            if (!in_write_mode) r_awready <= 1;
            if (awvalid) begin
                r_write_addr <= awaddr;
                r_write_size <= awsize;
                r_write_len <= awlen;
                r_write_id <= awid;
                
                `ifndef IN_YOSYS_STA
                if (awsize!=2 || awlen!=0) $error("%s only support write 1 burst - 4bytes, addr:%x size:%x len:%x", NAME, awaddr, awsize, awlen);
                `endif
            end
            if (awvalid && awready) begin
                r_awready <= 0;
            end

            // write data
            if (awvalid && awready) begin
                r_wready <= 1;
            end
            if (wvalid && wready) begin
                r_wready <= 0;
            end
            if (wvalid && wready) begin
                `ifndef IN_YOSYS_STA
                if (!wlast) $error("%s only support write 1-burst, addr:%x size:%x", NAME, awaddr, write_size);
                `endif
            end

            // write response
            if (wvalid && wready && wlast) begin
                r_bvalid <= 1;
                r_bresp <= 0;
                r_bid <= r_write_id;
            end
            if (bvalid && bready) begin
                r_bvalid <= 0;
                r_bid <= 0;
            end

        end
    end

endmodule

module axi_master_reader #(
    `ifndef IN_YOSYS_STA
    parameter NAME,
    `endif
    parameter BURST, // burst类型，0--FIXED 1--INCR 2--WRAP
    parameter ID,
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
) (
    input   wire                        clk,
    input   wire                        rst,
    /* 通信信号 */
    input   wire                        arready,
    output  wire                        arvalid,
    output  wire [ADDR_WIDTH-1:0]       araddr,
    output  wire [3:0]                  arid,
    output  wire [7:0]                  arlen,
    output  wire [2:0]                  arsize,
    output  wire [1:0]                  arburst,
    output  wire                        rready,
    input   wire                        rvalid,
    input   wire [RRESP_WIDTH-1:0]      rresp,
    input   wire [DATA_WIDTH-1:0]       rdata,
    input   wire                        rlast,
    input   wire [3:0]                  rid,
    /* 模块信号 */
    input   wire                        enable,
    input   wire                        read_sign,
    input   wire [ADDR_WIDTH-1:0]       read_addr,
    output  wire [DATA_WIDTH-1:0]       read_data,
    input   wire [7:0]                  read_len, // 读取数据总burst数量，2^n
    input   wire [2:0]                  read_size,
    output  wire [1:0]                  read_state
);

    reg r_arvalid = 0;
    reg [ADDR_WIDTH-1:0] r_araddr = 0;
    reg [3:0] r_arid;
    reg [7:0] r_arlen;
    reg [7:0] r_record_arlen;
    reg [2:0] r_arsize;
    reg [2:0] r_record_arsize;
    reg [1:0] r_arburst;
    reg r_rready;

    reg [7:0] s_read_idx;
    reg [7:0] s_read_len;
    reg [7:0] s_read_strb;
    wire [3:0] s_read_strbs[0:1];
    reg [1:0] s_read_shift_val;
    reg [1:0] r_read_state;
    reg [DATA_WIDTH-1:0] s_read_data;

    assign read_state = r_read_state;
    assign read_data = s_read_data;

    assign arvalid = r_arvalid;
    assign araddr = r_araddr;
    assign arid = r_arid;
    assign arlen = r_arlen;
    assign arsize = r_arsize;
    assign arburst = r_arburst;
    assign rready = r_rready;

    assign s_read_strbs[0] = s_read_strb[0 +: 4];
    assign s_read_strbs[1] = s_read_strb[4 +: 4];

    initial begin
        s_read_idx = 0;
        s_read_len = 0;
    end

    `ifdef IN_YOSYS_STA
    always @(posedge clk) begin
        s_read_data <= s_multi_read_data[s_read_shift_val*8 +: DATA_WIDTH];
    end
    `else
    always @(*) begin
        s_read_data = 0;
        if (r_read_state == `AXI4_STATE_DATA) begin
            /* 依次读取非对齐数据，用组合逻辑实现； */
            get_unalign_addr_data(read_sign, read_size, s_multi_read_data, s_read_shift_val, s_read_data);
        end
    end
    `endif

    // 未对齐多包需要单独拼接
    wire s_multi_unaligned_read = s_read_shift_val!=0 && arlen==8'h1;
    reg [DATA_WIDTH-1:0] s_multi_read_data_low;
    wire [2*DATA_WIDTH-1:0] s_multi_read_data = {rdata, s_multi_unaligned_read ? s_multi_read_data_low : rdata};
    always @(posedge clk) begin
        if (rst || !enable) begin
            s_multi_read_data_low <= 0;
        end else begin
            if (rvalid && s_read_idx==0) s_multi_read_data_low <= rdata;
        end
    end

    always @(*) begin
        s_read_len = 0;
        s_read_strb = 0;
        s_read_shift_val = 0;
        if (!rst && enable) begin
            get_unalign_addr_parameter(read_size, read_addr, s_read_len, s_read_strb, s_read_shift_val);
        end
    end

    always @(posedge clk) begin
        if (rst || !enable) begin
            r_read_state <= `AXI4_STATE_ADDR;

            r_arvalid <= 0;
            r_araddr <= 0;
            r_arid <= 0;
            r_arlen <= 0;
            r_arsize <= 0;
            r_arburst <= 0;
            r_rready <= 0;
        end else begin
            case (r_read_state)
                `AXI4_STATE_ADDR: begin
                    // read request
                    r_arvalid <= 1;
                    r_araddr <= read_addr; // sram会4字节对齐
                    r_arid <= ID;
                    if (read_len > 0)
                        r_arlen <= read_len; // 读取数据总burst数量，2^n
                    else
                        r_arlen <= s_read_len; // 读取数据总burst数量，2^n
                    r_arsize <= read_size;
                    r_arburst <= BURST;
                    check_dev_addr(read_addr, `DEV_ATTR_READ);
                    s_read_idx <= 0;

                    if (arvalid && arready) begin
                        r_arvalid <= 0;
                        r_record_arlen <= r_arlen;
                        r_record_arsize <= r_arsize;

                        // switch to read data
                        r_read_state <= `AXI4_STATE_DATA;
                        r_rready <= 1;
                        s_read_idx <= 0;
                    end
                end 

                `AXI4_STATE_DATA: begin
                    // read data
                    if (!rready) begin
                        r_rready <= 1;
                    end
                    if (rvalid) begin
                        // 读取非对齐地址时，read_len必然是0；而burst模式下，不支持非对齐方式；
                        if (read_len == 0) begin
                            s_read_idx <= s_read_idx + 1;
                        end
                    end
                    if (rvalid && rready) begin
                        r_rready <= 0;
                    end
                    if (rlast) begin
                        s_read_idx <= 0;
                        func_dev_skip(0, read_addr, {21'h0, r_record_arsize, r_record_arlen}, read_data);
                        // check error response
                        `ifndef IN_YOSYS_STA
                        if (rresp!=0 || rlast!=1 || rid!=ID) begin
                            $error("%s read data error, addr:%x resp:%x last:%x id:%x\n", NAME, read_addr, rresp, rlast, rid);
                        end
                        `endif

                        // clear read request
                        r_araddr <= 0;
                        r_arid <= 0;
                        r_arlen <= 0;
                        r_arsize <= 0;
                        r_arburst <= 0;

                        // switch to read addr
                        r_read_state <= `AXI4_STATE_ADDR;
                    end
                end

                `ifndef IN_YOSYS_STA
                default: $error("%s found unknown read state(%d)", NAME, r_read_state);
                `endif
            endcase
        end
    end
endmodule

module axi4_salve_reader #(
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
    input   wire                        data_en, // 数据使能信号
    output  wire [ADDR_WIDTH-1:0]       read_addr,
    input   wire [DATA_WIDTH-1:0]       read_data, /* 使用组合逻辑读取数据，否则一个周期的ar信号可能无法满足要求 */
    output  wire [7:0]                  read_len, // burst读取数量，2^n字节
    output  wire [2:0]                  read_size, // 单个burst读取数据大小，2^n字节
    output  wire [1:0]                  read_state
);
    reg [1:0]                               r_read_state;

    reg                                     r_arready;
    reg                                     r_rvalid;
    reg [RRESP_WIDTH-1:0]                   r_rresp;
    reg [DATA_WIDTH-1:0]                    r_rdata;
    reg                                     r_rlast;
    reg [3:0]                               r_rid;

    reg [7:0]                               r_read_len;
    reg [2:0]                               r_read_size;

    assign arready = r_arready;
    assign rvalid = r_rvalid;
    assign rresp = r_rresp;
    assign rdata = r_rdata;
    assign rlast = r_rlast;
    assign rid = r_rid;

    /* 使用组合逻辑，外面才能在时序中正常处理 */
    assign read_addr = araddr;
    assign read_len = arlen;
    assign read_size = arsize;
    assign read_state = r_read_state;

    always @(posedge clk) begin
        if (rst || !enable) begin
            r_read_state <= `AXI4_STATE_ADDR;

            r_arready <= 1;
            r_rvalid <= 0;
            r_rresp <= 0;
            r_rdata <= 0;
            r_rlast <= 0;
            r_rid <= 0;
        end else begin
            case (r_read_state)
                `AXI4_STATE_ADDR: begin
                    // read request
                    r_arready <= 0;
                    if (arvalid) begin
                        r_read_state <= `AXI4_STATE_DATA;

                        if (data_en) begin
                            // read data，配合组合逻辑快速读取数据
                            r_rdata <= read_data;
                            r_rvalid <= 1;
                            r_rresp <= 0;
                            r_rlast <= 1;
                            r_rid <= arid;
                        end
                    end

                end
            
                `AXI4_STATE_DATA: begin
                    if (data_en) begin
                        // read data，配合组合逻辑快速读取数据
                        r_rdata <= read_data;
                        r_rvalid <= 1;
                        r_rresp <= 0;
                        r_rlast <= 1;
                        r_rid <= arid;
                    end

                    if (rvalid && rready && rlast) begin
                        r_read_state <= `AXI4_STATE_ADDR;

                        r_arready <= 1;
                        r_rvalid <= 0;
                        r_rresp <= 0;
                        r_rlast <= 0;
                        r_rid <= 0;
                    end 
                end
            endcase
        end
    end

endmodule
