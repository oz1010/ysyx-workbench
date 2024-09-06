#include <unistd.h>
#include <stdio.h>
#include <sys/errno.h>
#include "generated/autoconf.h"
#include "dm/dm.h"
#include "dm/dm_interface.h"
#include "dm/dm_network.h"
#include "cpu/cpu.h"

#include <sys/socket.h>

/**
 * Table 6.1: JTAG DTM TAP Registers
 */
typedef enum _dm_info_regs_idx_e {
    DMIRI_BYPASS        = 0x00,     // BYPASS
    DMIRI_IDCODE        = 0x01,     // IDCODE
    DMIRI_DTMCS         = 0x10,     // DTM Control and Status (dtmcs)
    DMIRI_DMI           = 0x11,     // Debug Module Interface Access (dmi)
    DMIRI_BYPASS_12           ,     // Reserved (BYPASS)
    DMIRI_BYPASS_13           ,     // Reserved (BYPASS)
    DMIRI_BYPASS_14           ,     // Reserved (BYPASS)
    DMIRI_BYPASS_15           ,     // Reserved (BYPASS)
    DMIRI_BYPASS_16           ,     // Reserved (BYPASS)
    DMIRI_BYPASS_17           ,     // Reserved (BYPASS)
    DMIRI_BYPASS_1F     = 0x1F,     // BYPASS 0x1F
    DMIRI_MAX
} dm_info_regs_idx_t;
static_assert((DMIRI_MAX&(DMIRI_MAX-1))==0, "must be equal to a power of 2");

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

typedef struct _dm_debug_registers_s{
    uint8_t ir;
    uint32_t regs[DMIRI_MAX];
    dm_debug_status_t status;
} dm_debug_info_t;

static dm_debug_info_t dm_debug_info = {0};

void init_dm_debug_info(dm_debug_info_t *info, dm_debug_status_t status)
{
    memset(info, 0, sizeof(dm_debug_info_t));
    
    // info->regs[DMIRI_BYPASS] = 0x00000031;   // BYPASS
    info->regs[DMIRI_BYPASS] = -1;   // BYPASS

    /**
     * IDCODE 0x3ba0184d (mfg: 0x426 (Google Inc), part: 0xba01, ver: 0x3)
     * ref. riscv-openocd/src/helper/jep106.inc
     *   [8][0x26 - 1] = "Google Inc",
    */
    info->regs[DMIRI_IDCODE] = DMM_IDCODE_VALUE(0x3, 0xba01, 8, 0x26);

    // default is version 0.13
    dm_reg_dtmcs_t *dtmcs = (dm_reg_dtmcs_t *)&info->regs[DMIRI_DTMCS];
    dtmcs->version = 1;

    /** 
     * 6.1.2 JTAG DTM Registers
     *   When the TAP is reset, IR must default to 00001
     */
    info->ir = 0b00001;

    info->status = status;
}

int init_dm(int argc, char *argv[])
{
#if CONFIG_DEBUG_MODULE
    init_dm_debug_info(&dm_debug_info, dmds_mus_mode);

    init_dm_interface();

    init_dm_network();
#endif
    return 0;
}

dm_debug_status_t get_dm_debug_status()
{
    return dm_debug_info.status;
}

int dm_valid()
{
    return dm_debug_info.status != dmds_none;
}

void dm_dump_data(const char *title, uint8_t *data, int32_t size)
{
    int32_t line_cols = 16;
    int32_t i,j;

    printf("%s (%d):\n", title, size);
    for (i=0; i<size; i+=line_cols) {
        printf("[%03d]", i);
        for (j=0; j<line_cols && (i+j)<size; ++j) {
            printf("  %.02x", data[i+j]);
        }
        printf("\n");
    }
}

