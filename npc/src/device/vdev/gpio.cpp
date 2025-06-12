#include "device/vdev.h"
#include "generated/autoconf.h"
#include "utils.h"

static uint8_t *base = NULL;
static const uint32_t size = 16;

void init_gpio()
{
    base = new_vmem(size);
    add_vdev_item(VDEV_INNER, "gpio", CONFIG_GPIO_BASE_ADDR, base, size, (VDEV_ATTR_READ|VDEV_ATTR_WRITE), NULL);
}
