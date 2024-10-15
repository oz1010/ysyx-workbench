#ifndef __DM_INTERFACE_H__
#define __DM_INTERFACE_H__

#include <stdint.h>
#include <assert.h>
#include <string.h>
#include <stdbool.h>

#include "dm/dm_define.h"
#include "dm/dtm_define.h"

int dmi_init(void);
int dmi_execute(uint32_t addr, uint32_t *val, uint32_t op);
int dmi_update_status(void);
dm_debug_status_t dmi_get_debug_status(void);
int dmi_update_core_debug_register(int period);
int dmi_prepare_status(uint32_t inst);
bool dmi_is_hart_running(void);

#endif
