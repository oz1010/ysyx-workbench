module vga_top_apb(
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

  output [7:0]  vga_r,
  output [7:0]  vga_g,
  output [7:0]  vga_b,
  output        vga_hsync,
  output        vga_vsync,
  output        vga_valid
);

wire [23:0]   vga_rgb;
wire [9:0]    h_addr;
wire [9:0]    v_addr;

vga_fb m_vga_fb(
  .clk(clock),
  .rst(reset),
  .in_paddr(in_paddr),
  .in_psel(in_psel),
  .in_penable(in_penable),
  .in_pprot(in_pprot),
  .in_pwrite(in_pwrite),
  .in_pwdata(in_pwdata),
  .in_pstrb(in_pstrb),
  .in_pready(in_pready),
  .in_prdata(in_prdata),
  .in_pslverr(in_pslverr),
  .vga_rgb(vga_rgb),
  .h_addr(h_addr),
  .v_addr(v_addr)
);

vga_ctrl m_vga_ctrl(
    .clk(clock),      //25MHz时钟
    .rst(reset),    //置位
    .vga_rgb(vga_rgb), //上层模块提供的VGA颜色数据
    .h_addr(h_addr),   //提供给上层模块的当前扫描像素点坐标
    .v_addr(v_addr),
    .hsync(vga_hsync),    //行同步和列同步信号
    .vsync(vga_vsync),
    .valid(vga_valid),    //消隐信号
    .vga_r(vga_r),    //红绿蓝颜色信号
    .vga_g(vga_g),
    .vga_b(vga_b)
    );

endmodule
