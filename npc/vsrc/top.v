module top(
  	input clk,
  	input rst,
  	//input [4:0] btn,
	input [7:0] sw,
    output [15:0] ledr
  	//input a,
  	//input b,
  	//output f
);

led my_led(
	.clk(clk),
	.rst(rst),
	.sw(sw),
	.ledr(ledr)
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
