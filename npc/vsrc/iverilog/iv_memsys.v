`timescale 1ns/1ps
`include "generated/autoconf.vh"

module iv_memsys #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter SRAM_LATENCY = 0,
    parameter MROM_LATENCY = 1,
    parameter FLASH_LATENCY = 4,
    parameter PSRAM_LATENCY = 2,
    parameter SDRAM_LATENCY = 4
) (
    input  wire                  clock,
    input  wire                  reset,

    input  wire                  io_if_req_valid,
    output wire                  io_if_req_ready,
    input  wire [ADDR_WIDTH-1:0] io_if_req_addr,
    input  wire [3:0]            io_if_req_op,
    input  wire [DATA_WIDTH-1:0] io_if_req_wdata,
    output reg                   io_if_rsp_valid,
    input  wire                  io_if_rsp_ready,
    output reg  [DATA_WIDTH-1:0] io_if_rsp_data,

    input  wire                  io_mem_req_valid,
    output wire                  io_mem_req_ready,
    input  wire [ADDR_WIDTH-1:0] io_mem_req_addr,
    input  wire [3:0]            io_mem_req_op,
    input  wire [DATA_WIDTH-1:0] io_mem_req_wdata,
    output reg                   io_mem_rsp_valid,
    input  wire                  io_mem_rsp_ready,
    output reg  [DATA_WIDTH-1:0] io_mem_rsp_data,

    input  wire [31:0]           core_pc,
    input  wire [31:0]           core_inst_pc,
    input  wire                  core_inst_done
);

    localparam [2:0] REGION_NONE  = 0;
    localparam [2:0] REGION_SRAM  = 1;
    localparam [2:0] REGION_MROM  = 2;
    localparam [2:0] REGION_FLASH = 3;
    localparam [2:0] REGION_PSRAM = 4;
    localparam [2:0] REGION_SDRAM = 5;
    localparam [7:0] MEM_INIT_VALUE = `CONFIG_MEM_INIT_VALUE;

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
                // $display("Maybe core%-2d is in forever-loop, pc:0x%x ticks:%-d", i, core_pc[i], core_inst_stuck_tick[i]);
                // $finish;
            end
        end
    end

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

    reg if_busy;
    reg mem_busy;
    integer if_wait;
    integer mem_wait;

    assign io_if_req_ready = !reset && !if_busy;
    assign io_mem_req_ready = !reset && !mem_busy;

    function automatic [2:0] address_region;
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
        end
    endfunction

    function automatic integer access_latency;
        input [2:0] region;
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

    function automatic [7:0] read_byte;
        input [ADDR_WIDTH-1:0] addr;
        reg [2:0] region;
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
                default: begin $error("iv_memsys: read from unmapped address 0x%08x", addr); $finish; end
            endcase
            if (^data === 1'bx)
                data = MEM_INIT_VALUE;
            read_byte = data;
        end
    endfunction

    function automatic [DATA_WIDTH-1:0] read_aligned_word;
        input [ADDR_WIDTH-1:0] addr;
        reg [ADDR_WIDTH-1:0] aligned_addr;
        begin
            aligned_addr = {addr[ADDR_WIDTH-1:2], 2'b00};
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
        reg [2:0] region;
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

    task automatic write_byte;
        input [ADDR_WIDTH-1:0] addr;
        input [7:0] data;
        reg [2:0] region;
        begin
            region = address_region(addr);
            case (region)
                REGION_MROM, REGION_FLASH:
                    $error("iv_memsys: write to read-only address 0x%08x", addr);
                REGION_NONE:
                    $error("iv_memsys: write to unmapped address 0x%08x", addr);
                default: image_write_byte(addr, data);
            endcase
        end
    endtask

    task automatic write_request;
        input [ADDR_WIDTH-1:0] addr;
        input [3:0] op;
        input [DATA_WIDTH-1:0] data;
        integer index;
        begin
            if (op[1:0] == 2'b11) begin
                $error("iv_memsys: unsupported write size at 0x%08x", addr);
            end else begin
                for (index = 0; index < (1 << op[1:0]); index = index + 1)
                    write_byte(addr + index, data[index*8 +: 8]);
            end
        end
    endtask

    string image_path;
    integer image_fd;
    integer image_size;
    initial begin
        if ($value$plusargs("IMG=%s", image_path)) begin
            image_fd = $fopen(image_path, "rb");
            if (image_fd == 0)
                $fatal(1, "iv_memsys: cannot open image %s", image_path);
            case (address_region(`CONFIG_IMG_LOAD))
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
                default: $fatal(1, "iv_memsys: image base 0x%08x is unmapped", `CONFIG_IMG_LOAD);
            endcase
            $fclose(image_fd);
            $display("iv_memsys: loaded %0d bytes from %s at 0x%08x", image_size, image_path,
                     `CONFIG_IMG_LOAD);
        end else begin
            image_write_word(`CONFIG_IMG_LOAD, 32'h0000006f);
        end
    end

    always @(posedge clock) begin
        if (reset) begin
            if_busy <= 1'b0;
            mem_busy <= 1'b0;
            if_wait <= 0;
            mem_wait <= 0;
            io_if_rsp_valid <= 1'b0;
            io_if_rsp_data <= {DATA_WIDTH{1'b0}};
            io_mem_rsp_valid <= 1'b0;
            io_mem_rsp_data <= {DATA_WIDTH{1'b0}};
        end else begin
            if (io_if_rsp_valid && io_if_rsp_ready) begin
                io_if_rsp_valid <= 1'b0;
                if_busy <= 1'b0;
            end else if (if_busy && !io_if_rsp_valid) begin
                if (if_wait == 0)
                    io_if_rsp_valid <= 1'b1;
                else
                    if_wait <= if_wait - 1;
            end

            if (io_mem_rsp_valid && io_mem_rsp_ready) begin
                io_mem_rsp_valid <= 1'b0;
                mem_busy <= 1'b0;
            end else if (mem_busy && !io_mem_rsp_valid) begin
                if (mem_wait == 0)
                    io_mem_rsp_valid <= 1'b1;
                else
                    mem_wait <= mem_wait - 1;
            end

            if (io_if_req_valid && io_if_req_ready) begin
                if_busy <= 1'b1;
                if_wait <= access_latency(address_region(io_if_req_addr));
                if (io_if_req_op[3]) begin
                    io_if_rsp_data <= {DATA_WIDTH{1'b0}};
                    $error("iv_memsys: instruction interface does not accept writes");
                end else begin
                    io_if_rsp_data <= read_aligned_word(io_if_req_addr);
                end
            end

            if (io_mem_req_valid && io_mem_req_ready) begin
                mem_busy <= 1'b1;
                mem_wait <= access_latency(address_region(io_mem_req_addr));
                if (io_mem_req_op[3]) begin
                    write_request(io_mem_req_addr, io_mem_req_op, io_mem_req_wdata);
                    io_mem_rsp_data <= {DATA_WIDTH{1'b0}};
                end else begin
                    io_mem_rsp_data <= read_aligned_word(io_mem_req_addr);
                end
            end
        end
    end

endmodule
