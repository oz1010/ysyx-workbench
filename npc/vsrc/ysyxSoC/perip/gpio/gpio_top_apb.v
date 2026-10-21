module gpio_top_apb(
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

  output [15:0] gpio_out,
  input  [15:0] gpio_in,
  output [7:0]  gpio_seg_0,
  output [7:0]  gpio_seg_1,
  output [7:0]  gpio_seg_2,
  output [7:0]  gpio_seg_3,
  output [7:0]  gpio_seg_4,
  output [7:0]  gpio_seg_5,
  output [7:0]  gpio_seg_6,
  output [7:0]  gpio_seg_7
);

  wire led_ack;
  wire led_sel = in_psel && (in_paddr == 32'h10002000);
  
  wire sw_ack;
  wire sw_sel = in_psel && (in_paddr == 32'h10002004);
  wire [15:0] sw_value;
  
  wire seg_ack;
  wire seg_sel = in_psel && (in_paddr == 32'h10002008);
  wire [7:0]   seg_values[0:7];

  gpio_led m_led(
    .clock(clock),
    .reset(reset),
    .ce_n(!led_sel),
    .we_n(!led_sel),
    .wdata(in_pwdata[15:0]),
    .ack_o(led_ack),
    .led_value_o(gpio_out)
  );

  gpio_sw m_sw(
    .clock(clock),
    .reset(reset),
    .ce_n(!sw_sel),
    .rd_n(!sw_sel),
    .gpio_in(gpio_in),
    .ack_o(sw_ack),
    .sw_value_o(sw_value)
  );

  gpio_seg m_seg(
    .clock(clock),
    .reset(reset),
    .ce_n(!seg_sel),
    .we_n(!seg_sel),
    .wdata(in_pwdata),
    .ack_o(seg_ack),
    .seg_o({
      gpio_seg_0,
      gpio_seg_1,
      gpio_seg_2,
      gpio_seg_3,
      gpio_seg_4,
      gpio_seg_5,
      gpio_seg_6,
      gpio_seg_7
    })
  );

  assign in_pslverr = 1'b0;
  assign in_pready = in_psel && (
      (led_sel && led_ack)
      || (sw_sel && sw_ack)
      || (seg_sel && seg_ack)
      );
  assign in_prdata = sw_sel ? {16'h0, sw_value} : 32'hz;

endmodule
