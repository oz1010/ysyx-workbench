module psram(
  input sck,
  input ce_n,
  inout [3:0] dio
);

// assign dio = 4'bz;
// dpi_psram_write

typedef enum [2:0] {
    psram_cmd,
    psram_addr,
    psram_wait,
    psram_outdata,
    psram_done,
    psram_err
} psram_state_t;

reg [2:0] state;
reg [7:0] cnt;
reg [7:0] cmd;
reg [23:0] addr;
reg [31:0] data;
reg dir_control; // 方向控制信号：0=输入，1=输出
reg [3:0] dio_out;

assign dio = (dir_control) ? dio_out : 4'bzzzz;

always @(posedge sck or posedge ce_n ) begin
    if (ce_n) begin
        state <= psram_cmd;
        cnt <= 0;
        cmd <= 0;
        addr <= 0;
        dir_control <= 0;
        dio_out <= 0;
    end else begin
        cnt <= cnt + 1;

        case (cnt) inside
            [0:7]: begin
                dir_control <= 0;
                cmd <= {cmd[6:0], dio[0]};
            end
            
            [8:13]: begin
                if (cnt == 8) begin
                    if (!(cmd==8'heb || cmd==8'h38 )) $error("Found unknown cmd %x in psram", cmd);
                end
                dir_control <= 0;
                addr <= {addr[19:0], dio};
            end

            [14:19]: begin
                if (cmd==8'heb) begin
                    if (cnt==14) data <= dpi_psram_read({8'h0, addr}, 4);
                    if (cnt==15) data <= {data[7:0],data[15:8],data[23:16],data[31:24]};
                end else begin
                    ;
                end
            end

            [20:27]: begin
                dir_control <= 1;
                dio_out <= data[31:28];
                data <= {data[27:0], 4'h0};
            end

            default: cnt <= cnt;
        endcase

    end
end

endmodule
