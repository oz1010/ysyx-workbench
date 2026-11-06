module gpio_led #(
    parameter LED_BITS = 16
) (
    input                   clock,
    input                   reset,
    input                   ce_n,
    input                   we_n,
    input  [LED_BITS-1:0]   wdata,

    output                  ack_o,
    output [LED_BITS-1:0]   led_value_o
);

reg [LED_BITS-1:0]  led_value;
reg update_ack;

wire update_en = !ce_n && !we_n;

assign led_value_o = led_value;
assign ack_o = update_ack;

initial begin
    led_value = {LED_BITS{1'b0}};
    update_ack = 0;
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        led_value <= 0;
        update_ack <= 0;
    end else begin
        if (update_en && !update_ack) begin
            led_value <= wdata;
            // $display("led value update to %x", wdata);
            update_ack <= 1;
        end else begin
            update_ack <= 0;
        end
    end
end

endmodule