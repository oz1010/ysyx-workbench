`timescale 1ns/1ps
`include "generated/autoconf.vh"

module iv_memsys #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter SRAM_LATENCY = 0,
    parameter MROM_LATENCY = 1,
    parameter FLASH_LATENCY = 4,
    parameter PSRAM_LATENCY = 2,
    parameter SDRAM_LATENCY = 4,
    parameter [ADDR_WIDTH-1:0] IMAGE_BASE = `CONFIG_IMG_LOAD
) (
    input  wire                     clock,
    input  wire                     reset,

    output wire                     io_master_awready,
    input  wire                     io_master_awvalid,
    input  wire [ADDR_WIDTH-1:0]    io_master_awaddr,
    input  wire [3:0]               io_master_awid,
    input  wire [7:0]               io_master_awlen,
    input  wire [2:0]               io_master_awsize,
    input  wire [1:0]               io_master_awburst,
    output wire                     io_master_wready,
    input  wire                     io_master_wvalid,
    input  wire [DATA_WIDTH-1:0]    io_master_wdata,
    input  wire [DATA_WIDTH/8-1:0]  io_master_wstrb,
    input  wire                     io_master_wlast,
    input  wire                     io_master_bready,
    output reg                      io_master_bvalid,
    output reg  [1:0]               io_master_bresp,
    output reg  [3:0]               io_master_bid,
    output wire                     io_master_arready,
    input  wire                     io_master_arvalid,
    input  wire [ADDR_WIDTH-1:0]    io_master_araddr,
    input  wire [3:0]               io_master_arid,
    input  wire [7:0]               io_master_arlen,
    input  wire [2:0]               io_master_arsize,
    input  wire [1:0]               io_master_arburst,
    input  wire                     io_master_rready,
    output wire                     io_master_rvalid,
    output reg  [1:0]               io_master_rresp,
    output reg  [DATA_WIDTH-1:0]    io_master_rdata,
    output reg                      io_master_rlast,
    output reg  [3:0]               io_master_rid,

    input  wire [31:0]              core_pc,
    input  wire [31:0]              core_inst_pc,
    input  wire                     core_inst_done
);

    localparam [3:0] REGION_NONE  = 0;
    localparam [3:0] REGION_SRAM  = 1;
    localparam [3:0] REGION_MROM  = 2;
    localparam [3:0] REGION_FLASH = 3;
    localparam [3:0] REGION_PSRAM = 4;
    localparam [3:0] REGION_SDRAM = 5;
    localparam [3:0] REGION_UART     = 6;
    localparam [3:0] REGION_PS2      = 7;
    localparam [3:0] REGION_CLINT    = 8;
    localparam [3:0] REGION_VGA_CTRL = 9;
    localparam [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam [1:0] AXI_RESP_SLVERR = 2'b10;
    localparam [1:0] AXI_RESP_DECERR = 2'b11;
    localparam [1:0] READ_IDLE = 0;
    localparam [1:0] READ_WAIT = 1;
    localparam [1:0] READ_DATA = 2;
    localparam [1:0] WRITE_IDLE = 0;
    localparam [1:0] WRITE_DATA = 1;
    localparam [1:0] WRITE_RESP = 2;
    localparam [7:0] MEM_INIT_VALUE = `CONFIG_MEM_INIT_VALUE;

