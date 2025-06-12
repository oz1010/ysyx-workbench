module gpio_seg (
    input                   clk,
    input                   rst,
    input                   ce_n,
    input                   we_n,
    input  [31:0]           wdata,

    output                  ack_o,
    output [SEG_BITS-1:0]   seg_values_o[0:SEG_NUM-1]
);

parameter SEG_BITS = 8;
parameter SEG_NUM = 8;

reg [SEG_BITS-1:0]   seg_values[0:SEG_NUM-1];
reg update_ack;

wire update_en = !ce_n && !we_n;

assign seg_values_o = seg_values;
assign ack_o = update_ack;

// initial begin
//     seg_values = {LED_BITS{1'b0}};
//     update_ack = 0;
// end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (int i=0; i<SEG_NUM; ++i) begin
            seg_values[i] <= 0;
        end
        update_ack <= 0;
    end else begin
        if (update_en && !update_ack) begin
            // seg_values <= wdata;
            // $display("seg value update to %d(0x%x)", wdata, wdata);
            update_ack <= 1;
        end else begin
            update_ack <= 0;
        end
    end
end

endmodule