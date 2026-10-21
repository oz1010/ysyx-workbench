module ps2_top_apb(
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

  input         ps2_clk,
  input         ps2_data
);

    wire ps2_ack;
    wire ps2_sel = in_psel && (in_paddr == 32'h10011000);

    ps2_ctrl m_ps2_ctrl(
        .clock(clock),
        .reset(reset),
        .rd_n(!ps2_sel),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .ack_o(ps2_ack),
        .key_value_o(in_prdata[7:0])
    );
    assign in_prdata[31:8] = 0;
    assign in_pslverr = 1'b0;
    assign in_pready = in_psel && ((ps2_sel && ps2_ack));

endmodule
