module bcd_show(
    input [3:0] number,
    output reg [7:0] seg
);

always @(*) begin
    case(number)
        0: seg = 8'b0000_0011;
        1: seg = 8'b1001_1111;
        2: seg = 8'b0010_0101;
        3: seg = 8'b0000_1101;
        4: seg = 8'b1001_1001;
        5: seg = 8'b0100_1001;
        6: seg = 8'b0100_0001;
        7: seg = 8'b0001_1111;
        8: seg = 8'b0000_0001;
        9: seg = 8'b0000_1001;
        default: seg = 8'b1111_1111;
    endcase
end
    
endmodule //bcd_show
