/*
 * 信号延时模块，将in_signal的触发信号，等待一定周期后，再通过out_signal释放一个类似的触发信号。触发延时需要满足两个条件
 *   - start 信号开启延时
 *   - delta 延时量不为零
 * 当start信号触发，delay_cycle不断累积变化量
 * 当catch信号触发，delay_cycle不断进行递减。直到delay_cycle为0时释放out_signal触发信号
 */
module delayer #(
    `ifndef IN_YOSYS_STA
    parameter NAME,
    `endif
    parameter SIGNAL_WIDTH = 1,
    parameter SKIP_DELAY_EN = 0,
    parameter K_BITS = 8 // 延时放大系数，对应移位项
) (
    input               clk,
    input               rst,
    input               enable,
    input               start,
    input               catch,
    input [31:0]        delta,
    input [SIGNAL_WIDTH-1:0]    in_signal,
    output [SIGNAL_WIDTH-1:0]   out_signal
);

    enum [2:0] { idle_t, delay_t, delay_wait_t, err_t } state_t;

    reg [31:0] delay_cycle;
    reg [2:0] delay_state;
    reg delay_signal;
    reg last_start, last_catch;

    assign out_signal   = {SIGNAL_WIDTH{delay_signal}};
    
    // 转换为触发信号，类似捕捉上升沿
    always @(posedge clk) begin
        last_start <= start;
        last_catch <= catch;
    end
    wire start_trigger = enable && start && !last_start;
    wire catch_trigger = enable && catch && !last_catch;

    always @(posedge clk or posedge rst) begin
        if (rst || !enable) begin
            delay_cycle <= 0;
            delay_signal <= 0;
            delay_state <= idle_t;
        end else begin
            case (delay_state)
                idle_t: begin
                    if (start_trigger && delta!=0) begin
                        delay_state <= delay_t;
                        delay_cycle <= delta; // 需要记录第一个周期
                        // 启动时直接捕获触发信号
                        if (catch_trigger && SKIP_DELAY_EN) begin
                            delay_state <= delay_wait_t;
                            delay_cycle <= (delta >> K_BITS);
                        end
                    end
                end

                delay_t: begin
                    delay_cycle <= delay_cycle + delta;
                    if (catch_trigger) begin
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
