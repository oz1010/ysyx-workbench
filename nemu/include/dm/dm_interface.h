#ifndef __DM_INTERFACE_H__
#define __DM_INTERFACE_H__

#include <stdint.h>
#include <assert.h>
#include <string.h>
#include <stdbool.h>

#include "dm/dm_define.h"
#include "dm/dtm_define.h"

int dmi_init(void);
int dmi_execute(uint32_t addr, uint32_t in_val, uint32_t *out_val, uint32_t op);
int dmi_update_status(void);

#endif
