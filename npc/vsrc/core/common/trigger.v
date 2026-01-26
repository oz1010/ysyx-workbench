module trigger #(
    parameter TRIGGER_TYPE = `TRIGGER_EDGE_POS
) (
    input       clk,
    input       rst,

    input       in,
    output      out
);

generate
    if (TRIGGER_TYPE==`TRIGGER_EDGE_POS || TRIGGER_TYPE==`TRIGGER_EDGE_NEG) begin : edge_mode
        reg in_last;
        wire [1:0] in_edge = {in_last, in};

        always @(posedge clk) begin
            in_last <= in;
        end

        if (TRIGGER_TYPE==`TRIGGER_EDGE_POS) begin
            assign out = in_edge==2'b01;
        end else begin
            assign out = in_edge==2'b10;
        end
    end else begin : level_mode
        if (TRIGGER_TYPE==`TRIGGER_LEVEL_HIGH) begin
            assign out = in==1;
        end else begin
            assign out = in==0;
        end
    end
endgenerate

endmodule