uint8_t *dm_parse_scan_msg(uint8_t *buff, dm_msg_t *resp_msg)
{
    char debug_info[1024] = {0};
    int debug_info_size = 0;
    dm_debug_info_t *info = &dm_debug_info;

    // 提取消息体，并进行处理
    uint8_t *body_data = buff;
    DMM_PARSE_VALUE(bool, ir_scan);
    DMM_PARSE_VALUE(int, num_fields);

    for (int i=0; i<num_fields; ++i)
    {
        DMM_PARSE_VALUE(int, num_bits);
        DMM_PARSE_ARRAY(const uint8_t *, out_value, num_bits/8);
        uint32_t *select = (uint32_t *)out_value;

        uint8_t val_bytes = 0;
        void *val = NULL;
        if (ir_scan) {
            info->ir = *select & 0x1F;

            val_bytes = 1;
            // val = &info->regs[DMIRI_BYPASS];
            val = "1";
            debug_info_size += snprintf(&debug_info[debug_info_size], sizeof(debug_info)-debug_info_size, "[%d] IR:%#.2x RESP:%s\t", i, info->ir, (char *)val);
        } else {
            val_bytes = sizeof(info->regs[0]);
            val = &info->regs[info->ir];
            debug_info_size += snprintf(&debug_info[debug_info_size], sizeof(debug_info)-debug_info_size, "[%d] IR:%#.2x RESP:%#.8x\t", i, info->ir, *(uint32_t *)val);
        }
        dmm_package_body(resp_msg, &val_bytes, sizeof(val_bytes));
        dmm_package_body(resp_msg, val, val_bytes);

        LOG_DEBUG("dm parse msg type:%s num_fields:%02d\t%s", ir_scan?"IRSCAN":"DRSCAN", num_fields, debug_info);
    }

    return body_data;
}

void dm_update(int period, Decode *s, CPU_state *c)
{
    dm_msg_t recv_msg;
    int handle_ret = 0;

    // 执行指令前
    if (period == 0)
    {
        while(dm_valid()) {
            if (dm_msg_queue_pop(&dm_msg_queue, &recv_msg) != 0) {
                usleep(10000);
                continue;
            }

            // LOG_DEBUG("cpu state current pc %#x", c->pc);

            dm_msg_t resp_msg;
            dmm_init(&resp_msg);
            resp_msg.header.client_fd = recv_msg.header.client_fd;
            uint8_t *body_data = &recv_msg.body[0];
            uint8_t *body_data_start = body_data;

            while ((body_data-body_data_start)<recv_msg.header.num_bytes) {
                DMM_PARSE_VALUE(uint8_t, cmd_type);

                if (cmd_type>DMM_BODY_UNKNOWN && cmd_type<DMM_BODY_TYPE_MAX) {
                    dmm_package_body(&resp_msg, &cmd_type, 1);
                } else {
                    continue;
                }

                switch(cmd_type)
                {
                    case DMM_BODY_SCAN:
                    {
                        body_data = dm_parse_scan_msg(body_data, &resp_msg);
                        break;
                    }

                    case DMM_BODY_TLR_RESET:
                    case DMM_BODY_RESET:
                    {
                        init_dm_debug_info(&dm_debug_info, dmds_mus_mode);

                        uint32_t status_ok = 0;
                        dmm_package_body(&resp_msg, &status_ok, sizeof(status_ok));
                        LOG_DEBUG("dm parse msg cmd_type:%s resp:%u", cmd_type==DMM_BODY_TLR_RESET?"TLR_RESET":"RESET", status_ok);
                        break;
                    }
                    
                    default:
                    {
                        LOG_ERROR("recv invalid cmd_type:%d", cmd_type);
                        break;
                    }
                }
            }

            // 直接回复消息
            int send_ret = send(resp_msg.header.client_fd, &resp_msg, sizeof(dm_msg_header_t)+resp_msg.header.num_bytes, 0);
            if (send_ret < 0)
            {
                LOG_ERROR("send failed, errno:%d errstr:%s", errno, strerror(errno));
                return;
            }
            // LOG_DEBUG("send done, ret:%d", send_ret);
        }
    }
    // 执行指令后
    else
    {

    }
    (void)handle_ret;
}
