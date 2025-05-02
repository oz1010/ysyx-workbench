#ifndef __TEST_INTF_H__
#define __TEST_INTF_H__

#include <stdint.h>
#include "am.h"

#define TEST_INTF_BASEADDR                  0x0f002000
#define TEST_INIF_SWITCH_FLASH              (TEST_INTF_BASEADDR+0x0)
#define TEST_INIF_FLASH_BASEADDR            0x30f00000

UNUSED_FUNC inline void test_intf_switch_flash(uint32_t num)
{
    *((volatile uint32_t *)TEST_INIF_SWITCH_FLASH) = num;
}

#endif
