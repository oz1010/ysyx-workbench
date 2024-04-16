module top(
  	input clk,
  	input rst,
  	input [4:0] btn,
	input [15:0] sw,
    input ps2_clk,
    input ps2_data,
    output [15:0] ledr,
  	output [7:0] seg0,
    output [7:0] seg1,
    output [7:0] seg2,
    output [7:0] seg3,
    output [7:0] seg4,
    output [7:0] seg5,
    output [7:0] seg6,
    output [7:0] seg7
);

reg [7:0] num;
wire click;
wire ready;
wire overflow;

assign seg0 = 8'b1111_1111;
assign seg1 = 8'b1111_1111;
assign seg2 = 8'b1111_1111;
assign seg3 = 8'b1111_1111;
assign seg4 = 8'b1111_1111;
assign seg5 = 8'b1111_1111;
assign seg6 = 8'b1111_1111;
assign seg7 = 8'b1111_1111;

assign click = btn[0];
// assign ledr[7:0] = num;
// assign ledr[15] = overflow;
// assign ledr[14] = ready;

reg [7:0] recv_code;
reg [15:0] store_code;
reg nextdata_n;
reg [7:0] nextdata_n_delay;
assign ledr = store_code;
bcd_show_hex my_bcd_show0(
    store_code[3:0],
    seg0
);
bcd_show_hex my_bcd_show1(
    store_code[7:4],
    seg1
);
bcd_show_hex my_bcd_show2(
    store_code[11:8],
    seg2
);
bcd_show_hex my_bcd_show3(
    store_code[15:12],
    seg3
);
keyboard my_kb(
    .clk(clk),
    .reset(0),
    .ps2_clk(ps2_clk),
    .ps2_data(ps2_data),
    .nextdata_n(nextdata_n),
    .data(num),
    .ready(ready),
    .overflow(overflow)
);

reg [31:0] cnt;
always @(posedge clk) begin
    if (cnt == 0) begin
        if (ready) begin
            cnt <= 32'd8;
        end
    end if (cnt > 0) begin
        cnt <= cnt - 1;
    end
end

always @(negedge clk) begin
    if (cnt > 0) begin
        case (cnt)
            32'd8: begin
                // recv_code <= num;
                store_code <= {store_code[7:0],num};
                // $display("<== read %x\n", num);
                nextdata_n <= 0;
            end
            32'd7: begin
                nextdata_n <= 1;
            end
            default: ;
        endcase
    end
end

// always @(posedge ps2_clk) begin
//     if (ready) begin
//         cnt <= 32'd3;
//         nextdata_n <= 0;
//         recv_code <= num;
//         store_code <= {store_code[7:0],num};
//     end

//     if (cnt > 0) begin
//         case (cnt)
//             32'd3: begin
//                 $display("<== read %x\n", num);
//                nextdata_n <= 1; 
//             end
//             default: ;
//         endcase
//         cnt <= cnt - 1;
//     end

//     // if (cnt) begin
        
//     // end else begin
//     //     cnt <= 32'd
//     // end
//     // nextdata_n = ~ready;
// end

// always @(posedge clk) begin
//     if (ready & nextdata_n) begin
//         recv_code <= num;
//         nextdata_n <= 0;
//         nextdata_n_delay <= 8'h2;
//     end else if ((|nextdata_n_delay) & (~nextdata_n)) begin
//         if (nextdata_n_delay==8'h1) begin
//             nextdata_n <= 1;
//         end
//         nextdata_n_delay <= nextdata_n_delay - 1;
//     end else if (store_code[15:8] == 8'hF0) begin
//         recv_code <= 8'h0;
//     end
// end

initial begin
	$display("[%0t] Model running...\n", $time);
    num = 8'b0;
    cnt = 32'h0;
    recv_code = 8'b0;
    nextdata_n = 1'b1;
end

// always @(posedge click) begin
//     num <= num + 1;
// end

endmodule
