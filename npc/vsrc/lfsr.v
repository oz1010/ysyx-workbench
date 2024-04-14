// Linear-feedback shift register
module lfsr(
    input clk,
    output [7:0] out
);
    reg [7:0] data;


assign out = data;

always @(posedge clk) begin
    data <= {^{data[4:2],data[0]}, data[7:1]};
end

initial begin
    data = 8'h1;
end

endmodule //lfsr
