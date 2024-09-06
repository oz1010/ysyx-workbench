#include <unistd.h>
#include <stdio.h>
#include <sys/errno.h>
#include "generated/autoconf.h"
#include "dm/dm.h"
#include "dm/dm_interface.h"
#include "dm/dm_network.h"
#include "cpu/cpu.h"

#include <sys/socket.h>

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
#define DM_REG(S, N) DM_REGISTER(dm_reg_##S##_t, dtmri_##S, N, dm_debug_info.regs)
#define DM_R(N) DM_REG(N, r_##N)
// dm_reg_dmi_t *r_dmi = (dm_reg_dmi_t *)&dm_debug_info.regs[dtmri_dmi];

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

typedef struct _dm_debug_delay_cmd_s {
    uint8_t *resp_addr;
    dm_reg_dmi_t *scan;
} dm_debug_delay_cmd_t;

typedef struct _dm_debug_registers_s{
    uint8_t ir;
    uint32_t regs[dtmri_count];
    dm_debug_status_t status;
    dm_debug_delay_cmd_t delay_cmd;
} dm_debug_info_t;

static dm_debug_info_t dm_debug_info = {0};

void init_dm_debug_info(dm_debug_info_t *info, dm_debug_status_t status)
{
    memset(info, 0, sizeof(dm_debug_info_t));
    
    // info->regs[DMIRI_BYPASS] = 0x00000031;   // BYPASS
    info->regs[dtmri_bypass] = -1;   // BYPASS

    /**
     * IDCODE 0x3ba0184d (mfg: 0x426 (Google Inc), part: 0xba01, ver: 0x3)
     * ref. riscv-openocd/src/helper/jep106.inc
     *   [8][0x26 - 1] = "Google Inc",
    */
    info->regs[dtmri_idcode] = DMM_IDCODE_VALUE(0x3, 0xba01, 8, 0x26);

    // default is version 0.13
    dm_reg_dtmcs_t *dtmcs = (dm_reg_dtmcs_t *)&info->regs[dtmri_dtmcs];
    dtmcs->version = 1;
    dtmcs->abits = DM_DTMCS_ABITS_MAX;

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
    uint8_t *scan_idcode_data = NULL;

    // 提取消息体，并进行处理
    uint8_t *body_data = buff;
    DMM_PARSE_VALUE(bool, ir_scan);
    DMM_PARSE_VALUE(int, num_fields);

    dmm_package_body(resp_msg, &ir_scan, sizeof(ir_scan));
    dmm_package_body(resp_msg, &num_fields, sizeof(num_fields));

    for (int i=0; i<num_fields; ++i)
    {
        DMM_PARSE_VALUE(int, num_bits);
        DMM_PARSE_ARRAY(const uint8_t *, out_value, DIV_ROUND_UP(num_bits, 8));
        uint32_t *select = (uint32_t *)out_value;

        uint32_t val_bytes = 0;
        void *val = NULL;
        if (ir_scan) {
            info->ir = *select & 0x1F;

            val_bytes = 1;
            // val = &info->regs[DMIRI_BYPASS];
            val = "1";
            debug_info_size += snprintf(&debug_info[debug_info_size], sizeof(debug_info)-debug_info_size,
                "[%d] ir:%#.2x bits:%02d resp:%#.8x\t",
                i, info->ir, num_bits, *(uint32_t *)val);
        } else {

            // 当ir为dmi时，将此时的值赋值给对应的寄存器
            if (info->ir == dtmri_dmi)
            {
                DM_R(dmi);
                dm_debug_info.delay_cmd.scan = r_dmi;
                memcpy(r_dmi, out_value, DIV_ROUND_UP(num_bits, 8));

                // val_bytes = sizeof(info->regs[0]);
                val_bytes = DIV_ROUND_UP(num_bits, 8);
                val = &info->regs[info->ir];
                dm_debug_info.delay_cmd.resp_addr = &resp_msg->body[resp_msg->header.num_bytes + sizeof(val_bytes)]; // 需要跳过长度
            } else if (info->ir == dtmri_idcode) {
                val_bytes = DIV_ROUND_UP(num_bits, 8);
                scan_idcode_data = malloc(val_bytes);
                memset(scan_idcode_data, 0xffffffff, val_bytes);
                memcpy(scan_idcode_data, &info->regs[dtmri_idcode], sizeof(uint32_t));
                val = scan_idcode_data;
            } else {
                val_bytes = sizeof(info->regs[0]);
                val = &info->regs[info->ir];
            }
            debug_info_size += snprintf(&debug_info[debug_info_size], sizeof(debug_info)-debug_info_size,
                "[%d] ir:%#.2x bits:%02d resp:%#.8x\t",
                i, info->ir, num_bits, *(uint32_t *)val);
        }
        uint32_t val_bits = val_bytes * 8;
        dmm_package_body(resp_msg, &val_bits, sizeof(val_bits));
        dmm_package_body(resp_msg, val, val_bytes);

        LOG_DEBUG("dm parse msg type:%s num_fields:%02d\t%s", ir_scan?"IRSCAN":"DRSCAN", num_fields, debug_info);
    }

    if (scan_idcode_data) {
        free(scan_idcode_data);
        scan_idcode_data = NULL;
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
            dmm_reset(&recv_msg);
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

                if (cmd_type>0 && cmd_type<=JTAG_TMS) {
                    dmm_package_body(&resp_msg, &cmd_type, 1);
                } else {
                    LOG_WARNING("skip cmd type:%u", cmd_type);
                    continue;
                }

                switch(cmd_type)
                {
                    case JTAG_SCAN:
                    {
                        body_data = dm_parse_scan_msg(body_data, &resp_msg);
                        break;
                    }

                    case JTAG_RUNTEST:
                    {
                        int dmi_ret = 0;
                        uint32_t *resp_addr = NULL;
                        if (dm_debug_info.delay_cmd.scan)
                        {
                            dm_reg_dmi_t *delay_dmi = dm_debug_info.delay_cmd.scan;
                            resp_addr = (uint32_t *)dm_debug_info.delay_cmd.resp_addr;

                            // 执行dmi命令
                            uint32_t execute_val = 0;
                            dmi_ret = dmi_execute(delay_dmi->address, delay_dmi->data, (uint32_t *)&execute_val, delay_dmi->op);
                            delay_dmi->data = execute_val;
                            // 将数据拷贝到响应结构中
                            memcpy(resp_addr, delay_dmi, DIV_ROUND_UP((2+32+DM_DTMCS_ABITS_MAX),8));

                            dm_debug_info.delay_cmd.scan = NULL;
                            dm_debug_info.delay_cmd.resp_addr = NULL;
                        }

                        LOG_DEBUG("dm parse msg cmd_type:JTAG_RUNTEST resp(64bits):%#lx dmi_ret:%d", *(uint64_t *)resp_addr, dmi_ret);
                        break;
                    }

                    case JTAG_TLR_RESET:
                    case JTAG_RESET:
                    {
                        init_dm_debug_info(&dm_debug_info, dmds_mus_mode);

                        uint32_t status_ok = 0;
                        LOG_DEBUG("dm parse msg cmd_type:%s resp:%u", cmd_type==JTAG_TLR_RESET?"TLR_RESET":"RESET", status_ok);
                        break;
                    }
                    
                    default:
                    {
                        LOG_ERROR("recv invalid cmd_type:%d", cmd_type);
                        break;
                    }
                }

                // 执行完dm命令后，更新dmi状态
                dmi_update_status();
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
