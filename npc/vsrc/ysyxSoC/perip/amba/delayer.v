/*
 * 信号延时模块，将in_signal的触发信号，等待一定周期后，再通过out_signal释放一个类似的触发信号。触发延时需要满足两个条件
 *   - start 信号开启延时
 *   - delta 延时量不为零
 * 开启延时后，delay_cycle不断累积变化量
 * 当in_signal信号触发，delay_cycle不断进行递减。直到delay_cycle为0时释放out_signal触发信号
 */
module delayer #(
    `ifndef IN_YOSYS_STA
    parameter NAME,
    `endif
    parameter K_BITS = 8 // 延时放大系数，对应移位项
) (
    input               clk,
    input               rst,
    input               start,
    input [31:0]        delta,
    input               in_signal,
    output              out_signal
);

    enum [2:0] { idle_t, delay_t, delay_wait_t, err_t } state_t;

    reg [31:0] delay_cycle;
    reg [2:0] delay_state;
    reg delay_signal;

    assign out_signal   = (delta == 0) ? in_signal :
            (delta!=0 && delay_cycle==0) ? delay_signal : 
            0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            delay_cycle <= 0;
            delay_signal <= 0;
            delay_state <= idle_t;
        end else begin
            case (delay_state)
                idle_t: begin
                    if (start) begin
                        delay_state <= delay_t;
                        delay_cycle <= delta; // 需要记录第一个周期
                        // 启动时直接捕获触发信号
                        if (in_signal) begin
                            delay_state <= delay_wait_t;
                            delay_cycle <= (delta >> K_BITS);
                        end
                    end
                end

                delay_t: begin
                    delay_cycle <= delay_cycle + delta;
                    if (in_signal) begin
                        delay_state <= delay_wait_t;
                        delay_cycle <= (delay_cycle >> K_BITS);
                    end
                end

                delay_wait_t: begin
                    delay_cycle <= delay_cycle - 1;
                    if (delay_cycle == 0) begin
                        delay_signal <= 1;
                        delay_cycle <= 0;
                    end
                end

                default: begin
                    `ifndef IN_YOSYS_STA
                    $error("unknown delay_state %x in %s", delay_state, NAME);
                    `endif
                end
            endcase

            if (delay_signal) begin
                delay_signal <= 0;
                delay_state <= idle_t;
            end
        end
    end

endmodule
