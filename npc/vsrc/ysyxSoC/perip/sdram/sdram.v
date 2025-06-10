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
  inout [15:0] dq
);
    // ref. https://www.mouser.com/datasheet/2/12/alliance_MT48LC-1155509.pdf

    assign dq = (state==read_t && counter==cas_latency-1) ? rdata[15:0] :
                (state==read_t && (counter==cas_latency)) ? rdata[31:16] :
                16'bz;

    wire [3:0] input_cmd = {cs, ras, cas, we};

    typedef enum [2:0] { idle_t, active_t, read_t, write_t, err_t } state_t;
    reg [2:0] state;
    reg [7:0] counter;
    reg [31:0] addr;
    reg [31:0] rdata;

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

    initial begin
        state = idle_t;
        counter = 0;
        addr = 0;
        rdata = 0;
        wmask = 0;
    end

    always @(posedge clk) begin
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
                /**
                 * ref. Functional Description
                 * ref. Figure 3: 16 Meg x 16 Functional Block Diagram
                 *   每个bank范围：(8192 x 512 x 16)
                 * 地址结构：[row-13bits][bank-2bits][column-9bits][rdata-16bits]
                 * 需要注意数据总线为16bit，及2字节数据，所以地址最低位一直为0
                 */
                addr[31:25] <= 7'h50;   // a000_0000固定地址
                addr[24:12] <= a;       // select the row
                addr[11:10] <= ba;      // select the bank
                addr[0] <= 0;
                if (burst_length!=2) $error("sdram don't support burst_length=%x", burst_length);
                if (mx_cas_latency!=2) $error("sdram only support cas_latency=%x", mx_cas_latency);
            end

            // READ 读出目标存储体的一列
            4'b0101: begin
                if (state == active_t || state == idle_t) begin
                    state <= read_t;
                    addr[9:1] <= a[8:0];    // select the column
                end
            end

            // WRITE 写入目标存储体的一列
            4'b0100: begin
                if (state == active_t || state == idle_t) begin
                    state <= write_t;
                    addr[9:1] <= a[8:0];    // select the column
                    // $display("write data is dq:%x(%x) counter %x", dq, dqm, counter);
                    wdata <= {dq, wdata[31:16]};
                    wmask <= {~dqm, wmask[3:2]};
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
                if (counter == 0) begin
                    // read rdata
                    rdata <= dpi_vdev_read(addr, 4);
                end

                if (counter == cas_latency) begin
                    // end read rdata
                    // $display("read data done addr %x counter %x", addr, counter);
                    state <= idle_t;
                end
            end

            write_t: begin
                if (counter == 0) begin
                    wdata <= {dq, wdata[31:16]};
                    wmask <= {~dqm, wmask[3:2]};
                    get_unalign_from_mask({~dqm, wmask[3:2]}, woffset, wsize);
                    // $display("write data is dq:%x(%x) counter %x", dq, dqm, counter);
                end else begin
                    // end write rdata
                    dpi_vdev_write((addr+{30'h0,woffset}), (wdata>>(8*woffset)), {29'h0,wsize});
                    // $display("write data done addr %x data %x counter %x", addr, wdata, counter);
                    state <= idle_t;
                    wmask <= 0;
                end
            end

            err_t: ;
            default: ;
        endcase
    end

endmodule
