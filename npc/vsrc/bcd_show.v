module bcd_show_number(
    input [3:0] number,
    output reg [7:0] segs [1:0]
);
    
bcd_show_impl show_num(
    number,
    0,
    segs[0]
);
bcd_show_impl show_sign(
    number,
    1,
    segs[1]
);

endmodule //bcd_show_sign

module bcd_show_impl(
    input [3:0] number,
    input sign,
    output reg [7:0] seg
);

wire [3:0] num = number[3] ? (~number)+1 : number;

always @(*) begin
    if (sign) seg = number[3] ? 8'b1111_1101 : 8'b1111_1111;
    else begin
       case(num)
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
end
    
endmodule //bcd_show_impl

