module inner_con #(
    parameter IN_DATA_STORAGE = 1, // 输入数据存储模式，stage_in_bits可以维持多个周期，但会存在延时；若是直连模式，stage_in_bits只能维持一个周期；
    parameter IN_DATA_W = 1
) (
    input   wire                        clk,
    input   wire                        rst,

    input   wire                        in_valid,
    output  wire                        in_ready,
    input   wire [IN_DATA_W-1:0]        in_bits,

    output  wire                        out_valid,
    input   wire                        out_ready,

    output  wire [IN_DATA_W-1:0]        stage_in_bits,
    output  wire                        stage_in_done,      // 指示输入是否完成
    input   wire                        stage_out_valid,    // 需要保持到stage_out_done使能后
    output  wire                        stage_out_done,
    output  wire [`INNER_CON_STATE_W-1:0]   stage_state
);

reg                                     r_in_ready;
reg [`INNER_CON_STATE_W-1:0]            r_stage_state;

assign in_ready = r_in_ready;
assign out_valid = stage_out_valid;
assign stage_in_done = in_valid && in_ready;
assign stage_out_done = out_valid && out_ready;
assign stage_state = r_stage_state;

generate
    if (IN_DATA_STORAGE) begin : storage_mode
        reg [IN_DATA_W-1:0] r_in_bits;
        assign stage_in_bits = r_in_bits;
        always @(posedge clk) begin
            if (rst) begin
                r_in_bits <= 0;
            end else begin
                if (stage_state==`INNER_CON_IDLE && stage_in_done) r_in_bits <= in_bits;
            end
        end
    end else begin
        assign stage_in_bits = in_bits;
    end
endgenerate

always @(posedge clk) begin
    if (rst) begin
        r_in_ready <= 0;
        r_stage_state <= `INNER_CON_IDLE;
    end else begin
        case (stage_state)
            `INNER_CON_IDLE: begin
                r_in_ready <= 1;
                if (stage_in_done) begin
                    r_in_ready <= 0;
                    r_stage_state <= `INNER_CON_BUSY;
                end
            end

            `INNER_CON_BUSY: begin
                r_in_ready <= 0;
                if (stage_out_done) begin
                    r_in_ready <= 1;
                    r_stage_state <= `INNER_CON_IDLE;
                end
            end

            default: begin
                `ifndef IN_YOSYS_STA
                $error("unknown stage_state %d", stage_state);
                `endif
            end

        endcase
    end
end
    
endmodule
