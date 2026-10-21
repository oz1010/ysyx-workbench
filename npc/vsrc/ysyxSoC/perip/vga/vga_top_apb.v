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
wire fb_sync_valid;
wire fb_sync_ready;

vga_regs m_vga_regs(
  .clock(clock),
  .reset(reset),
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
  .v_addr(v_addr),
  .fb_sync_valid_o(fb_sync_valid),
  .fb_sync_ready(fb_sync_ready)
);

vga_port m_vga_port(
  .clock(clock),
  .reset(reset),
  .vga_rgb(vga_rgb),
  .h_addr(h_addr),
  .v_addr(v_addr),
  .hsync(vga_hsync),
  .vsync(vga_vsync),
  .valid(vga_valid),
  .vga_r(vga_r),
  .vga_g(vga_g),
  .vga_b(vga_b),
  .fb_sync_valid(fb_sync_valid),
  .fb_sync_ready_o(fb_sync_ready)
);

endmodule
