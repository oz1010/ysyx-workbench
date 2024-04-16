module bcd_show_hex(
    input [3:0] number,
    output reg [7:0] seg
);

always @(*) begin
    case(number)
        4'h0: seg = 8'b0000_0011;
        4'h1: seg = 8'b1001_1111;
        4'h2: seg = 8'b0010_0101;
        4'h3: seg = 8'b0000_1101;
        4'h4: seg = 8'b1001_1001;
        4'h5: seg = 8'b0100_1001;
        4'h6: seg = 8'b0100_0001;
        4'h7: seg = 8'b0001_1111;
        4'h8: seg = 8'b0000_0001;
        4'h9: seg = 8'b0000_1001;
        4'hA: seg = 8'b0001_0001;
        4'hB: seg = 8'b1100_0001;
        4'hC: seg = 8'b0110_0011;
        4'hD: seg = 8'b1000_0101;
        4'hE: seg = 8'b0110_0001;
        4'hF: seg = 8'b0111_0001;
        default: seg = 8'b1111_1111;
    endcase 
end
    
endmodule //bcd_show_hex
