module barrelshifter(
    input al,
    input lr,
    input [7:0] din,
    /* verilator lint_off UNUSEDSIGNAL */
    input [2:0] shamt,
    output [7:0] dout
);

wire high_data = al?din[7]:0;

wire [7:0] data1;
genvar i;
generate for (i=0;i<$bits(din);++i) begin: gen_data1
    mux_42 mux_data1(
        .sel({lr,shamt[0]}),
        .in({
            i<1 ? 1'b0 : din[i-1],
            din[i],
            i>=($bits(din)-1) ? high_data : din[i+1],
            din[i]
        }),
        .out(data1[i])
    );
    end
endgenerate

wire [7:0] data2;
generate for (i=0;i<$bits(din);++i) begin: gen_data2
    mux_42 mux_data2(
        .sel({lr,shamt[1]}),
        .in({
            i<2 ? 1'b0 : data1[i-2],
            data1[i],
            i>=($bits(din)-2) ? high_data : data1[i+2],
            data1[i]
        }),
        .out(data2[i])
    );
    end
endgenerate

wire [7:0] data3;
generate for (i=0;i<$bits(din);++i) begin: gen_data3
    mux_42 mux_data3(
        .sel({lr,shamt[2]}),
        .in({
            i<4 ? 1'b0 : data2[i-4],
            data2[i],
            i>=($bits(din)-4) ? high_data : data2[i+4],
            data2[i]
        }),
        .out(data3[i])
    );
    end
endgenerate

assign dout = data3;

// always @(*) begin
//     $display("==> data1 %x data2 %x", data1, data2);
// end

endmodule //barrelshifter
