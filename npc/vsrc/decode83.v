module decode83(
    input [7:0] code,
    output reg [2:0] out,
    output valide
);

assign valide = code!=0;

always @(code) begin
    casez (code)
        8'b0000_0001: out = 0;
        8'b0000_001z: out = 1;
        8'b0000_01zz: out = 2;
        8'b0000_1zzz: out = 3;
        8'b0001_zzzz: out = 4;
        8'b001z_zzzz: out = 5;
        8'b01zz_zzzz: out = 6;
        8'b1zzz_zzzz: out = 7;
        default: out = 0;
    endcase
end
    
endmodule //decode83
