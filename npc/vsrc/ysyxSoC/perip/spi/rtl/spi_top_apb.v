// define this macro to enable fast behavior simulation
// for flash by skipping SPI transfers
// `define FAST_FLASH

module spi_top_apb #(
  parameter flash_addr_start = 32'h30000000,
  parameter flash_addr_end   = 32'h3fffffff,
  parameter spi_ss_num       = 8
) (
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

  output                  spi_sck,
  output [spi_ss_num-1:0] spi_ss,
  output                  spi_mosi,
  input                   spi_miso,
  output                  spi_irq_out
);

`ifdef FAST_FLASH

wire [31:0] data;
parameter invalid_cmd = 8'h0;
flash_cmd flash_cmd_i(
  .clock(clock),
  .valid(in_psel && !in_penable),
  .cmd(in_pwrite ? invalid_cmd : 8'h03),
  .addr({8'b0, in_paddr[23:2], 2'b0}),
  .data(data)
);
assign spi_sck    = 1'b0;
assign spi_ss     = 8'b0;
assign spi_mosi   = 1'b1;
assign spi_irq_out= 1'b0;
assign in_pslverr = 1'b0;
assign in_pready  = in_penable && in_psel && !in_pwrite;
assign in_prdata  = data[31:0];

`else

wire is_xip = (in_psel&&in_paddr>=32'h3000_0000 && in_paddr<=32'h3fff_ffff)?1:0;
reg [4:0] xip_in_paddr;
reg [31:0] xip_in_pwdata;
reg [31:0] xip_in_prdata;
reg [3:0] xip_in_pstrb;
reg xip_in_pwrite;
reg xip_in_psel;
reg xip_in_penable;
reg xip_in_pready;

reg [31:0] u0_in_prdata;
reg u0_in_pready;
spi_top u0_spi_top (
  .wb_clk_i(clock),
  .wb_rst_i(reset),
  .wb_adr_i( is_xip ? xip_in_paddr : in_paddr[4:0] ),
  .wb_dat_i( is_xip ? xip_in_pwdata : in_pwdata ),
  .wb_dat_o( u0_in_prdata ),
  .wb_sel_i( is_xip ? xip_in_pstrb : in_pstrb ),
  .wb_we_i ( is_xip ? xip_in_pwrite : in_pwrite ),
  .wb_stb_i( is_xip ? xip_in_psel : in_psel ),
  .wb_cyc_i( is_xip ? xip_in_penable : in_penable ),
  .wb_ack_o(u0_in_pready),
  .wb_err_o(in_pslverr),
  .wb_int_o(spi_irq_out),

  .ss_pad_o(spi_ss),
  .sclk_pad_o(spi_sck),
  .mosi_pad_o(spi_mosi),
  .miso_pad_i(spi_miso)
);

assign in_pready = is_xip ? xip_in_pready : u0_in_pready;
assign in_prdata = is_xip ? xip_in_prdata : u0_in_prdata;

typedef enum[3:0] {
    XIP_IDLE,
    XIP_INIT_DIVIDER,
    XIP_INIT_SS,
    XIP_INIT_TX0,
    XIP_INIT_TX1,
    XIP_INIT_CTRL,
    XIP_WAIT_TRANSFER,
    XIP_READ_DATA,
    XIP_READ_DONE
} xip_state_t;
reg [3:0] xip_state;

