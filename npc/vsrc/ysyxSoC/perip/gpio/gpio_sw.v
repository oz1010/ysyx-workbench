module gpio_sw #(
    parameter SW_BITS = 16
) (
    input                   clock,
    input                   reset,
    input                   ce_n,
    input                   rd_n,
    input  [SW_BITS-1:0]    gpio_in,

    output                  ack_o,
    output [SW_BITS-1:0]    sw_value_o
);

reg [SW_BITS-1:0] sw_value;
reg update_ack;

wire update_en = !ce_n && !rd_n;

assign sw_value_o = sw_value;
assign ack_o = update_ack;

initial begin
    sw_value = {SW_BITS{1'b0}};
    update_ack = 0;
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        sw_value <= 0;
        update_ack <= 0;
    end else begin
        if (update_en && !update_ack) begin
            sw_value <= gpio_in;
            // $display("sw value update to %x", gpio_in);
            update_ack <= 1;
        end else begin
            update_ack <= 0;
        end
    end
end

endmodule