#ifndef __FLASH_H__
#define __FLASH_H__
/**
 * 整个flash颗粒的存储阵列划分成256个块(Block), 每个块的大小是64KB; 
 * 每个块的内部又划分成16个扇区(Sector), 每个扇区的大小是4KB; 
 * 每个扇区的内部又划分成16个页(Page), 每个页的大小是256B.
 * ref. https://evelta.com/content/datasheets/153-W25Q128JVSIQ.pdf
*/

#include <stdint.h>
#include "peripheral/spi.h"
#include "am.h"

// 0x3000_0000~0x3fff_ffff
#define FLASH_BASEADDR              (0x30000000)
#define FLASH_ENDADDR               (0x3fffffff)
#define FLASH_SIZE                  (FLASH_ENDADDR-FLASH_BASEADDR+1)

/**
 * The Read Data instruction allows one or more data bytes to be sequentially read from the memory. The
 * instruction is initiated by driving the /CS pin low and then shifting the instruction code “03h” followed by a
 * 24-bit address (A23-A0) into the DI pin. The code and address bits are latched on the rising edge of the
 * CLK pin. After the address is received, the data byte of the addressed memory location will be shifted out
 * on the DO pin at the falling edge of CLK with most significant bit (MSB) first.
*/
#define FLASH_CMD_READ_DATA         (0x03)

UNUSED_FUNC int flash_init(void)
{
    return spi_init(
        (spi_ctrl_t){
            .char_len = 64,
            .go_bsy = 0,
            .rx_neg = 0,
            .tx_neg = 1,
            .lsb = 0,
            .ie = 0,
            .ass = 1,
        }, 
        SPI_SLAVE_FLASH);
}

UNUSED_FUNC uint32_t flash_read(uint32_t addr)
{
    uint32_t datas[2] = {
        0,
        ((FLASH_CMD_READ_DATA&0xFF)<<24) | ((addr&0xFFFFFF)<<0),
    };
    volatile uint32_t *rx = spi_transfer(datas, 2, SPI_TRANSFER_SYNC);
    return swap_uint32(rx[0]);
}

#endif
