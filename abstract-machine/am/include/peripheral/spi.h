#ifndef __SPI_H__
#define __SPI_H__

#include <stdint.h>

// ref. git@gitee.com:uu90909/ysyxSoC.git ysyxSoC/perip/spi/doc/spi.pdf

#define SPI_BASEADDR    (0x10001000)
#define SPI_RX0         (SPI_BASEADDR+0x0)
#define SPI_RX1         (SPI_BASEADDR+0x4)
#define SPI_RX2         (SPI_BASEADDR+0x8)
#define SPI_RX3         (SPI_BASEADDR+0xc)
#define SPI_TX0         (SPI_BASEADDR+0x0)
#define SPI_TX1         (SPI_BASEADDR+0x4)
#define SPI_TX2         (SPI_BASEADDR+0x8)
#define SPI_TX3         (SPI_BASEADDR+0xc)
#define SPI_CTRL        (SPI_BASEADDR+0x10)
#define SPI_DIVIDER     (SPI_BASEADDR+0x14)
#define SPI_SS          (SPI_BASEADDR+0x18)

#define SPI_SLAVE_FLASH                (1<<0)
#define SPI_SLAVE_BITREV               (1<<7)

typedef union {
    struct {
        uint32_t char_len:7;    // 单次传输数据量，例如：接收8字节+发送8字节，值为16
        uint32_t reserved0:1;
        uint32_t go_bsy:1;      // write 1 to start util transfer is done
        uint32_t rx_neg:1;      // slave是否在下降沿接收数据，与tx_neg相反
        uint32_t tx_neg:1;      // master是否在下降沿发送数据，与rx_neg相反
        uint32_t lsb:1;         // 是否先发送LSB
        uint32_t ie:1;          // 中断使能
        uint32_t ass:1;         // 自动使能ss信号，flash -- bit0 bitrev -- bit7
        uint32_t reserved1:18;
    };
    uint32_t raw_data;
} spi_ctrl_t;

typedef union {
    struct {
        uint32_t ss:8;
        uint32_t reserved0:24;
    };
    uint32_t raw_data;
} spi_ss_t;

typedef union {
    struct {
        uint32_t divider:16;    // 仿真都支持，选用最高评率的除数；fsclk=fclk/((DIVIDER+1)*2)
        uint32_t reserved0:16;
    };
    uint32_t raw_data;
} spi_divider_t;

typedef struct {
    union {
        uint32_t rx[4];
        uint32_t tx[4];
    };
    spi_ctrl_t ctrl;
    spi_divider_t divider;
    spi_ss_t ss;
} spi_dev_t;

static volatile spi_dev_t *spi_dev=(volatile spi_dev_t *)SPI_BASEADDR;

#endif
