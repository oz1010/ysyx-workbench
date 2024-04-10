module top(
  	input clk,
  	input rst,
  	//input [4:0] btn,
	input [9:0] sw,
    output [15:0] ledr
  	//input a,
  	//input b,
  	//output f
);

// led my_led(
// 	.clk(clk),
// 	.rst(rst),
// 	.sw(sw[7:0]),
// 	.ledr(ledr)
// );

mux42 my_mux(
    .Y(sw[1:0]),
    .X(sw[9:2]),
    .F(ledr[1:0])
);

//assign f = a ^ b;

initial begin
    // if ($test$plusargs("trace") != 0) begin
	//     $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
	//     $dumpfile("logs/vlt_dump.vcd");
	//     $dumpvars();
	// end
	$display("[%0t] Model running...\n", $time);
end

endmodule
