#ifndef __DM_DEFINE_H__
#define __DM_DEFINE_H__

#include <stdint.h>
#include <assert.h>
#include <string.h>
#include <stdbool.h>

/**
 * ref. RISC-V External Debug Support Version 0.13.2
 */
typedef enum _dm_regs_idx_e {
    // Abstract Data 0 - 11, P30
    dm_ri_data0 = 0x04,
    dm_ri_data1,
    dm_ri_data2,
    dm_ri_data3,
    dm_ri_data4,
    dm_ri_data5,
    dm_ri_data6,
    dm_ri_data7,
    dm_ri_data8,
    dm_ri_data9,
    dm_ri_data10,
    dm_ri_data11,
    // Debug Module Control, P22
    dm_ri_dmcontrol,
    // Debug Module Status, P20
    dm_ri_dmstatus,
    // Hart Info, P25
    dm_ri_hartinfo,
    // Halt Summary 1, P31
    dm_ri_haltsum1,
    // Hart Array Window Select, P26
    dm_ri_hawindowsel,
    // Hart Array Window, P26
    dm_ri_hawindow,
    // Abstract Control and Status, P27
    dm_ri_abstractcs,
    // Abstract Command, P28
    dm_ri_command,
    // Abstract Command Autoexec, P29
    dm_ri_abstractauto,
    // Configuration String Pointer 0, P29
    dm_ri_confstrptr0,
    // Configuration String Pointer 1, P29
    dm_ri_confstrptr1,
    // Configuration String Pointer 2, P29
    dm_ri_confstrptr2,
    // Configuration String Pointer 3, P29
    dm_ri_confstrptr3,
    // Next Debug Module, P30
    dm_ri_nextdm,
    // Program Buffer 0 - 15, P30
    dm_ri_progbuf0 = 0x20,
    dm_ri_progbuf1,
    dm_ri_progbuf2,
    dm_ri_progbuf3,
    dm_ri_progbuf4,
    dm_ri_progbuf5,
    dm_ri_progbuf6,
    dm_ri_progbuf7,
    dm_ri_progbuf8,
    dm_ri_progbuf9,
    dm_ri_progbuf10,
    dm_ri_progbuf11,
    dm_ri_progbuf12,
    dm_ri_progbuf13,
    dm_ri_progbuf14,
    dm_ri_progbuf15,
    // Authentication Data, P31
    dm_ri_authdata,
    // Halt Summary 2, P32
    dm_ri_haltsum2 = 0x34,
    // Halt Summary 3, P32
    dm_ri_haltsum3,
    // System Bus Address 127:96, P36
    dm_ri_sbaddress3 = 0x37,
    // System Bus Access Control and Status, P32
    dm_ri_sbcs,
    // System Bus Address 31:0, P34
    dm_ri_sbaddress0,
    // System Bus Address 63:32, P35
    dm_ri_sbaddress1,
    // System Bus Address 95:64, P35
    dm_ri_sbaddress2,
    // System Bus Data 31:0, P36
    dm_ri_sbdata0,
    // System Bus Data 63:32, P37
    dm_ri_sbdata1,
    // System Bus Data 95:64, P37
    dm_ri_sbdata2,
    // System Bus Data 127:96, P38
    dm_ri_sbdata3,
    // Halt Summary 0, P31
    dm_ri_haltsum0,

    dm_ri_count,
} dm_regs_idx_t;

/**
 * 3.12.1 Debug Module Status (dmstatus, at 0x11)
 */
typedef struct _dm_reg_dmstatus_s {
    /**
     * R 2
     */
    uint32_t    version:4;
    /**
     * R Preset
     */
    uint32_t    confstrptrvalid:1;
    /**
     * R Preset
     */
    uint32_t    hasresethaltreq:1;
    /**
     * R 0
     */
    uint32_t    authbusy:1;
    /**
     * R Preset
     */
    uint32_t    authenticated:1;
    /**
     * R -
     */
    uint32_t    anyhalted:1;
    /**
     * R -
     */
    uint32_t    allhalted:1;
    /**
     * R -
     */
    uint32_t    anyrunning:1;
    /**
     * R -
     */
    uint32_t    allrunning:1;
    /**
     * R -
     */
    uint32_t    anyunavail:1;
    /**
     * R -
     */
    uint32_t    allunavail:1;
    /**
     * R -
     */
    uint32_t    anynonexistent:1;
    /**
     * R -
     */
    uint32_t    allnonexistent:1;
    /**
     * R -
     */
    uint32_t    anyresumeack:1;
    /**
     * R -
     */
    uint32_t    allresumeack:1;
    /**
     * R -
     */
    uint32_t    anyhavereset:1;
    /**
     * R -
     */
    uint32_t    allhavereset:1;
    uint32_t    rsv0:2;
    /**
     * R Preset
     */
    uint32_t    impebreak:1;
    uint32_t    rsv1:9;
} dm_reg_dmstatus_t;

/**
 * 3.12.2 Debug Module Control (dmcontrol, at 0x10)
 */
typedef struct _dm_reg_dmcontrol_s {
    uint32_t    dmactive:1;
    uint32_t    ndmreset:1;
    /**
     * W1
     */
    uint32_t    clrresethaltreq:1;
    /**
     * W1
     */
    uint32_t    setresethaltreq:1;
    uint32_t    rsv0:2;
    uint32_t    hartselhi:10;
    uint32_t    hartsello:10;
    uint32_t    hasel:1;
    uint32_t    rsv1:1;
    /**
     * W1
     */
    uint32_t    ackhavereset:1;
    uint32_t    hartreset:1;
    /**
     * W1
     */
    uint32_t    resumereq:1;
    /**
     * W1
     */
    uint32_t    haltreq:1;
} dm_reg_dmcontrol_t;

typedef struct _dm_reg_map_item_s {
    dm_regs_idx_t idx;      // 寄存器索引
    uint32_t phy_addr;      // 映射的寄存器物理地址
} dm_reg_map_item_t;

#endif
