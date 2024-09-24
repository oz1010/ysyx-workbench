#ifndef __DTM_H__
#define __DTM_H__

#include <stdint.h>
#include "cpu/decode.h"
#include "cpu/cpu.h"

// 4.8 Core Debug Registers, maximum of register address is 0x7b3
#define DM_DTMCS_ABITS_MAX              12
#define DM_DTMCS_ABITS_MASK             (DM_DTMCS_ABITS_MAX-1)

/**
 * Rounds @c m up to the nearest multiple of @c n using division.
 * @param m The value to round up to @c n.
 * @param n Round @c m up to a multiple of this number.
 * @returns The rounded integer value.
 */
#define DIV_ROUND_UP(m, n)	(((m) + (n) - 1) / (n))

#define DM_REGISTER(T, I, N, RS) T*N=(T*)&RS[(I)];(void)N
#define DM_REG(S, N) DM_REGISTER(dm_reg_##S##_t, dtmri_##S, N, dtm_ctx.regs)
#define DM_R(N) DM_REG(N, r_##N)
// dm_reg_dmi_t *r_dmi = (dm_reg_dmi_t *)&dtm_ctx.regs[dtmri_dmi];

/**
 * The type of the @c jtag_command_container contained by a
 * @c jtag_command structure.
 */
enum jtag_command_type {
	JTAG_SCAN         = 1,
	/* JTAG_TLR_RESET's non-minidriver implementation is a
	 * vestige from a statemove cmd. The statemove command
	 * is obsolete and replaced by pathmove.
	 *
	 * pathmove does not support reset as one of it's states,
	 * hence the need for an explicit statemove command.
	 */
	JTAG_TLR_RESET    = 2,
	JTAG_RUNTEST      = 3,
	JTAG_RESET        = 4,
	JTAG_PATHMOVE     = 6,
	JTAG_SLEEP        = 7,
	JTAG_STABLECLOCKS = 8,
	JTAG_TMS          = 9,
};

/**
 * Table 6.1: JTAG DTM TAP Registers
 */
typedef enum _dtm_regs_idx_e {
    dtmri_bypass        = 0x00,     // BYPASS
    dtmri_idcode        = 0x01,     // IDCODE
    dtmri_dtmcs         = 0x10,     // DTM Control and Status (dtmcs)
    dtmri_dmi           = 0x11,     // Debug Module Interface Access (dmi)
    dtmri_bypass_12           ,     // Reserved (BYPASS)
    dtmri_bypass_13           ,     // Reserved (BYPASS)
    dtmri_bypass_14           ,     // Reserved (BYPASS)
    dtmri_bypass_15           ,     // Reserved (BYPASS)
    dtmri_bypass_16           ,     // Reserved (BYPASS)
    dtmri_bypass_17           ,     // Reserved (BYPASS)
    dtmri_bypass_1f     = 0x1F,     // BYPASS 0x1F
    dtmri_count
} dtm_regs_idx_t;
static_assert((dtmri_count&(dtmri_count-1))==0, "must be equal to a power of 2");

/**
 * 6.1.4 DTM Control and Status (dtmcs, at 0x10)
 */
typedef struct _dm_reg_dtmcs_s {
    /**
     * R 1
     * 0: Version described in spec version 0.11.
     * 1: Version described in spec version 0.13.
     * 15: Version not described in any available version of this spec.
     */
    uint32_t version:4;

    /**
     * R Preset
     * The size of address in dmi.
     */
    uint32_t abits:6;

    /**
     * R 0
     * 0: No error.
     * 1: Reserved. Interpret the same as 2.
     * 2: An operation failed (resulted in op of 2).
     * 3: An operation was attempted while a DMI access was still in progress (resulted in op of 3)
     */
    uint32_t dmistat:2;

    /**
     * R Preset
     * This is a hint to the debugger of the minimum
     * number of cycles a debugger should spend in RunTest/Idle after every DMI scan to avoid a ‘busy’
     * return code (dmistat of 3). A debugger must still
     * check dmistat when necessary.
     * 0: It is not necessary to enter Run-Test/Idle at all.
     * 1: Enter Run-Test/Idle and leave it immediately.
     * 2: Enter Run-Test/Idle and stay there for 1 cycle before leaving.
     */
    uint32_t idle:3;

    /**
     * 0
     */
    const uint32_t rsv0:1;
    
    /**
     * W1 -
     * Writing 1 to this bit clears the sticky error state
     * and allows the DTM to retry or complete the previous transaction.
     */
    uint32_t dmireset:1;

    /**
     * W1 -
     * Writing 1 to this bit does a hard reset of the DTM,
     * causing the DTM to forget about any outstanding DMI transactions. In general this should only
     * be used when the Debugger has reason to expect
     * that the outstanding DMI transaction will never
     * complete (e.g. a reset condition caused an inflight
     * DMI transaction to be cancelled).
     */
    uint32_t dmihardreset:1;

    /**
     * 0
     */
    const uint32_t rsv1:14;
} dm_reg_dtmcs_t;

/**
 * 6.1.5 Debug Module Interface Access (dmi, at 0x11)
 */
typedef struct _dm_reg_dmi_s {
    /**
     * RW 0
     * When the debugger writes this field, it has the following meaning:
     * 0: Ignore data and address. (nop) Don’t send anything over the DMI during Update-DR. 
     *   This operation should never result in a busy or error response. 
     *   The address and data reported in the following Capture-DR are undefined.
     * 1: Read from address. (read)
     * 2: Write data to address. (write)
     * 3: Reserved.
     * When the debugger reads this field, it means the following:
     * 0: The previous operation completed successfully.
     * 1: Reserved.
     * 2: A previous operation failed. The data scanned into dmi in this access will be ignored. 
     *   This status is sticky and can be cleared by writing dmireset in dtmcs. 
     *   This indicates that the DM itself responded with an error. There are no specified cases 
     *   in which the DM would respond with an error, and DMI is not required to support returning errors.
     * 3: An operation was attempted while a DMI request is still in progress. The data scanned into 
     *   dmi in this access will be ignored. This status is sticky and can be cleared by writing dmireset in dtmcs. 
     *   If a debugger sees this status, it needs to give the target more TCK edges between UpdateDR and Capture-DR. 
     *   The simplest way to do that is to add extra transitions in Run-Test/Idle.
     */
    uint64_t    op:2;

    /**
     * RW 0
     * The data to send to the DM over the DMI during Update-DR, and the data returned from the DM
     * as a result of the previous operation.
     */
    uint64_t    data:32;

    /**
     * RW 0
     * Address used for DMI access. In Update-DR this value is used to access the DM over the DMI.
     */
    uint64_t    address:DM_DTMCS_ABITS_MAX;
} dm_reg_dmi_t;

typedef enum _dm_debug_status_e {
    dmds_none,
    dmds_init,
    dmds_mus_mode,

    dmds_resuming,
    dmds_halting,
    dmds_halted_waiting,

    dmds_command_start,
    dmds_command_transfer,
    dmds_command_done,
    dmds_command_progbuf,

    dmds_error_detected,
    dmds_error_wait,

    dmds_quick_access_halt,
    dmds_quick_access_resume,
    dmds_quick_access_exec,
} dm_debug_status_t;

typedef struct _dm_debug_delay_cmd_s {
    uint8_t *resp_addr;
    dm_reg_dmi_t *scan;
} dm_debug_delay_cmd_t;

int dtm_init(int argc, char *argv[]);
dm_debug_status_t dtm_get_dm_debug_status();
int dtm_dm_valid();
void dtm_update(int period, Decode *s, CPU_state *c);

#endif
