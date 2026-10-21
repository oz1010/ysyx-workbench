module ps2_ctrl (
    input                   clock,
    input                   reset,
    input                   rd_n,
    input                   ps2_clk,
    input                   ps2_data,

    output                  ack_o,
    output [7:0]            key_value_o
);

localparam KEY_QUEUE_SIZE_BITS = 3;
localparam KEY_QUEUE_SIZE = 1<<KEY_QUEUE_SIZE_BITS;

typedef enum [2:0] {
    idle_t,
    data_t,
    parity_t,
    stop_t,
    err_t
} ps2_state_t;

reg [2:0] state;
reg [15:0] ps2_clk_queue;
reg [7:0] data_bit;
reg [7:0] data_bit_cnt;
reg [7:0] key_queue[0:KEY_QUEUE_SIZE-1];
reg [7:0] key_ridx;
reg [7:0] key_widx;
reg parity;
wire [7:0] key_queue_cnt = key_widx - key_ridx;
wire data_bit_en = ps2_clk_queue==16'h0ffe; // 正常clk应该都是拉低，重启后一直为高电平，需要避免第一个clk造成异常触发影响
reg [7:0] key_value;
reg key_ack;

assign key_value_o = key_value;
assign ack_o = key_ack;

initial begin
    state = idle_t;
    for(integer i=0; i<KEY_QUEUE_SIZE; ++i) begin
        key_queue[i] = 0;
    end
    key_ridx = 0;
    key_widx = 0;
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        ps2_clk_queue <= 0;
    end else begin
        ps2_clk_queue <= {ps2_clk_queue[14:0], ps2_clk};
    end
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        parity <= 0;
    end else begin
        if (data_bit_en) begin
            if (state == parity_t) begin
                parity <= !(^data_bit);
            end
        end
    end
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= idle_t;
    end else begin
        if (data_bit_en) begin
            case (state)
                idle_t: begin
                    if (ps2_data == 0) state <= state + 1;
                end

                data_t: begin
                    if (data_bit_cnt == 7) begin
                        state <= state + 1;
                    end
                end

                err_t, stop_t:
                    state <= idle_t;

                default:
                    state <= state + 1;
            endcase
        end
    end
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        data_bit_cnt <= 0;
    end else begin
        if (data_bit_en) begin
            case (state)
                idle_t, stop_t: data_bit_cnt <= 0;
                default: data_bit_cnt <= data_bit_cnt + 1;
            endcase
        end
    end
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        data_bit <= 0;
        key_widx <= 0;
    end else begin
        if (data_bit_en) begin
            case (state)
                data_t: data_bit <= {ps2_data, data_bit[7:1]};
                stop_t: begin
                    // 避免频繁捕获相同普通按键
                    if (key_queue_cnt >= 3) begin
                        // $display("key queue is too small %d", key_queue_cnt);
                        if (key_queue_cnt<(KEY_QUEUE_SIZE-2) && data_bit != key_queue[(key_widx-1)%KEY_QUEUE_SIZE]) begin
                            key_queue[key_widx[KEY_QUEUE_SIZE_BITS-1:0]] <= data_bit;
                            key_widx <= key_widx + 1;
                        end
                    end else begin
                        key_queue[key_widx[KEY_QUEUE_SIZE_BITS-1:0]] <= data_bit;
                        key_widx <= key_widx + 1;
                    end
                end
                default: ;
            endcase
        end
    end
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        key_value <= 0;
        key_ridx <= 0;
        key_ack <= 0;
    end else begin
        if (!rd_n && !key_ack) begin
            if (state != stop_t && key_queue_cnt > 0) begin
                key_value <= key_queue[key_ridx[KEY_QUEUE_SIZE_BITS-1:0]];
                key_ridx <= key_ridx + 1;
            end else begin
                key_value <= 0;
            end
            key_ack <= 1;
        end else begin
            key_value <= 0;
            key_ack <= 0;
        end
    end
end

endmodule