`ifdef CONFIG_HAS_UART
    reg [7:0] uart_dll;
    reg [7:0] uart_dlm;
    reg [3:0] uart_ier;
    reg [7:0] uart_lcr;
    reg [4:0] uart_mcr;
    reg [7:0] uart_scratch;
    reg [7:0] uart_rx_data;
    reg uart_rx_ready;
    string uart_rx_path;
    integer uart_rx_fd;
    integer uart_rx_next;

    task automatic uart_rx_load_next;
        begin
            uart_rx_ready = 1'b0;
            if (uart_rx_fd != 0) begin
                uart_rx_next = $fgetc(uart_rx_fd);
                if (uart_rx_next < 0) begin
                    $fclose(uart_rx_fd);
                    uart_rx_fd = 0;
                end else begin
                    uart_rx_data = uart_rx_next[7:0];
                    uart_rx_ready = 1'b1;
                end
            end
        end
    endtask

    function automatic [7:0] uart_read_byte;
        input [2:0] offset;
        begin
            case (offset)
                0: uart_read_byte = uart_lcr[7] ? uart_dll : uart_rx_data;
                1: uart_read_byte = uart_lcr[7] ? uart_dlm : {4'b0, uart_ier};
                2: uart_read_byte = 8'hc1;
                3: uart_read_byte = uart_lcr;
                4: uart_read_byte = {3'b0, uart_mcr};
                5: uart_read_byte = {1'b0, 2'b11, 4'b0, uart_rx_ready};
                6: uart_read_byte = 0;
                7: uart_read_byte = uart_scratch;
            endcase
        end
    endfunction

    task automatic uart_write_byte;
        input [2:0] offset;
        input [7:0] data;
        begin
            case (offset)
                0: begin
                    if (uart_lcr[7])
                        uart_dll = data;
                    else if (uart_mcr[4]) begin
                        uart_rx_data = data;
                        uart_rx_ready = 1'b1;
                    end else begin
                        $write("%c", data);
                        $fflush();
                    end
                end
                1: begin
                    if (uart_lcr[7])
                        uart_dlm = data;
                    else
                        uart_ier = data[3:0];
                end
                2: begin
                    if (data[1])
                        uart_rx_load_next();
                end
                3: uart_lcr = data;
                4: uart_mcr = data[4:0];
                7: uart_scratch = data;
                default: begin end
            endcase
        end
    endtask

    task automatic uart_read_commit;
        input [ADDR_WIDTH-1:0] addr;
        begin
            if (addr == `CONFIG_UART_BASE_ADDR && !uart_lcr[7])
                uart_rx_load_next();
        end
    endtask

    initial begin
        uart_rx_data = 0;
        uart_rx_ready = 1'b0;
        uart_rx_fd = 0;
        if ($value$plusargs("UART_RX=%s", uart_rx_path)) begin
            uart_rx_fd = $fopen(uart_rx_path, "rb");
            if (uart_rx_fd == 0)
                $fatal(1, "iv_memsys: cannot open UART RX file %s", uart_rx_path);
        end
        uart_rx_load_next();
    end
`endif

`ifdef CONFIG_HAS_PS2
`ifdef VERILATOR
    import "DPI-C" function int iv_ps2_input();
`endif
    reg [7:0] ps2_rx_data;
    string ps2_rx_path;
    integer ps2_rx_fd;
    integer ps2_rx_next;
    integer ps2_use_host;

    task automatic ps2_rx_load_next;
        begin
            ps2_rx_data = 0;
            if (ps2_rx_fd != 0) begin
                ps2_rx_next = $fgetc(ps2_rx_fd);
                if (ps2_rx_next < 0) begin
                    $fclose(ps2_rx_fd);
                    ps2_rx_fd = 0;
                end else begin
                    ps2_rx_data = ps2_rx_next[7:0];
                end
            end else if (ps2_use_host != 0) begin
`ifdef IV_NO_HOST_PS2
                ps2_rx_next = -1;
`elsif VERILATOR
                ps2_rx_next = iv_ps2_input();