always @(posedge clock) begin
    if (reset) begin
        xip_state <= XIP_IDLE;
    end else begin
        if (is_xip) begin
            case (xip_state)
                XIP_IDLE: begin
                    xip_in_psel <= 1;
                    xip_in_penable <= 0;
                    xip_state <= XIP_INIT_DIVIDER;
                    if (in_paddr[1:0]>0) $error("Only support align addr access to flash %x", in_paddr);
                end

                XIP_INIT_DIVIDER: begin
                    if (!xip_in_penable) begin
                        xip_in_paddr <= 5'h14;
                        xip_in_pwdata <= 0;
                        xip_in_pstrb <= 4'h3;
                        xip_in_pwrite <= 1;
                        xip_in_penable <= 1;
                    end
                    if (u0_in_pready && xip_in_penable) begin
                        xip_in_penable <= 0;
                        xip_state <= XIP_INIT_SS;
                    end
                end

                XIP_INIT_SS: begin
                    if (!xip_in_penable) begin
                        xip_in_paddr <= 5'h18;
                        xip_in_pwdata <= 32'h1;
                        xip_in_pstrb <= 4'hf;
                        xip_in_pwrite <= 1;
                        xip_in_penable <= 1;
                    end
                    if (u0_in_pready && xip_in_penable) begin
                        xip_in_penable <= 0;
                        xip_state <= XIP_INIT_TX0;
                    end
                end

                XIP_INIT_TX0: begin
                    if (!xip_in_penable) begin
                        xip_in_paddr <= 5'h00;
                        xip_in_pwdata <= 32'h0;
                        xip_in_pstrb <= 4'hf;
                        xip_in_pwrite <= 1;
                        xip_in_penable <= 1;
                    end
                    if (u0_in_pready && xip_in_penable) begin
                        xip_in_penable <= 0;
                        xip_state <= XIP_INIT_TX1;
                    end
                end

                XIP_INIT_TX1: begin
                    if (!xip_in_penable) begin
                        xip_in_paddr <= 5'h04;
                        xip_in_pwdata <= {8'h03, in_paddr[23:2], 2'h0};
                        xip_in_pstrb <= 4'hf;
                        xip_in_pwrite <= 1;
                        xip_in_penable <= 1;
                    end
                    if (u0_in_pready && xip_in_penable) begin
                        xip_in_penable <= 0;
                        xip_state <= XIP_INIT_CTRL;
                    end
                end
                
                XIP_INIT_CTRL: begin
                    if (!xip_in_penable) begin
                        xip_in_paddr <= 5'h10;
                        xip_in_pwdata <= 32'h2540;
                        xip_in_pstrb <= 4'hf;
                        xip_in_pwrite <= 1;
                        xip_in_penable <= 1;
                    end
                    if (u0_in_pready && xip_in_penable) begin
                        xip_in_penable <= 0;
                        xip_state <= XIP_WAIT_TRANSFER;
                    end
                end

                XIP_WAIT_TRANSFER: begin
                    if (!xip_in_penable) begin
                        xip_in_paddr <= 5'h10;
                        xip_in_pwdata <= 32'h0;
                        xip_in_pstrb <= 4'hf;
                        xip_in_pwrite <= 0;
                        xip_in_penable <= 1;
                    end
                    if (u0_in_pready && xip_in_penable) begin
                        xip_in_penable <= 0;
                        if (!u0_in_prdata[8]) xip_state <= XIP_READ_DATA;
                    end
                end
                
                XIP_READ_DATA: begin
                    if (!xip_in_penable) begin
                        xip_in_paddr <= 5'h0;
                        xip_in_pwdata <= 32'h0;
                        xip_in_pstrb <= in_pstrb;
                        xip_in_pwrite <= 0;
                        xip_in_penable <= 1;
                    end
                    if (u0_in_pready && xip_in_penable) begin
                        // 0x30313233
                        xip_in_prdata <= {u0_in_prdata[7:0], u0_in_prdata[15:8], u0_in_prdata[23:16], u0_in_prdata[31:24]};
                        // xip_in_prdata <= u0_in_prdata;
                        xip_in_pready <= 1;

                        xip_in_penable <= 0;
                        xip_state <= XIP_READ_DONE;
                        xip_in_psel <= 0;
                    end
                end

                XIP_READ_DONE: begin
                    xip_state <= XIP_IDLE;
                    xip_in_pready <= 0;
                end

                default: $error("Found unknown state %d", xip_state);
            endcase
        end else begin
            xip_in_psel <= 0;
            xip_in_penable <= 0;
            xip_state <= XIP_IDLE;
            xip_in_pready <= 0;
        end
    end
end

`endif // FAST_FLASH

endmodule
