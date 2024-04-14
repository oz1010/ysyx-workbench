module top(
  	input clk,
  	input rst,
  	//input [4:0] btn,
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

wire [3:0] num_a = sw[15:12];
wire [3:0] num_b = sw[11:8];
wire [2:0] func = sw[2:0];
wire [3:0] out;

assign seg0 = 8'b1111_1111;
assign seg1 = 8'b1111_1111;
assign seg2 = 8'b1111_1111;
assign seg3 = 8'b1111_1111;
assign seg4 = 8'b1111_1111;
assign seg5 = 8'b1111_1111;
assign seg6 = 8'b1111_1111;
assign seg7 = 8'b1111_1111;
assign ledr[3:0] = out;

bcd_show_number my_bcd_a(
    num_a,
    {seg7,seg6}
);
bcd_show_number my_bcd_b(
    num_b,
    {seg5,seg4}
);
bcd_show_number my_bcd_out(
    out,
    {seg1,seg0}
);

alu my_alu(
    func,
    num_a,
    num_b,
    out,
    ledr[7],
    ledr[6],
    ledr[5]
);

initial begin
	$display("[%0t] Model running...\n", $time);
end

endmodule