`else
                ps2_rx_next = $iv_ps2_input();
`endif
                ps2_rx_data = ps2_rx_next[7:0];
            end
        end
    endtask

    function automatic [7:0] ps2_read_byte;
        input [2:0] offset;
        begin
            ps2_read_byte = offset == 0 ? ps2_rx_data : 0;
        end
    endfunction

    task automatic ps2_read_commit;
        input [ADDR_WIDTH-1:0] addr;
        begin
            if (addr == `CONFIG_PS2_BASE_ADDR)
                ps2_rx_load_next();
        end
    endtask

    initial begin
        ps2_rx_data = 0;
        ps2_rx_fd = 0;
        ps2_use_host = 1;
        if ($value$plusargs("PS2_RX=%s", ps2_rx_path)) begin
            ps2_use_host = 0;
            ps2_rx_fd = $fopen(ps2_rx_path, "rb");
            if (ps2_rx_fd == 0)
                $fatal(1, "iv_memsys: cannot open PS2 RX file %s", ps2_rx_path);
        end
        ps2_rx_load_next();
    end
`endif

    reg [31:0] core_inst_stuck_tick;
    reg core_error /*verilator public_flat_rw*/;
    always @(posedge clock) begin
        if (reset) begin
            core_error <= 0;
            core_inst_stuck_tick <= 0;
        end else begin
            core_inst_stuck_tick <= (core_inst_done && core_pc!=core_inst_pc ) ? 0 : core_inst_stuck_tick + 1;
            if (core_inst_stuck_tick == 5000) begin
                $display("Maybe core is in forever-loop, pc:0x%x ticks:%-d", core_pc, core_inst_stuck_tick);
                core_error <= 1;
                $finish;
            end
        end
    end

    // 硬件滴答值
    reg [63:0] hw_ticks;
    always @(posedge clock) begin
        if (reset)
            hw_ticks <= 0;
        else
            hw_ticks <= hw_ticks + 1;
    end
`ifdef CONFIG_CORE_FREQUENCY
    wire [63:0] local_rtc_us = hw_ticks / (`CONFIG_CORE_FREQUENCY / 1000000);  // us
`endif

`ifdef CONFIG_SRAM
    reg [7:0] sram_mem [0:`CONFIG_SRAM_SIZE-1];
`endif
`ifdef CONFIG_MROM
    reg [7:0] mrom_mem [0:`CONFIG_MROM_SIZE-1];
`endif
`ifdef CONFIG_FLASH
    reg [7:0] flash_mem [0:`CONFIG_FLASH_SIZE-1];
`endif
`ifdef CONFIG_PSRAM
    reg [7:0] psram_mem [0:`CONFIG_PSRAM_SIZE-1];
`endif
`ifdef CONFIG_SDRAM
    reg [7:0] sdram_mem [0:`CONFIG_SDRAM_SIZE-1];
`endif
`ifdef CONFIG_HAS_NVBOARD_VGA
    reg [31:0] vga_ctrl_mem [0:1023];
    integer vga_ctrl_index;
    initial begin
        for (vga_ctrl_index = 0; vga_ctrl_index < 1024; vga_ctrl_index = vga_ctrl_index + 1)
            vga_ctrl_mem[vga_ctrl_index] = 0;
        vga_ctrl_mem[0] = {16'd640, 16'd480};
    end
`endif

    function automatic [3:0] address_region;
        input [ADDR_WIDTH-1:0] addr;
        begin
            address_region = REGION_NONE;
`ifdef CONFIG_SRAM
            if (addr >= `CONFIG_SRAM_BASE && (addr - `CONFIG_SRAM_BASE) < `CONFIG_SRAM_SIZE)
                address_region = REGION_SRAM;
`endif
`ifdef CONFIG_MROM
            if (addr >= `CONFIG_MROM_BASE && (addr - `CONFIG_MROM_BASE) < `CONFIG_MROM_SIZE)
                address_region = REGION_MROM;
`endif
`ifdef CONFIG_FLASH
            if (addr >= `CONFIG_FLASH_BASE && (addr - `CONFIG_FLASH_BASE) < `CONFIG_FLASH_SIZE)
                address_region = REGION_FLASH;
`endif
`ifdef CONFIG_PSRAM
            if (addr >= `CONFIG_PSRAM_BASE && (addr - `CONFIG_PSRAM_BASE) < `CONFIG_PSRAM_SIZE)
                address_region = REGION_PSRAM;
`endif
`ifdef CONFIG_SDRAM
            if (addr >= `CONFIG_SDRAM_BASE && (addr - `CONFIG_SDRAM_BASE) < `CONFIG_SDRAM_SIZE)
                address_region = REGION_SDRAM;
`endif
`ifdef CONFIG_HAS_UART
            if (addr >= `CONFIG_UART_BASE_ADDR && (addr - `CONFIG_UART_BASE_ADDR) < 8)
                address_region = REGION_UART;
