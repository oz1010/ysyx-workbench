module top(
  	input clk,
  	input rst,
  	input [4:0] btn,
	input [15:0] sw,
    output [15:0] ledr,
  	output [7:0] seg0,
    output [7:0] seg1,
    output [7:0] seg2,
    output [7:0] seg3,
    output [7:0] seg4,
    output [7:0] seg5,
    output [7:0] seg6,
    output [7:0] seg7
);

reg [7:0] num;
wire click;

assign seg0 = 8'b1111_1111;
assign seg1 = 8'b1111_1111;
assign seg2 = 8'b1111_1111;
assign seg3 = 8'b1111_1111;
assign seg4 = 8'b1111_1111;
assign seg5 = 8'b1111_1111;
assign seg6 = 8'b1111_1111;
assign seg7 = 8'b1111_1111;

// assign ledr[7:0] = num;
// assign click = btn[0];
// dflipflop my_dff(
//     click,
//     num[0],
//     ledr[15]
// );

// wire al = sw[14];
// wire lr = sw[15];
// wire [7:0] din = sw[7:0];
// wire [2:0] shamt = sw[11:9];
// wire [7:0] dout;
// assign ledr[7:0] = dout;
// barrelshifter my_bs(
//     al,
//     lr,
//     din,
//     shamt,
//     dout
// );

assign ledr[7:0] = num;
assign click = btn[0];
lfsr my_lfsr(
    click,
    num
);

initial begin
	$display("[%0t] Model running...\n", $time);
    num = 8'b00011101;
end

always @(posedge click) begin
    num <= {num[0],num[7:1]};
end

endmodule
