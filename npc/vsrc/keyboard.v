module keyboard(
    input clk,reset,ps2_clk,ps2_data,nextdata_n,
    output [7:0] data,
    output reg ready,
    output reg overflow
);

reg [9:0] recv_data;    // current received data
reg [3:0] recv_cnt;     // current received data count
reg [2:0] ps2_clk_sync; // check fall ps2 clk edge
reg [7:0] fifo[7:0];    // data fifo
reg [2:0] w_ptr,r_ptr;  // fifo write and read pointers
reg [2:0] nextdata_n_sync; // check rise edge

assign data = fifo[r_ptr];

always @(posedge clk) begin
    if (reset) begin
        ps2_clk_sync <= 0;
        ready <= 0;
        overflow <= 0;
    end
    else begin
        ps2_clk_sync <= {ps2_clk_sync[1:0],ps2_clk};
        nextdata_n_sync <= {nextdata_n_sync[1:0],nextdata_n};
    end
end

wire sampling = ps2_clk_sync[2] & (~ps2_clk_sync[1]);
wire nextdata = (~nextdata_n_sync[2]) & nextdata_n_sync[1];

always @(posedge clk) begin
    if (!reset) begin
        if (ready) begin
            if (nextdata) begin // read next data
            // if (~nextdata_n) begin // read next data
                r_ptr <= r_ptr + 3'b1;
                if(w_ptr == (r_ptr + 1)) // empty
                    ready <= 1'b0;
            end
        end
        if (sampling) begin
            if (recv_cnt == 4'd10) begin
                if ((recv_data[0] == 0) &&  // start bit
                    (ps2_data == 1) &&  // stop bit
                    (^recv_data[9:1])   // check parity
                ) begin
                    // $display("==> received %x w:%d r:%d\n", recv_data[8:1], w_ptr, r_ptr);
                    fifo[w_ptr] <= recv_data[8:1];
                    w_ptr <= w_ptr + 3'b1;
                    ready <= 1'b1;
                    overflow <= overflow | (r_ptr == (w_ptr + 3'b1));
                end
                recv_cnt <= 4'h0; // next recv
            end else begin
                recv_data[recv_cnt] <= ps2_data;
                recv_cnt <= recv_cnt + 3'b1;
            end
        end
    end
end

initial begin
    if (ps2_data) data[0] = 0;
    else if (nextdata_n) data[0] = 0;
    r_ptr = 0;
    w_ptr = 0;
    recv_cnt = 0;
    recv_data = 0;
    for (int i=0;i<($bits(fifo)/$bits(fifo[0]));++i)
        fifo[i] = 0;
end
    
endmodule //keyboard
