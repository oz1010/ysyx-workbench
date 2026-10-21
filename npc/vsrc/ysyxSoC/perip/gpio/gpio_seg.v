module gpio_seg (
    input                   clock,
    input                   reset,
    input                   ce_n,
    input                   we_n,
    input  [31:0]           wdata,

    output                  ack_o,
    output [SEG_BITS-1:0]   seg_o[0:SEG_NUM-1]
);

parameter SEG_BITS = 8;
parameter SEG_NUM = 8;

reg [31:0] seg_value;
reg update_ack;

wire update_en = !ce_n && !we_n;
assign ack_o = update_ack;

// 8位共阳极数码管编码表，编码顺序为 a b c d e f g dp（dp为小数点，共阳极 0点亮，1熄灭）
logic [7:0] hex_seg_codes [] = '{
    8'b00000011,  // 0
    8'b10011111,  // 1
    8'b00100101,  // 2
    8'b00001101,  // 3
    8'b10011001,  // 4
    8'b01001001,  // 5
    8'b01000001,  // 6
    8'b00011111,  // 7
    8'b00000001,  // 8
    8'b00001001,  // 9
    8'b00010001,  // A
    8'b11000001,  // B
    8'b01100011,  // C
    8'b10000101,  // D
    8'b01100001,  // E
    8'b01110001   // F
};
generate
    genvar i;
    for(i=0; i<SEG_NUM; ++i) begin : seg_values_list
        assign seg_o[i] = hex_seg_codes[seg_value[4*i +: 4]];
    end
endgenerate

initial begin
    seg_value = 0;
    update_ack = 0;
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        seg_value <= 0;
        update_ack <= 0;
    end else begin
        if (update_en && !update_ack) begin
            seg_value <= wdata;
            // $display("seg value update to %d(0x%x)", wdata, wdata);
            update_ack <= 1;
        end else begin
            update_ack <= 0;
        end
    end
end

endmodule