`endif
`ifdef CONFIG_HAS_PS2
            if (addr >= `CONFIG_PS2_BASE_ADDR && (addr - `CONFIG_PS2_BASE_ADDR) < 8)
                address_region = REGION_PS2;
`endif
`ifdef CONFIG_HAS_CLINT
            if (addr >= `CONFIG_CLINT_BASE_ADDR && (addr - `CONFIG_CLINT_BASE_ADDR) < 32'h00010000)
                address_region = REGION_CLINT;
`endif
`ifdef CONFIG_HAS_NVBOARD_VGA
            if (addr >= `CONFIG_NVBOARD_VGA_CTRL_BASE_ADDR &&
                (addr - `CONFIG_NVBOARD_VGA_CTRL_BASE_ADDR) < 32'h00001000)
                address_region = REGION_VGA_CTRL;
`endif
        end
    endfunction

    function automatic integer access_latency;
        input [3:0] region;
        begin
            case (region)
                REGION_SRAM:  access_latency = SRAM_LATENCY;
                REGION_MROM:  access_latency = MROM_LATENCY;
                REGION_FLASH: access_latency = FLASH_LATENCY;
                REGION_PSRAM: access_latency = PSRAM_LATENCY;
                REGION_SDRAM: access_latency = SDRAM_LATENCY;
                default:      access_latency = 0;
            endcase
        end
    endfunction

    function automatic [1:0] read_response;
        input [ADDR_WIDTH-1:0] addr;
        begin
            read_response = address_region(addr) == REGION_NONE ? AXI_RESP_DECERR : AXI_RESP_OKAY;
        end
    endfunction

    function automatic [1:0] write_response;
        input [ADDR_WIDTH-1:0] addr;
        begin
            case (address_region(addr))
                REGION_MROM, REGION_FLASH: write_response = AXI_RESP_SLVERR;
                REGION_NONE:               write_response = AXI_RESP_DECERR;
                default:                   write_response = AXI_RESP_OKAY;
            endcase
        end
    endfunction

    function automatic [ADDR_WIDTH-1:0] next_beat_addr;
        input [ADDR_WIDTH-1:0] addr;
        input [2:0] size;
        input [1:0] burst;
        input [7:0] len;
        reg [31:0] beat_bytes;
        reg [31:0] total_bytes;
        reg [31:0] wrap_base;
        begin
            beat_bytes = 32'h1 << size;
            total_bytes = beat_bytes * (len + 1);
            case (burst)
                2'b00: next_beat_addr = addr;
                2'b10: begin
                    wrap_base = (addr / total_bytes) * total_bytes;
                    if (addr + beat_bytes >= wrap_base + total_bytes)
                        next_beat_addr = wrap_base;
                    else
                        next_beat_addr = addr + beat_bytes;
                end
                default: next_beat_addr = addr + beat_bytes;
            endcase
        end
    endfunction

    function automatic [7:0] read_byte;
        input [ADDR_WIDTH-1:0] addr;
        reg [3:0] region;
        reg [7:0] data;
        begin
            region = address_region(addr);
            data = MEM_INIT_VALUE;
            case (region)
`ifdef CONFIG_SRAM
                REGION_SRAM: data = sram_mem[addr - `CONFIG_SRAM_BASE];
`endif
`ifdef CONFIG_MROM
                REGION_MROM: data = mrom_mem[addr - `CONFIG_MROM_BASE];
`endif
`ifdef CONFIG_FLASH
                REGION_FLASH: data = flash_mem[addr - `CONFIG_FLASH_BASE];
`endif
`ifdef CONFIG_PSRAM
                REGION_PSRAM: data = psram_mem[addr - `CONFIG_PSRAM_BASE];
`endif
`ifdef CONFIG_SDRAM
                REGION_SDRAM: data = sdram_mem[addr - `CONFIG_SDRAM_BASE];
`endif
`ifdef CONFIG_HAS_UART
                REGION_UART: data = uart_read_byte(addr[2:0]);
`endif
`ifdef CONFIG_HAS_PS2
                REGION_PS2: data = ps2_read_byte(addr[2:0]);
`endif
`ifdef CONFIG_HAS_NVBOARD_VGA
                REGION_VGA_CTRL:
                    data = vga_ctrl_mem[(addr - `CONFIG_NVBOARD_VGA_CTRL_BASE_ADDR) >> 2][addr[1:0]*8 +: 8];
