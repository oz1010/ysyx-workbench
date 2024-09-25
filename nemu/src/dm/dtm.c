#include <unistd.h>
#include <stdio.h>
#include <sys/errno.h>
#include "generated/autoconf.h"
#include "dm/dm.h"
#include "dm/dtm.h"
#include "dm/dm_interface.h"
#include "dm/dtm_network.h"
#include "cpu/cpu.h"

#include <sys/socket.h>

typedef struct _dm_debug_registers_s{
    uint8_t ir;
    uint32_t regs[dtm_ri_count];
    dm_debug_delay_cmd_t delay_cmd;
} dtm_ctx_t;

static dtm_ctx_t dtm_ctx = {0};

static void dtm_ctx_init(dtm_ctx_t *ctx)
{
    memset(ctx, 0, sizeof(dtm_ctx_t));
    
    // info->regs[DMIRI_BYPASS] = 0x00000031;   // BYPASS
    ctx->regs[dtm_ri_bypass] = -1;   // BYPASS

    /**
     * IDCODE 0x3ba0184d (mfg: 0x426 (Google Inc), part: 0xba01, ver: 0x3)
     * ref. riscv-openocd/src/helper/jep106.inc
     *   [8][0x26 - 1] = "Google Inc",
    */
    ctx->regs[dtm_ri_idcode] = DTM_MSG_IDCODE_VALUE(0x3, 0xba01, 8, 0x26);

    // default is version 0.13
    dtm_reg_dtmcs_t *dtmcs = (dtm_reg_dtmcs_t *)&ctx->regs[dtm_ri_dtmcs];
    dtmcs->version = 1;
    dtmcs->abits = DM_DTMCS_ABITS_MAX;

    /** 
     * 6.1.2 JTAG DTM Registers
     *   When the TAP is reset, IR must default to 00001
     */
    ctx->ir = 0b00001;
}

int dtm_init(int argc, char *argv[])
{
#if CONFIG_DEBUG_MODULE
    dm_init();

    dmi_init();
    
    dtm_ctx_init(&dtm_ctx);

    dtmn_init();
#endif
    return 0;
}

int dtm_dm_valid()
{
    return dmi_get_debug_status() > dm_ds_mus_mode;
}

void dtm_dm_dump_data(const char *title, uint8_t *data, int32_t size)
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

uint8_t *dtm_dm_parse_scan_msg(uint8_t *buff, dtm_msg_t *resp_msg)
{
    char debug_info[1024] = {0};
    int debug_info_size = 0;
    dtm_ctx_t *ctx = &dtm_ctx;
    uint8_t *scan_idcode_data = NULL;

    // 提取消息体，并进行处理
    uint8_t *body_data = buff;
    DTM_MSG_PARSE_VALUE(bool, ir_scan);
    DTM_MSG_PARSE_VALUE(int, num_fields);

    dtm_msg_package_body(resp_msg, &ir_scan, sizeof(ir_scan));
    dtm_msg_package_body(resp_msg, &num_fields, sizeof(num_fields));

    for (int i=0; i<num_fields; ++i)
    {
        DTM_MSG_PARSE_VALUE(int, num_bits);
        DTM_MSG_PARSE_ARRAY(const uint8_t *, out_value, DIV_ROUND_UP(num_bits, 8));
        uint32_t *select = (uint32_t *)out_value;

        uint32_t val_bytes = 0;
        void *val = NULL;
        if (ir_scan) {
            ctx->ir = *select & 0x1F;

            val_bytes = 1;
            // val = &info->regs[DMIRI_BYPASS];
            val = "1";
            debug_info_size += snprintf(&debug_info[debug_info_size], sizeof(debug_info)-debug_info_size,
                "[%d] ir:%#.2x bits:%02d resp:%#.8x\t",
                i, ctx->ir, num_bits, *(uint32_t *)val);
        } else {

            // 当ir为dmi时，将此时的值赋值给对应的寄存器
            if (ctx->ir == dtm_ri_dmi)
            {
                DTM_R(dmi);
                dtm_ctx.delay_cmd.scan = r_dmi;
                memcpy(r_dmi, out_value, DIV_ROUND_UP(num_bits, 8));

                // val_bytes = sizeof(info->regs[0]);
                val_bytes = DIV_ROUND_UP(num_bits, 8);
                val = &ctx->regs[ctx->ir];
                dtm_ctx.delay_cmd.resp_addr = &resp_msg->body[resp_msg->header.num_bytes + sizeof(val_bytes)]; // 需要跳过长度
            } else if (ctx->ir == dtm_ri_idcode) {
                val_bytes = DIV_ROUND_UP(num_bits, 8);
                scan_idcode_data = malloc(val_bytes);
                memset(scan_idcode_data, 0xffffffff, val_bytes);
                memcpy(scan_idcode_data, &ctx->regs[dtm_ri_idcode], sizeof(uint32_t));
                val = scan_idcode_data;
            } else {
                val_bytes = sizeof(ctx->regs[0]);
                val = &ctx->regs[ctx->ir];
            }
            debug_info_size += snprintf(&debug_info[debug_info_size], sizeof(debug_info)-debug_info_size,
                "[%d] ir:%#.2x bits:%02d resp:%#.8x\t",
                i, ctx->ir, num_bits, *(uint32_t *)val);
        }
        uint32_t val_bits = val_bytes * 8;
        dtm_msg_package_body(resp_msg, &val_bits, sizeof(val_bits));
        dtm_msg_package_body(resp_msg, val, val_bytes);

        DTM_DEBUG("parse msg type:%s num_fields:%02d\t%s", ir_scan?"IRSCAN":"DRSCAN", num_fields, debug_info);
    }

    if (scan_idcode_data) {
        free(scan_idcode_data);
        scan_idcode_data = NULL;
    }

    return body_data;
}

