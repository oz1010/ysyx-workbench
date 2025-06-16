module vga_fb (
    input                   clk,
    input                   rst,
    input  [31:0]           in_paddr,
    input                   in_psel,
    input                   in_penable,
    input  [2:0]            in_pprot,
    input                   in_pwrite,
    input  [31:0]           in_pwdata,
    input  [3:0]            in_pstrb,
    output                  in_pready,
    output [31:0]           in_prdata,
    output                  in_pslverr,

    output [7:0]            vga_r,
    output [7:0]            vga_g,
    output [7:0]            vga_b,
    output                  vga_hsync,
    output                  vga_vsync,
    output                  vga_valid
);

localparam      VGA_CTRL_WIDTH = 640;
localparam      VGA_CTRL_HIGH = 480;
localparam      VGA_RGB_BIT_WIDTH = 24;
localparam      VGA_COUNTER_BIT_WIDTH = 10;

localparam      h_frontporch = 96;
localparam      h_active = (h_frontporch+48);
localparam      h_backporch = (h_active+VGA_CTRL_WIDTH);
localparam      h_total = (h_backporch+16);

localparam      v_frontporch = 2;
localparam      v_active = (v_frontporch+33);
localparam      v_backporch = (v_active+VGA_CTRL_HIGH);
localparam      v_total = (v_backporch+10);

reg [VGA_RGB_BIT_WIDTH-1:0] fram_buffer[0:VGA_CTRL_HIGH-1][0:VGA_CTRL_WIDTH-1];
reg [VGA_COUNTER_BIT_WIDTH-1:0] h_counter;
reg [VGA_COUNTER_BIT_WIDTH-1:0] v_counter;
reg vga_output;

wire hs_valid = (!vga_output) || (h_counter>=h_frontporch && h_counter<=h_total);
wire vs_valid = (!vga_output) || (v_counter>=v_frontporch && v_counter<=v_total);
wire h_rgb_valid = (h_counter>=h_active && h_counter<=h_backporch);
wire v_rgb_valid = (v_counter>=v_active && v_counter<=v_backporch);

assign vga_hsync = hs_valid;
assign vga_vsync = vs_valid;
assign vga_valid = vga_output;
// TODO 临时填写的值
assign in_pready = 1;
assign in_prdata = 32'hff0000;
assign in_pslverr = 0;

assign {vga_r,vga_g,vga_b} = (vga_output && h_rgb_valid && v_rgb_valid) ? fram_buffer[(v_counter-v_frontporch)%VGA_CTRL_HIGH][(h_counter-h_frontporch)%VGA_CTRL_WIDTH] : 0;

initial begin
    for (integer h=0; h<VGA_CTRL_HIGH; ++h) begin
        for (integer w=0; w<VGA_CTRL_WIDTH; ++w) begin
            fram_buffer[h][w] = 24'hff0000;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
    end else begin
        // if (vga_ctrl_value == 0) begin
        //     vga_ctrl_value <= dpi_vdev_read(32'h22000000, 4);
        // end else begin
        // end
    end
end

always @(posedge clk or posedge rst)
    if (rst) h_counter <= 0;
    else if (vga_output && h_counter < h_total) h_counter <= h_counter + 1;
    else h_counter <= 0;

always @(posedge clk or posedge rst)
    if (rst) v_counter <= 0;
    else if (vga_output && v_counter == v_total) v_counter <= 0;
    else if (vga_output && h_counter < h_total) v_counter <= v_counter;
    else if (vga_output && h_counter == h_total) v_counter <= v_counter + 1;
    else v_counter <= 0;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        vga_output <= 0;
    end else begin
        vga_output <= 1;
    end
end

endmodule