module trigger #(
    parameter TRIGGER_TYPE = `TRIGGER_EDGE_POS
) (
    input       clk,
    input       rst,

    input       in,
    output      out
);

reg in_last;
wire [1:0] in_edge = {in_last, in};

assign out = TRIGGER_TYPE==`TRIGGER_EDGE_POS ? in_edge==2'b01 : 0;

always @(posedge clk) begin
    if (rst) begin
        in_last <= 0;
    end else begin
        in_last <= in;
    end
end

endmodule