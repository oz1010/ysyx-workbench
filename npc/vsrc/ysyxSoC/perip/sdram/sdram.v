module sdram(
  input        clk,
  input        cke,
  input        cs,
  input        ras,
  input        cas,
  input        we,
  input [12:0] a,
  input [ 1:0] ba,
  input [ 1:0] dqm,
  input        bsel,
  inout [15:0] dq
);

    parameter BASE_ADDR_OFFSET = 32'h0;

    // ref. https://www.mouser.com/datasheet/2/12/alliance_MT48LC-1155509.pdf

    assign dq = (state==read_t && counter==(cas_latency-1+2*read_index-2)) ? rdata[15:0] :
                (state==read_t && (counter==cas_latency+2*read_index-2)) ? rdata[31:16] :
                16'bz;

    wire [3:0] input_cmd = {cs, ras, cas, we};

    typedef enum [2:0] { idle_t, active_t, read_t, write_t, err_t } state_t;
    reg [2:0] state;
    reg [7:0] counter;
    reg [7:0] read_index; // 记录需要读取数据当前索引值
    reg [7:0] read_index_max; // 记录需要读取数据最大值
    reg [31:0] addr;
    reg [31:0] rdata;
    reg [12:0] active_rows[0:3]; /* 存储当前激活的bank对应的row，减少active命令发送 */
    wire [6:0] addr_fixed = 7'h50; // a000_0000固定地址
    /**
     * ref. Functional Description
     * ref. Figure 3: 16 Meg x 16 Functional Block Diagram
     *   每个bank范围：(8192 x 512 x 16)
     * 地址结构：[row-13bits][bank-2bits][column-9bits][rdata-16bits]
     * 需要注意数据总线为16bit，及2字节数据，所以地址最低位一直为0
     */
    wire [31:0] ram_addr = {
        7'h50,              // [31:25]  a000_0000固定地址
        active_rows[ba],    // [24:12]  select the row
        ba,                 // [11:10]  select the bank
        a[8:0],             // [9:1]    select the column
        1'h0                // [0:0]    固定的地址
    } + BASE_ADDR_OFFSET;

    reg [31:0] wdata;
    reg [3:0] wmask;
    reg [1:0] woffset;
    reg [2:0] wsize;

    // reg. https://www.mouser.com/datasheet/2/12/alliance_MT48LC-1155509.pdf
    //   Mode Register Definition
    reg [12:0] mx;
    wire [2:0] mx_burst_length = mx[2:0]; // 2^n，有效值：0~3 (1~8)
    wire [2:0] mx_cas_latency = mx[6:4]; // 设定dq执行READ命令几个周期后数据有效，有效取值：1~3，其他保留
    wire [7:0] burst_length = 8'h1<<mx_burst_length;
    wire [7:0] cas_latency = {5'h0, mx_cas_latency};

    wire [7:0] read_done_count = (cas_latency + 2 * (read_index_max - 1));
    wire read_done = (state==read_t) && (counter == read_done_count);
    wire [31:0] roffset = {30'h0, dqm};

    initial begin
        state = idle_t;
        counter = 0;
        addr = 0;
        rdata = 0;
        wmask = 0;
    end

    always @(posedge clk) begin
        if (bsel) begin
            casez (input_cmd)
                // COMMAND INHIBIT 无命令
                4'b1zzz: begin
                    state <= idle_t;
                end

                // NO OPERATION NOP
                4'b0111: begin
                end
                
                // ACTIVE 激活目标存储体的一行
                4'b0011: begin
                    state <= active_t;
                    active_rows[ba] <= a;   // 先存储激活的row
                    if (burst_length!=2&&burst_length!=1) $error("sdram don't support burst_length=%x", burst_length);
                    if (mx_cas_latency!=2&&mx_cas_latency!=1) $error("sdram only support cas_latency=%x", mx_cas_latency);
                end

                // READ 读出目标存储体的一列
                4'b0101: begin
                    read_index_max <= read_index_max + 1;
                    if (state == active_t || state == idle_t) begin
                        state <= read_t;
                        addr <= ram_addr + roffset;
                    end
                end

                // WRITE 写入目标存储体的一列
                4'b0100: begin
                    if (state == active_t || state == idle_t) begin
                        state <= write_t;
                        addr <= ram_addr;
                        // $display("write data is dq:%x(%x) counter %x", dq, dqm, counter);

                        if (burst_length == 1) begin
                            wdata <= {16'h0, dq};
                            wmask <= {2'h0, ~dqm};
                            get_unalign_from_mask({2'h0, ~dqm}, woffset, wsize);
                        end else begin
                            wdata <= {dq, wdata[31:16]};
                            wmask <= {~dqm, wmask[3:2]}; 
                        end
                    end
                end

                // BURST TERMINATE 停止当前的突发传输
                4'b0110: begin
                end

                // PRECHARGE和AUTO REFRESH命令与存储单元的电气特性相关, 在仿真环境中不必考虑, 因此可以将其实现成NOP.
                // PERCHARGE 关闭存储体中已激活的行（预充电）
                4'b0010: begin
                end

                // PRECHARGE和AUTO REFRESH命令与存储单元的电气特性相关, 在仿真环境中不必考虑, 因此可以将其实现成NOP.
                // AUTO REFRESH 刷新
                4'b0001: begin
                end

                // Mode寄存器只需要实现CAS Latency和Burst Length, 其他字段可忽略
                // LOAD MODE REGISTER 设置Mode寄存器
                4'b0000: begin
                    mx <= a;
                    // $display("set mx => %x", a);
                end

                default: begin
                    $error("sdram don't support other command 0x%x.", input_cmd);
                end
            endcase

            if (read_done) begin
                addr <= 0;
            end
        end else begin
            state <= idle_t;
            read_index <= 0;
            read_index_max <= 0;
        end
    end

    always @(posedge clk) begin
        case(state)
            idle_t: counter <= 0;
            read_t, write_t: counter <= counter + 1;
            default: counter <= counter;
        endcase
    end

    always @(posedge clk) begin
        case(state)
            idle_t: ;
            active_t: ;

            read_t: begin
                if (counter == (cas_latency + 2 * read_index - 2)) begin
                    // read rdata
                    integer new_rdata = dpi_vdev_read(addr, burst_length == 1 ? 2 : 4);
                    rdata <= new_rdata;
                    read_index <= read_index + 1;
                    addr <= addr + 4;
                    // $display("sdram read data, addr %x data %x index %x", addr, new_rdata, read_index);
                end

                if (read_done) begin
                    // end read rdata
                    state <= idle_t;
                    rdata <= 0;
                end
            end

            write_t: begin
                if (burst_length == 1) begin
                    if (wsize != 0) begin // 当数据量为0时，无需写入任何数据
                        dpi_vdev_write((addr+{30'h0,woffset}), (wdata>>(8*woffset)), {29'h0,wsize});
                        // $display("write data done addr %x data %x size %d counter %x", (addr+{30'h0,woffset}), (wdata>>(8*woffset)), wsize, counter);
                    end
                    state <= idle_t;
                    wmask <= 0;
                end else begin
                    if (counter == 0) begin
                        wdata <= {dq, wdata[31:16]};
                        wmask <= {~dqm, wmask[3:2]};
                        get_unalign_from_mask({~dqm, wmask[3:2]}, woffset, wsize);
                        // $display("write data is dq:%x(%x) counter %x", dq, dqm, counter);
                    end else begin
                        // end write rdata
                        dpi_vdev_write((addr+{30'h0,woffset}), (wdata>>(8*woffset)), {29'h0,wsize});
                        // $display("write data done addr %x data %x size %d counter %x", (addr+{30'h0,woffset}), (wdata>>(8*woffset)), wsize, counter);
                        state <= idle_t;
                        wmask <= 0;
                    end
                end
            end

            err_t: ;
            default: ;
        endcase
    end

endmodule
