module psram(
  input sck,
  input ce_n,
  inout [3:0] dio
);

// assign dio = 4'bz;

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
reg [7:0] write_cnt;
reg [7:0] write_byte;

assign dio = (dir_control) ? dio_out : 4'bzzzz;

always @(posedge sck or posedge ce_n ) begin
    if (ce_n) begin
        state <= psram_cmd;
        cnt <= 0;
        cmd <= 0;
        addr <= 0;
        dir_control <= 0;
        dio_out <= 0;
        write_cnt <= 0;
        write_byte <= 0;
        data <= 0;

        if (cmd==8'h38) begin
            // $display("Found cmd %x addr %x data %x cnt %d write_cnt %d", cmd, addr, data, cnt, write_cnt);
            if (write_cnt>0 && write_cnt<=4) dpi_psram_write({8'h0, addr}, {24'h0, write_cnt}, data);
        end
    end else begin
        cnt <= cnt + 1;

        case (cnt) inside
            [0:7]: begin // command
                dir_control <= 0;
                cmd <= {cmd[6:0], dio[0]};
            end
            
            [8:13]: begin // address
                if (cnt == 8) begin
                    if (!(cmd==8'heb || cmd==8'h38 )) $error("Found unknown cmd %x in psram", cmd);
                end
                dir_control <= 0;
                addr <= {addr[19:0], dio};
                write_cnt <= 0;
                write_byte <= 0;
            end

            [14:27]: begin
                if (cmd==8'heb) begin
                    if (cnt==14) data <= dpi_psram_read({8'h0, addr}, 4);
                    if (cnt==15) data <= {data[7:0],data[15:8],data[23:16],data[31:24]};
                    if (cnt>=20&&cnt<=27) begin
                        dir_control <= 1;
                        dio_out <= data[31:28];
                        data <= {data[27:0], 4'h0};
                    end
                end else if (cmd==8'h38) begin
                    if (cnt>=14&&cnt<=21) begin
                        dir_control <= 0;
                        // data <= {data[27:0], dio};
                        write_byte <= {write_byte[3:0], dio};
                        case (cnt)
                            8'd15: begin data[7:0]   <= {write_byte[3:0], dio}; write_cnt <= write_cnt+1; end
                            8'd17: begin data[15:8]  <= {write_byte[3:0], dio}; write_cnt <= write_cnt+1; end
                            8'd19: begin data[23:16] <= {write_byte[3:0], dio}; write_cnt <= write_cnt+1; end
                            8'd21: begin data[31:24] <= {write_byte[3:0], dio}; write_cnt <= write_cnt+1; end
                            default: ;
                        endcase
                    end
                end
            end

            default: cnt <= cnt;
        endcase

    end
end

endmodule
