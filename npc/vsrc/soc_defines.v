`ifndef __SOC_DEFINES_V__
`define __SOC_DEFINES_V__

import "DPI-C" function void exit_simu(input int code);
import "DPI-C" function void invalid_inst(input int pc, input int inst);
import "DPI-C" function void dpi_cpu_stat_ctrl(input int dtype, input int delta);
import "DPI-C" function void dpi_add_monitor_item(input int mid, input int pc, input int arg);
import "DPI-C" function int fetch_inst(input int addr);
import "DPI-C" function void write_raw_mem(input int addr, input int len, input int inst);
import "DPI-C" function int read_raw_mem(input int addr, input int len);
import "DPI-C" function void dpi_uart_write(input int addr, input int len, input int inst);
import "DPI-C" function int dpi_rtc_read(input int addr, input int len);
import "DPI-C" function void dpi_dev_skip(input int write, input int addr, input int req_info, input int data);
import "DPI-C" function int dpi_test_intf(input int write, input int addr, input int len, input int data);
import "DPI-C" function void dpi_psram_write(input int addr, input int len, input int data);
import "DPI-C" function int dpi_psram_read(input int addr, input int len);
import "DPI-C" function int dpi_vdev_read(input int addr, input int len);
import "DPI-C" function void dpi_vdev_write(input int addr, input int data, input int len);
import "DPI-C" function int get_reset_pc();
import "DPI-C" function int sext(input int x, input int len);
import "DPI-C" function int dpi_check_dev_addr(input int addr, input int attr);

`include "generated/autoconf.vh"

`define SDRAM_DATA_BITS     32
`define SDRAM_DATA_MASK_BITS (`SDRAM_DATA_BITS/8)
`define SDRAM_BLK_BITS      1
`define SDRAM_BLK_NUM      (1<<`SDRAM_BLK_BITS)

`endif