`endif
                default: begin
                    $display("iv_memsys: read from unmapped address 0x%08x at 0x%08x, returning DECERR", addr, core_pc);
                    data = MEM_INIT_VALUE;
                end
            endcase
            if (^data === 1'bx)
                data = MEM_INIT_VALUE;
            read_byte = data;
        end
    endfunction

`ifdef CONFIG_HAS_CLINT
    function automatic [63:0] rtc_info_from_us;
        input [63:0] us;
        reg [63:0] seconds;
        reg [63:0] days;
        reg [63:0] z;
        reg [63:0] era;
        reg [63:0] doe;
        reg [63:0] yoe;
        reg [63:0] year;
        reg [63:0] doy;
        reg [63:0] mp;
        reg [63:0] month;
        reg [63:0] day;
        begin
            seconds = us / 1000000;
            days = seconds / 86400;
            z = days + 719468;
            era = z / 146097;
            doe = z - era * 146097;
            yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
            year = yoe + era * 400;
            doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
            mp = (5 * doy + 2) / 153;
            day = doy - (153 * mp + 2) / 5 + 1;
            month = mp < 10 ? mp + 3 : mp - 9;
            year = year + (month <= 2);

            rtc_info_from_us = 0;
            rtc_info_from_us[11:0] = year[11:0];
            rtc_info_from_us[15:12] = month[3:0];
            rtc_info_from_us[20:16] = day[4:0];
            rtc_info_from_us[25:21] = (seconds / 3600) % 24;
            rtc_info_from_us[31:26] = (seconds / 60) % 60;
            rtc_info_from_us[37:32] = seconds % 60;
        end
    endfunction

    function automatic [DATA_WIDTH-1:0] clint_read_word;
        input [ADDR_WIDTH-1:0] addr;
        reg [63:0] rtc_info;
        begin
            rtc_info = rtc_info_from_us(local_rtc_us);
            case (addr)
                // Get up time
                `CONFIG_CLINT_BASE_ADDR + 32'h48: clint_read_word = local_rtc_us[31:0];
                `CONFIG_CLINT_BASE_ADDR + 32'h4c: clint_read_word = local_rtc_us[63:32];
                // Get linux date
                `CONFIG_CLINT_BASE_ADDR + 32'h50: clint_read_word = rtc_info[31:0];
                `CONFIG_CLINT_BASE_ADDR + 32'h54: clint_read_word = rtc_info[63:32];
                default:                         clint_read_word = 0;
            endcase
        end
    endfunction
`endif

    function automatic [DATA_WIDTH-1:0] read_aligned_word;
        input [ADDR_WIDTH-1:0] addr;
        reg [ADDR_WIDTH-1:0] aligned_addr;
        begin
            aligned_addr = {addr[ADDR_WIDTH-1:2], 2'b00};
`ifdef CONFIG_HAS_CLINT
            if (address_region(aligned_addr) == REGION_CLINT)
                read_aligned_word = clint_read_word(aligned_addr);
            else
`endif
                read_aligned_word = {
                    read_byte(aligned_addr + 3),
                    read_byte(aligned_addr + 2),
                    read_byte(aligned_addr + 1),
                    read_byte(aligned_addr)
                };
        end
    endfunction

    task automatic image_write_byte;
        input [ADDR_WIDTH-1:0] addr;
        input [7:0] data;
        reg [3:0] region;
        begin
            region = address_region(addr);
            case (region)
`ifdef CONFIG_SRAM
                REGION_SRAM: sram_mem[addr - `CONFIG_SRAM_BASE] = data;
`endif
`ifdef CONFIG_MROM
                REGION_MROM: mrom_mem[addr - `CONFIG_MROM_BASE] = data;
`endif
`ifdef CONFIG_FLASH
                REGION_FLASH: flash_mem[addr - `CONFIG_FLASH_BASE] = data;
`endif
`ifdef CONFIG_PSRAM
                REGION_PSRAM: psram_mem[addr - `CONFIG_PSRAM_BASE] = data;
