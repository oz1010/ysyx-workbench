module bitrev (
  input  sck,
  input  ss,
  input  mosi,
  output miso
);

typedef enum[1:0] {
    BITREV_IN,
    BITREV_OUT,
    BITREV_WAIT
} bitrev_state_t;

reg [7:0] bits;
reg [2:0] cnt;
reg [1:0] state;
reg out_bit;

assign miso = out_bit;

always @(posedge sck or posedge ss) begin
    if (ss) begin
        bits <= 0;
        cnt <= 0;
        state <= BITREV_IN;
        out_bit <= 1;
    end else begin
        case (state)
            BITREV_IN: begin
                cnt <= cnt + 1;
                bits[cnt] <= mosi;

                if (cnt == 7) begin
                    state <= BITREV_OUT;
                    out_bit <= mosi;
                    cnt <= cnt -1;
                end
            end

            BITREV_OUT: begin
                cnt <= cnt - 1;
                out_bit <= bits[cnt];

                if (cnt == 0) begin
                    bits <= 0;
                    cnt <= 0;
                    state <= BITREV_WAIT;
                end
            end

            default: begin
                bits <= 0;
                cnt <= 0;
                state <= state;
                out_bit <= 1;
            end
        endcase
    end
end

endmodule
