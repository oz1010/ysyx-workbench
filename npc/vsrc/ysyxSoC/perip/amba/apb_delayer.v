module apb_delayer(
  input         clock,
  input         reset,
  input  [31:0] in_paddr,
  input         in_psel,
  input         in_penable,
  input  [2:0]  in_pprot,
  input         in_pwrite,
  input  [31:0] in_pwdata,
  input  [3:0]  in_pstrb,
  output        in_pready,
  output [31:0] in_prdata,
  output        in_pslverr,

  output [31:0] out_paddr,
  output        out_psel,
  output        out_penable,
  output [2:0]  out_pprot,
  output        out_pwrite,
  output [31:0] out_pwdata,
  output [3:0]  out_pstrb,
  input         out_pready,
  input  [31:0] out_prdata,
  input         out_pslverr
);

    enum [2:0] { idle_t, delay_t, delay_wait_t, err_t } state_t;

    localparam delay_k_bits = 8; // 延时放大系数，对应移位项
    localparam sdram_delay_cycle_delta =  ((`CONFIG_CORE_FREQUENCY << delay_k_bits) / `CONFIG_SDRAM_FREQUENCY) - (1<<delay_k_bits) ; // 每个周期需要延时的累加数，需要减1
    localparam sdram_size = 64*1024*1024;

    reg [31:0] delay_cycle;
    reg [2:0] state;
    reg delay_ready;

    wire sdram_addr_sel = in_paddr>=`CONFIG_SDRAM_BASE && in_paddr<=(`CONFIG_SDRAM_BASE+sdram_size);
    wire [31:0] delay_cycle_delta = sdram_addr_sel ? sdram_delay_cycle_delta : 0;

    assign out_paddr   = in_paddr;
    assign out_psel    = in_psel;
    assign out_penable = in_penable;
    assign out_pprot   = in_pprot;
    assign out_pwrite  = in_pwrite;
    assign out_pwdata  = in_pwdata;
    assign out_pstrb   = in_pstrb;
    assign in_pready   = (delay_cycle_delta != 0) ? 
        (state==idle_t) ? delay_ready : 0
        : out_pready;
    assign in_prdata   = out_prdata;
    assign in_pslverr  = out_pslverr;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            delay_cycle <= 0;
            delay_ready <= 0;
            state <= idle_t;
        end else begin
            case (state)
                idle_t: begin
                    if (in_psel && sdram_addr_sel && sdram_delay_cycle_delta!=0) begin
                        state <= delay_t;
                        delay_cycle <= delay_cycle_delta; // 需要记录第一个周期
                    end
                    if (delay_ready) delay_ready <= 0;
                end

                delay_t: begin
                    delay_cycle <= delay_cycle + delay_cycle_delta;
                    if (out_pready) begin
                        state <= delay_wait_t;
                        delay_cycle <= (delay_cycle >> delay_k_bits);
                    end
                end

                delay_wait_t: begin
                    delay_cycle <= delay_cycle - 1;
                    if (delay_cycle == 0) begin
                        delay_ready <= 1;
                        state <= idle_t;
                        delay_cycle <= 0;
                    end
                end

                default: begin
                    $error("unknown state %x in apb_delayer", state);
                end
            endcase
        end
    end

endmodule