`endif
`ifdef CONFIG_SDRAM
                REGION_SDRAM: sdram_mem[addr - `CONFIG_SDRAM_BASE] = data;
`endif
                default: $error("iv_memsys: image write to unmapped address 0x%08x", addr);
            endcase
        end
    endtask

    task automatic image_write_word;
        input [ADDR_WIDTH-1:0] addr;
        input [31:0] data;
        begin
            image_write_byte(addr, data[7:0]);
            image_write_byte(addr + 1, data[15:8]);
            image_write_byte(addr + 2, data[23:16]);
            image_write_byte(addr + 3, data[31:24]);
        end
    endtask

    task automatic image_copy;
        input [31:0] load_addr;
        input [31:0] start_addr;
        input [31:0] end_addr;
        reg [31:0] src_addr;
        reg [31:0] dst_addr;
        begin
            if (load_addr != start_addr) begin
                src_addr = load_addr;
                for (dst_addr = start_addr; dst_addr < end_addr; dst_addr = dst_addr + 1) begin
                    image_write_byte(dst_addr, read_byte(src_addr));
                    src_addr = src_addr + 1;
                end
            end
        end
    endtask

    task automatic fast_load_image;
        reg [31:0] text_load;
        reg [31:0] text_start;
        reg [31:0] text_end;
        reg [31:0] data_load;
        reg [31:0] data_start;
        reg [31:0] data_end;
        reg [31:0] bss_start;
        reg [31:0] bss_end;
        reg [31:0] bss_addr;
        begin
            text_load = read_aligned_word(IMAGE_BASE + 8);
            text_start = read_aligned_word(IMAGE_BASE + 12);
            text_end = read_aligned_word(IMAGE_BASE + 16);
            data_load = read_aligned_word(IMAGE_BASE + 20);
            data_start = read_aligned_word(IMAGE_BASE + 24);
            data_end = read_aligned_word(IMAGE_BASE + 28);
            bss_start = read_aligned_word(IMAGE_BASE + 32);
            bss_end = read_aligned_word(IMAGE_BASE + 36);
            $display("iv_memsys: Section text [0x%x] => [0x%x, 0x%x)", text_load, text_start, text_end);
            image_copy(text_load, text_start, text_end);
            $display("iv_memsys: Section data [0x%x] => [0x%x, 0x%x)", data_load, data_start, data_end);
            image_copy(data_load, data_start, data_end);
            $display("iv_memsys: Section bss 0 => [0x%x, 0x%x)", bss_start, bss_end);
            for (bss_addr = bss_start; bss_addr < bss_end; bss_addr = bss_addr + 4)
                image_write_word(bss_addr, 0);
        end
    endtask

    task automatic write_byte;
        input [ADDR_WIDTH-1:0] addr;
        input [7:0] data;
        reg [3:0] region;
        begin
            region = address_region(addr);
            case (region)
                REGION_MROM, REGION_FLASH:
                    $display("iv_memsys: write to read-only address 0x%08x, returning SLVERR", addr);
                REGION_NONE:
                    $display("iv_memsys: write to unmapped address 0x%08x, returning DECERR", addr);
`ifdef CONFIG_HAS_UART
                REGION_UART:
                    uart_write_byte(addr[2:0], data);
`endif
`ifdef CONFIG_HAS_PS2
                REGION_PS2: begin end
`endif
`ifdef CONFIG_HAS_NVBOARD_VGA
                REGION_VGA_CTRL:
                    vga_ctrl_mem[(addr - `CONFIG_NVBOARD_VGA_CTRL_BASE_ADDR) >> 2][addr[1:0]*8 +: 8] = data;
