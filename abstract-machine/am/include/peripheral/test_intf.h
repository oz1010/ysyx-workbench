#ifndef __TEST_INTF_H__
#define __TEST_INTF_H__

#include <stdint.h>
#include "am.h"

#define TEST_INTF_BASEADDR                  0x0f002000
#define TEST_INIF_SWITCH_FLASH              (TEST_INTF_BASEADDR+0x0)
#define TEST_INIF_SWITCH_PSRAM              (TEST_INTF_BASEADDR+0x4)
#define TEST_INIF_FLASH_BASEADDR            0x30f00000
#define TEST_INIF_PSRAM_OFFSET              0x00300000
#define TEST_INIF_PSRAM_BASEADDR            (0x80000000+TEST_INIF_PSRAM_OFFSET)

UNUSED_FUNC inline void test_intf_switch_flash(uint32_t num)
{
    *((volatile uint32_t *)TEST_INIF_SWITCH_FLASH) = num;
}

UNUSED_FUNC inline void test_intf_switch_psram(uint32_t num)
{
    *((volatile uint32_t *)TEST_INIF_SWITCH_PSRAM) = num;
}

#endif
