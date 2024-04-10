module top(
    input   a,b,s,
    output  y
    );
  assign  y = (~s&a)|(s&b);  // 实现电路的逻辑功能。

endmodule
