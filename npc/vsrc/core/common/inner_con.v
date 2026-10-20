module inner_con #(
) (
    input   wire                        clk,
    input   wire                        rst,

    input   wire                        in_valid,
    output  wire                        in_ready,

    output  wire                        out_valid,
    input   wire                        out_ready,

    output  wire                        stage_in_done,      // 指示输入是否完成
    input   wire                        stage_out_valid,    // 需要保持到stage_out_done使能后
    output  wire                        stage_out_done
);

reg                                     r_in_ready;
reg [`INNER_CON_STATE_W-1:0]            r_stage_state;

assign in_ready = r_in_ready;
assign out_valid = stage_out_valid;
assign stage_in_done = in_valid && in_ready;
assign stage_out_done = out_valid && out_ready;

always @(posedge clk) begin
    if (rst) begin
        r_in_ready <= 0;
        r_stage_state <= `INNER_CON_IDLE;
    end else begin
        case (r_stage_state)
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
                $error("unknown stage_state %d", r_stage_state);
                `endif
            end

        endcase
    end
end
    
endmodule