`endif
                default: image_write_byte(addr, data);
            endcase
        end
    endtask

    task automatic write_request;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH/8-1:0] strb;
        input [DATA_WIDTH-1:0] data;
        integer index;
        begin
            for (index = 0; index < DATA_WIDTH/8; index = index + 1) begin
                if (strb[index])
                    write_byte(addr + index, data[index*8 +: 8]);
            end
        end
    endtask

    string image_path;
    integer image_fd;
    integer image_size;
    reg [31:0] _bin_flag;
    initial begin
        if ($value$plusargs("IMG=%s", image_path)) begin
            image_fd = $fopen(image_path, "rb");
            if (image_fd == 0)
                $fatal(1, "iv_memsys: cannot open image %s", image_path);
            case (address_region(IMAGE_BASE))
`ifdef CONFIG_SRAM
                REGION_SRAM: image_size = $fread(sram_mem, image_fd);
`endif
`ifdef CONFIG_MROM
                REGION_MROM: image_size = $fread(mrom_mem, image_fd);
`endif
`ifdef CONFIG_FLASH
                REGION_FLASH: image_size = $fread(flash_mem, image_fd);
`endif
`ifdef CONFIG_PSRAM
                REGION_PSRAM: image_size = $fread(psram_mem, image_fd);
`endif
`ifdef CONFIG_SDRAM
                REGION_SDRAM: image_size = $fread(sdram_mem, image_fd);
