module uart #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clk,
    input wire rst,

    input wire aw_valid,
    output wire aw_ready,
    input wire [ADDR_WIDTH-1:0] aw_addr,

    input wire w_valid,
    output wire w_ready,
    input wire [DATA_WIDTH-1:0] w_data,
    input wire [DATA_WIDTH/8-1:0] w_strb,

    output wire b_valid,
    input wire b_ready,
    output wire [BRESP_WIDTH-1:0] b_resp,

    input wire ar_valid,
    output wire ar_ready,
    input wire [ADDR_WIDTH-1:0] ar_addr,

    output wire r_valid,
    input wire r_ready,
    output wire [DATA_WIDTH-1:0] r_data,
    output wire [RRESP_WIDTH-1:0] r_resp
);

reg [ADDR_WIDTH-1:0] r_write_addr;

reg r_aw_ready;
reg r_w_ready;
reg r_b_valid;
reg [BRESP_WIDTH-1:0] r_b_resp;
reg r_ar_ready;
reg r_r_valid;
reg [DATA_WIDTH-1:0] r_r_data;
reg [RRESP_WIDTH-1:0] r_r_resp;

wire [DATA_WIDTH-1:0] w_write_width = {{DATA_WIDTH-DATA_WIDTH/8{1'b0}}, w_strb};

assign aw_ready = r_aw_ready;
assign w_ready = r_w_ready;
assign b_valid = r_b_valid;
assign b_resp = r_b_resp;
assign ar_ready = r_ar_ready;
assign r_valid = r_r_valid;
assign r_data = r_r_data;
assign r_resp = r_r_resp;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_write_addr <= 0;
        r_aw_ready <= 0;
        r_w_ready <= 0;
        r_b_valid <= 0;
        r_b_resp <= 0;
        r_ar_ready <= 0;
        r_r_valid <= 0;
        r_r_data <= 0;
        r_r_resp <= 0;
    end else begin
        r_write_addr <= r_write_addr;
        r_aw_ready <= r_aw_ready;
        r_w_ready <= r_w_ready;
        r_b_valid <= r_b_valid;
        r_b_resp <= r_b_resp;
        r_ar_ready <= r_ar_ready;
        r_r_valid <= r_r_valid;
        r_r_data <= r_r_data;
        r_r_resp <= r_r_resp;

        // write request
        if (aw_valid) begin
            r_aw_ready <= 1;
        end
        if (aw_valid && aw_ready) begin
            r_write_addr <= aw_addr;
            r_aw_ready <= 0;
        end

        // write data
        if (aw_valid && aw_ready) begin
            r_w_ready <= 1;
        end
        if (w_valid && w_ready) begin
            // $display("====== uart:%x strb:%d '%c'", r_write_addr, w_strb, w_data[7:0]);
            // print data
            $write("%c", w_data[7:0]);
            $fflush();
            write_raw_dev(r_write_addr, w_write_width, w_data);
            r_w_ready <= 0;
        end

        // write response
        if (w_valid && w_ready) begin
            r_b_valid <= 1;
            r_b_resp <= 1;
        end
        if (b_valid && b_ready) begin
            r_b_valid <= 0;
            r_b_resp <= 0;
        end

        // read request
        // if (!r_ar_ready && !r_ready) begin
        //     r_ar_ready <= 1;
        // end
        // if (ar_valid && ar_ready) begin
        //     r_ar_ready <= 0;
        // end

        // read data
        if (ar_valid && ar_ready) begin
            $display("uart don't support read, addr:%x", ar_addr);
            $finish();
            r_r_valid <= 1;
        end
        if (r_valid && r_ready) begin
            r_r_valid <= 0;
            r_r_resp <= 0;
        end
    end
end

endmodule