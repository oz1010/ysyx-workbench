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

    // TODO 需要解决读写序号问题
    assign dq = (state==read_t && counter==cas_latency-1) ? data[15:0] :
                (state==read_t && (counter==cas_latency)) ? data[31:16] :
                16'bz;

    typedef enum [2:0] { idle_t, active_t, read_t, write_t, err_t } state_t;
    reg [2:0] state;
    reg [7:0] counter;
    reg [31:0] addr;
    reg [31:0] data;
    reg [15:0] read_data;
    reg [15:0] write_data;

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
        data = 0;
    end

    always @(posedge clk) begin
        casez ({cs, ras, cas, we})
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
                 * 地址结构：[row-13bits][bank-2bits][column-9bits][data-16bits]
                 * 需要注意数据总线为16bit，及2字节数据，所以地址最低位一直为0
                 */
                addr[31:25] <= 0;
                addr[24:12] <= a;   // select the row
                addr[11:10] <= ba;  // select the bank
                addr[0] <= 0;
                if (burst_length!=2) $error("sdram don't support burst_length=%x", burst_length);
                if (mx_cas_latency!=2) $error("sdram only support cas_latency=%x", mx_cas_latency);
            end

            // READ 读出目标存储体的一列
            4'b0101: begin
                if (state == active_t) begin
                    state <= read_t;
                    addr[9:1] <= a[8:0];    // select the column
                end
            end

            // WRITE 写入目标存储体的一列
            4'b0100: begin
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
                $error("sdram don't support other command {cs,ras,cas,we}=0x%x.", {cs, ras, cas, we});
            end
        endcase
    end

    always @(posedge clk) begin
        case(state)
            read_t, write_t: counter <= counter + 1;
            default: counter <= 0;
        endcase
    end

    always @(posedge clk) begin
        case(state)
            idle_t: ;
            active_t: ;

            read_t: begin
                if (counter == 0) begin
                    // read data
                    $display("====== set debug data %x at addr %x", addr, 32'ha0000000 + addr);
                    data <= 32'ha0000000 + addr;
                end

                if (counter == (cas_latency+1)) begin
                    // end read data
                    // $display("read data done addr %x counter %x", addr, counter);
                    state <= idle_t;
                end
            end

            write_t: ;
            err_t: ;
            default: ;
        endcase
    end

endmodule
