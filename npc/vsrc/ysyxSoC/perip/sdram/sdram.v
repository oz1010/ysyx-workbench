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

    assign dq = 16'bz;

    reg [15:0] read_data;
    reg [15:0] write_data;

    // reg. https://www.mouser.com/datasheet/2/12/alliance_MT48LC-1155509.pdf
    //   Mode Register Definition
    reg [12:0] mx;
    wire [2:0] mx_burst_length = mx[2:0]; // 2^n，有效值：0~3 (1~8)
    wire [2:0] mx_cas_latency = mx[6:4]; // 设定dq执行READ命令几个周期后数据有效，有效取值：1~3，其他保留

    always @(posedge clk) begin
    casez ({cs, ras, cas, we})
        // COMMAND INHIBIT 无命令
        4'b1zzz: begin
        end
        // NO OPERATION NOP
        4'b0111: begin
        end
        // ACTIVE 激活目标存储体的一行
        4'b0011: begin
        end
        // READ 读出目标存储体的一列
        4'b0101: begin
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

endmodule
