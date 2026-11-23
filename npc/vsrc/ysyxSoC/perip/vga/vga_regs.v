module vga_regs (
    input                   clock,
    input                   reset,
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
    output [23:0]           vga_rgb,
    output                  fb_sync_valid_o,
    input                   fb_sync_ready
);

localparam      VGA_CTRL_WIDTH = 640;
localparam      VGA_CTRL_HIGH = 480;
localparam      VGA_RGB_BIT_WIDTH = 32; // 模拟效率更高

reg r_pready;
reg [31:0] r_prdata;
reg r_pslverr;
wire read_enable = in_psel && in_penable && !in_pwrite;
wire write_enable = in_psel && in_penable && in_pwrite;
reg [VGA_RGB_BIT_WIDTH-1:0] fram_buffer[0:VGA_CTRL_HIGH-1][0:VGA_CTRL_WIDTH-1];
reg [31:0] ctrl_regs[1:0] /* verilator public_flat_rd */;
wire vga_ctrl_sync = ctrl_regs[1][0];
wire [9:0] x_cnt = h_addr;
wire [9:0] y_cnt = v_addr;

assign in_pready = r_pready;
assign in_prdata = r_prdata;
assign in_pslverr = r_pslverr;
assign vga_rgb = (x_cnt<VGA_CTRL_WIDTH && y_cnt<VGA_CTRL_HIGH) ? fram_buffer[y_cnt%VGA_CTRL_HIGH][x_cnt%VGA_CTRL_WIDTH][23:0] : 0;
assign fb_sync_valid_o = vga_ctrl_sync;

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
    ctrl_regs[0] = 0;
    ctrl_regs[1] = 0;
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        r_pready <= 0;
        r_prdata <= 0;
        r_pslverr <= 0;
    end else begin
        if (write_enable) begin
            $error("vga regs only support DMA write %x", in_paddr);
        end else begin
            r_prdata <= 0;
            r_pready <= 0;
            r_pslverr <= 0;
        end
    end
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
    end else begin
        if (vga_ctrl_sync) begin
            if (vga_ctrl_sync && fb_sync_ready) begin
                ctrl_regs[1][0] <= 0;
                // $display("====== update fb");
            end
        end
    end
end

endmodule