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

    input  [9:0]            h_addr,
    input  [9:0]            v_addr,
    output [23:0]           vga_rgb
);

localparam      VGA_CTRL_WIDTH = 640;
localparam      VGA_CTRL_HIGH = 480;
localparam      VGA_RGB_BIT_WIDTH = 32; // 模拟效率更高

reg [VGA_RGB_BIT_WIDTH-1:0] fram_buffer[0:VGA_CTRL_HIGH-1][0:VGA_CTRL_WIDTH-1];
wire [9:0] x_cnt = h_addr;
wire [9:0] y_cnt = v_addr;

assign vga_rgb = (x_cnt<VGA_CTRL_WIDTH && y_cnt<VGA_CTRL_HIGH) ? fram_buffer[y_cnt%VGA_CTRL_HIGH][x_cnt%VGA_CTRL_WIDTH][23:0] : 0;

initial begin
    for (integer y=0; y<VGA_CTRL_HIGH; ++y) begin
        for (integer x=0; x<VGA_CTRL_WIDTH; ++x) begin
            if (x>=VGA_CTRL_WIDTH/2) begin
                if (y>=VGA_CTRL_HIGH/2)
                    fram_buffer[y][x] = 32'h00ff55;
                else
                    fram_buffer[y][x] = 32'h550055;
            end else begin
                if (y>=VGA_CTRL_HIGH/2)
                    fram_buffer[y][x] = 32'hffff00;
                else
                    fram_buffer[y][x] = 32'hff0102;
            end
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

endmodule