`endif
                default: $fatal(1, "iv_memsys: image base 0x%08x is unmapped", IMAGE_BASE);
            endcase
            $fclose(image_fd);
            $display("iv_memsys: Loaded %0d bytes from %s at 0x%08x", image_size, image_path,
                     IMAGE_BASE);
            _bin_flag = read_aligned_word(IMAGE_BASE + 4);
            $display("iv_memsys: _bin_flag = 0x%08x", _bin_flag);
            if (_bin_flag[0]) begin
                fast_load_image();
                $display("iv_memsys: fast load done");
            end
        end else begin
            $fatal(1, "iv_memsys: Need to set '+IMG=<path_to_bin>'");
        end
`ifdef CI_STANDALONE
        image_write_word(`CONFIG_FLASH_BASE, 32'h800002b7);
        image_write_word(`CONFIG_FLASH_BASE + 4, 32'h00028067);
`endif
    end

    reg [1:0] read_state;
    reg [ADDR_WIDTH-1:0] read_addr;
    reg [7:0] read_len;
    reg [2:0] read_size;
    reg [1:0] read_burst;
    reg [7:0] read_index;
    integer read_wait;

    assign io_master_arready = !reset && read_state == READ_IDLE;
    assign io_master_rvalid = !reset && read_state == READ_DATA;

    always @(posedge clock) begin
        if (reset) begin
            read_state <= READ_IDLE;
            read_addr <= 0;
            read_len <= 0;
            read_size <= 0;
            read_burst <= 0;
            read_index <= 0;
            read_wait <= 0;
            io_master_rresp <= AXI_RESP_OKAY;
            io_master_rdata <= 0;
            io_master_rlast <= 1'b0;
            io_master_rid <= 0;
        end else begin
            case (read_state)
                READ_IDLE: begin
                    if (io_master_arvalid && io_master_arready) begin
                        read_state <= READ_WAIT;
                        read_addr <= {io_master_araddr[ADDR_WIDTH-1:2], 2'b00};
                        read_len <= io_master_arlen;
                        read_size <= io_master_arsize;
                        read_burst <= io_master_arburst;
                        read_index <= 0;
                        read_wait <= access_latency(address_region(io_master_araddr));
                        io_master_rresp <= read_response(io_master_araddr);
                        io_master_rdata <= read_aligned_word(io_master_araddr);
                        io_master_rlast <= io_master_arlen == 0;
                        io_master_rid <= io_master_arid;
`ifdef CONFIG_HAS_UART
                        uart_read_commit(io_master_araddr);
`endif
`ifdef CONFIG_HAS_PS2
                        ps2_read_commit(io_master_araddr);
`endif
                    end
                end
                READ_WAIT: begin
                    if (read_wait == 0)
                        read_state <= READ_DATA;
                    else
                        read_wait <= read_wait - 1;
                end
                READ_DATA: begin
                    if (io_master_rvalid && io_master_rready) begin
                        if (io_master_rlast) begin
                            read_state <= READ_IDLE;
                            io_master_rlast <= 1'b0;
                            io_master_rid <= 0;
                        end else begin
                            read_state <= READ_WAIT;
                            read_addr <= next_beat_addr(read_addr, read_size, read_burst, read_len);
                            read_index <= read_index + 1;
                            read_wait <= access_latency(address_region(
                                next_beat_addr(read_addr, read_size, read_burst, read_len)));
                            io_master_rresp <= read_response(
                                next_beat_addr(read_addr, read_size, read_burst, read_len));
                            io_master_rdata <= read_aligned_word(
                                next_beat_addr(read_addr, read_size, read_burst, read_len));
                            io_master_rlast <= read_index + 1 == read_len;
`ifdef CONFIG_HAS_UART
                            uart_read_commit(
                                next_beat_addr(read_addr, read_size, read_burst, read_len));
`endif
`ifdef CONFIG_HAS_PS2
                            ps2_read_commit(
                                next_beat_addr(read_addr, read_size, read_burst, read_len));
`endif
                        end
                    end
                end
                default: read_state <= READ_IDLE;
            endcase
        end
    end

    reg [1:0] write_state;
    reg [ADDR_WIDTH-1:0] write_addr;
    reg [3:0] write_id;
    reg [7:0] write_len;
    reg [2:0] write_size;
    reg [1:0] write_burst;
    reg [7:0] write_index;
    integer write_wait;

    assign io_master_awready = !reset && write_state == WRITE_IDLE;
    assign io_master_wready = !reset && write_state == WRITE_DATA && write_wait == 0;

    always @(posedge clock) begin
        if (reset) begin
            write_state <= WRITE_IDLE;
            write_addr <= 0;
            write_id <= 0;
            write_len <= 0;
            write_size <= 0;
            write_burst <= 0;
            write_index <= 0;
            write_wait <= 0;
            io_master_bvalid <= 1'b0;
            io_master_bresp <= AXI_RESP_OKAY;
            io_master_bid <= 0;
`ifdef CONFIG_HAS_UART
            uart_dll <= 0;
            uart_dlm <= 0;
            uart_ier <= 0;
            uart_lcr <= 8'h03;
            uart_mcr <= 0;
            uart_scratch <= 0;
`endif
        end else begin
            case (write_state)
                WRITE_IDLE: begin
                    if (io_master_awvalid && io_master_awready) begin
                        write_state <= WRITE_DATA;
                        write_addr <= {io_master_awaddr[ADDR_WIDTH-1:2], 2'b00};
                        write_id <= io_master_awid;
                        write_len <= io_master_awlen;
                        write_size <= io_master_awsize;
                        write_burst <= io_master_awburst;
                        write_index <= 0;
                        write_wait <= access_latency(address_region(io_master_awaddr));
                        io_master_bresp <= write_response(io_master_awaddr);
                    end
                end
                WRITE_DATA: begin
                    if (write_wait != 0)
                        write_wait <= write_wait - 1;
                    if (io_master_wvalid && io_master_wready) begin
                        write_request(write_addr, io_master_wstrb, io_master_wdata);
                        if (io_master_wlast || write_index == write_len) begin
                            if (io_master_wlast != (write_index == write_len))
                                $error("iv_memsys: WLAST does not match AWLEN at 0x%08x", write_addr);
                            write_state <= WRITE_RESP;
                            io_master_bvalid <= 1'b1;
                            io_master_bid <= write_id;
                        end else begin
                            write_addr <= next_beat_addr(write_addr, write_size, write_burst, write_len);
                            write_index <= write_index + 1;
                            write_wait <= access_latency(address_region(
                                next_beat_addr(write_addr, write_size, write_burst, write_len)));
                            io_master_bresp <= write_response(
                                next_beat_addr(write_addr, write_size, write_burst, write_len));
                        end
                    end
                end
                WRITE_RESP: begin
                    if (io_master_bvalid && io_master_bready) begin
                        write_state <= WRITE_IDLE;
                        io_master_bvalid <= 1'b0;
                        io_master_bid <= 0;
                    end
                end
                default: write_state <= WRITE_IDLE;
            endcase
        end
    end

endmodule
