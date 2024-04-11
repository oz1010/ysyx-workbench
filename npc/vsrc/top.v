module top(
  	input clk,
  	input rst,
  	//input [4:0] btn,
	input [9:0] sw,
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

reg [3:0] num0 = {1'b0, ledr[2:0]};

assign seg1 = 8'b1111_1111;
assign seg2 = 8'b1111_1111;
assign seg3 = 8'b1111_1111;
assign seg4 = 8'b1111_1111;
assign seg5 = 8'b1111_1111;
assign seg6 = 8'b1111_1111;
assign seg7 = 8'b1111_1111;

bcd_show my_bcd0(
    num0,
    seg0
);

decode83 my_dc83(
    sw[7:0],
    ledr[2:0],
    ledr[3]
);

initial begin
	$display("[%0t] Model running...\n", $time);
end

endmodule
