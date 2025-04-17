## 外设地址分布

我们先给出ysyxSoC包含的外围设备和相应的地址空间.

| 设备          | 地址空间                  |
| ------------- | ------------------------- |
| CLINT         | `0x0200_0000~0x0200_ffff` |
| SRAM          | `0x0f00_0000~0x0fff_ffff` |
| UART16550     | `0x1000_0000~0x1000_0fff` |
| SPI master    | `0x1000_1000~0x1000_1fff` |
| GPIO          | `0x1000_2000~0x1000_200f` |
| PS2           | `0x1001_1000~0x1001_1007` |
| MROM          | `0x2000_0000~0x2000_0fff` |
| VGA           | `0x2100_0000~0x211f_ffff` |
| Flash         | `0x3000_0000~0x3fff_ffff` |
| ChipLink MMIO | `0x4000_0000~0x7fff_ffff` |
| PSRAM         | `0x8000_0000~0x9fff_ffff` |
| SDRAM         | `0xa000_0000~0xbfff_ffff` |
| ChipLink MEM  | `0xc000_0000~0xffff_ffff` |
| Reverse       | 其他                      |
