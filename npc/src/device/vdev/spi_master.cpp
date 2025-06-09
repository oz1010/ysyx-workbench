#include "device/vdev.h"
#include "generated/autoconf.h"
#include "utils.h"

static uint8_t *spi_base = NULL;
static const uint32_t spi_size = 4 * 1024;

void init_spi_master()
{
    spi_base = new_vmem(spi_size);
    add_vdev_item(VDEV_INNER, "spi_master", CONFIG_SPI_MASTER_BASE_ADDR, spi_base, spi_size, (VDEV_ATTR_READ|VDEV_ATTR_WRITE), NULL);
}
