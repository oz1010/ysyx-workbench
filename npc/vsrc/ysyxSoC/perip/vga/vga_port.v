module vga_port(
    input           clock,
    input           reset,
    input  [23:0]   vga_rgb,
    output [9:0]    h_addr,
    output [9:0]    v_addr,
    output          hsync,
    output          vsync,
    output          valid,
    output [7:0]    vga_r,
    output [7:0]    vga_g,
    output [7:0]    vga_b,
    input           fb_sync_valid,
    output          fb_sync_ready_o
);

  //640x480分辨率下的VGA参数设置
  parameter     h_frontporch = 96;
  parameter     h_active = 144;
  parameter     h_backporch = 784;
  parameter     h_total = 800;

  parameter     v_frontporch = 2;
  parameter     v_active = 35;
  parameter     v_backporch = 515;
  parameter     v_total = 525;

  //像素计数值
  reg           fb_sync_en = 1; // 一直开启刷新后不关闭，实时同步
  reg           fb_sync_ready;
  reg [9:0]     x_cnt;
  reg [9:0]     y_cnt;
  wire          h_valid;
  wire          v_valid;

  assign fb_sync_ready_o = fb_sync_ready;

  always @(posedge clock or posedge reset)
    if (reset) begin
      // fb_sync_en <= 0;
      fb_sync_ready <= 0;
    end else begin
      if (fb_sync_en) begin
      end else begin
        if (fb_sync_valid) begin
          fb_sync_ready <= 1;
        end

        if (fb_sync_valid && fb_sync_ready) begin
          fb_sync_en <= 1;
          fb_sync_ready <= 0;
          // $display("====== fb_sync_en start");
        end
      end
    end

  always @(posedge clock or posedge reset) //行像素计数
      if (reset == 1'b1)
        x_cnt <= 1;
      else
      begin
        if (fb_sync_en) begin
          if (x_cnt == h_total)
            x_cnt <= 1;
          else
            x_cnt <= x_cnt + 10'd1;
        end else begin
          x_cnt <= 1;
        end
      end

  always @(posedge clock or posedge reset)  //列像素计数
      if (reset == 1'b1)
        y_cnt <= 1;
      else
      begin
        if (fb_sync_en) begin
          if (y_cnt == v_total & x_cnt == h_total) begin
            // 开启刷新后不关闭，实时同步
            // fb_sync_en <= 0;
            y_cnt <= 1;
            // $display("====== fb_sync_en done");
          end else if (x_cnt == h_total) begin
            y_cnt <= y_cnt + 10'd1;
          end
        end else begin
          y_cnt <= 1;
        end
      end
  //生成同步信号
  assign hsync = (x_cnt > h_frontporch);
  assign vsync = (y_cnt > v_frontporch);
  //生成消隐信号
  assign h_valid = (x_cnt > h_active) & (x_cnt <= h_backporch);
  assign v_valid = (y_cnt > v_active) & (y_cnt <= v_backporch);
  assign valid = h_valid & v_valid;
  //计算当前有效像素坐标
  assign h_addr = h_valid ? (x_cnt - 10'd145) : {10{1'b0}};
  assign v_addr = v_valid ? (y_cnt - 10'd36) : {10{1'b0}};
  //设置输出的颜色值
  assign vga_r = vga_rgb[23:16];
  assign vga_g = vga_rgb[15:8];
  assign vga_b = vga_rgb[7:0];
endmodule