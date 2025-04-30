#include "am.h"
#include <stdint.h>
#include "file/bin_header.h"
#include "peripheral/flash.h"

int main()
{
    flash_init();
    return 0;
}
