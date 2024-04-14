module dflipflop(
    input clk,
    input in,
    output out
);

wire [4:0] dq,dp;
assign dq[0] = in;
assign out = dq[4];

genvar i;
generate for(i = 0 ; i < 4; i = i + 1) begin : gen_dff
    dflipflop_1bit dff_item(
        clk,
        dq[i],
        dq[i+1],
        dp[i+1]
    );
end
endgenerate

endmodule

module dflipflop_1bit(
    input clk,
    input in,
    output q,p
);
    reg val;

    assign {q,p} = {val,~val};

    always @(posedge clk) begin
        val <= in;
    end

endmodule //dflipflop_1bit
