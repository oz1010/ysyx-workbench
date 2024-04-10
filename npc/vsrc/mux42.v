module mux42(
    input [7:0] X,
    input [1:0] Y,
    output [1:0] F
);
    MuxKeyWithDefault #(4, 2, 2) s0 (F, Y, 2'h0, {
        2'b00, X[1:0],
        2'b01, X[3:2],
        2'b10, X[5:4],
        2'b11, X[7:6]
    });
    // assign F = 2'b01;
endmodule