void dtm_update(int period, Decode *s, CPU_state *c)
{
    dtm_msg_t recv_msg;
    int handle_ret = 0;

    // 执行指令前
    if (period == 0)
    {
        while(dtm_dm_valid()) {
            dtm_msg_reset(&recv_msg);
            if (dtmn_msg_queue_pop(&dtmn_msg_queue, &recv_msg) != 0) {
                usleep(10000);
                continue;
            }

            // DTM_DEBUG("cpu state current pc %#x", c->pc);

            dtm_msg_t resp_msg;
            dtm_msg_init(&resp_msg);
            resp_msg.header.client_fd = recv_msg.header.client_fd;
            uint8_t *body_data = &recv_msg.body[0];
            uint8_t *body_data_start = body_data;

            while ((body_data-body_data_start)<recv_msg.header.num_bytes) {
                DTM_MSG_PARSE_VALUE(uint8_t, cmd_type);

                if (cmd_type>0 && cmd_type<=JTAG_TMS) {
                    dtm_msg_package_body(&resp_msg, &cmd_type, 1);
                } else {
                    LOG_WARNING("skip cmd type:%u", cmd_type);
                    continue;
                }

                switch(cmd_type)
                {
                    case JTAG_SCAN:
                    {
                        body_data = dtm_dm_parse_scan_msg(body_data, &resp_msg);
                        break;
                    }

                    case JTAG_RUNTEST:
                    {
                        int dmi_ret = 0;
                        (void)dmi_ret;
                        uint8_t *resp_addr = NULL;
                        if (dtm_ctx.delay_cmd.scan)
                        {
                            dtm_reg_dmi_t *delay_dmi = dtm_ctx.delay_cmd.scan;
                            resp_addr = dtm_ctx.delay_cmd.resp_addr;

                            // 执行dmi命令
                            uint32_t execute_val = delay_dmi->data;
                            dmi_ret = dmi_execute(delay_dmi->address, &execute_val, delay_dmi->op);
                            delay_dmi->data = execute_val;
                            // 将数据拷贝到响应结构中
                            memcpy(resp_addr, delay_dmi, DIV_ROUND_UP((2+32+DM_DTMCS_ABITS_MAX),8));

                            dtm_ctx.delay_cmd.scan = NULL;
                            dtm_ctx.delay_cmd.resp_addr = NULL;
                        }

                        if (resp_addr)
                        {
                            DTM_DEBUG("parse msg cmd_type:JTAG_RUNTEST modify resp(64bits):[%p] => %#lx dmi_ret:%d", resp_addr, *(uint64_t *)resp_addr, dmi_ret);
                        }
                        else
                        {
                            DTM_DEBUG("parse msg cmd_type:JTAG_RUNTEST skip");
                        }
                        break;
                    }

                    case JTAG_TLR_RESET:
                    case JTAG_RESET:
                    {
                        dtm_ctx_init(&dtm_ctx);
                        DTM_DEBUG("parse msg cmd_type:%s", cmd_type==JTAG_TLR_RESET?"TLR_RESET":"RESET");
                        break;
                    }
                    
                    default:
                    {
                        DTM_ERROR("recv invalid cmd_type:%d", cmd_type);
                        break;
                    }
                }

                // 执行完dtm命令后，更新dmi状态
                dmi_update_status();
            }

            // 直接回复消息
            int send_ret = send(resp_msg.header.client_fd, &resp_msg, sizeof(dtm_msg_header_t)+resp_msg.header.num_bytes, 0);
            if (send_ret < 0)
            {
                DTM_ERROR("send failed, errno:%d errstr:%s", errno, strerror(errno));
                return;
            }
            // DTM_DEBUG("send done, ret:%d", send_ret);
        }
    }
    // 执行指令后
    else
    {

    }
    (void)handle_ret;
}
