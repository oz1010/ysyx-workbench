#ifndef __DM_DEFINE_H__
#define __DM_DEFINE_H__

#include <stdint.h>
#include <assert.h>
#include <string.h>
#include <stdbool.h>

#define DM_ARRAY_SIZE(A) (sizeof(A)/sizeof(A[0]))

/**
 * ref. The RISC-V Instruction Set Manual Volume II - Privileged Architecture
 *   2.2 CSR Listing
 */
#define std_ri_mstatus                      0x300
#define std_ri_misa                         0x301

/**
 * ref. RISC-V External Debug Support Version 0.13.2 
 *   4.8 Core Debug Registers
 */
// 4.8.1 Debug Control and Status (dcsr, at 0x7b0)
#define cd_ri_dcsr                          0x7b0
// 4.8.2 Debug PC (dpc, at 0x7b1)
#define cd_ri_dpc                           0x7b1
// 4.8.3 Debug Scratch Register 0 (dscratch0, at 0x7b2)
#define cd_ri_dscratch0                     0x7b0
// 4.8.4 Debug Scratch Register 1 (dscratch1, at 0x7b3)
#define cd_ri_dscratch1                     0x7b0

/**
 * ref. RISC-V External Debug Support Version 0.13.2 
 *   5.2 Trigger Registers
 */
#define tm_ri_tselect                       0x7a0
#define tm_ri_tdata1                        0x7a1
#define tm_ri_mcontrol                      0x7a1
#define tm_ri_icount                        0x7a1
#define tm_ri_itrigger                      0x7a1
#define tm_ri_etrigger                      0x7a1
#define tm_ri_tdata2                        0x7a2
#define tm_ri_tdata3                        0x7a3
#define tm_ri_textra32                      0x7a3
#define tm_ri_textra64                      0x7a3
#define tm_ri_tinfo                         0x7a4
#define tm_ri_tcontrol                      0x7a5
#define tm_ri_mcontext                      0x7a8
#define tm_ri_scontext                      0x7aa

#define TM_TRIGER_COUNT                     6

/**
 * ref. RISC-V External Debug Support Version 0.13.2
 */
typedef enum {
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

typedef enum {
    dm_ds_none,                 // 非调试状态，也没有开启调试模块
    dm_ds_init,                 // 非调试状态，正在初始化调试模块
    dm_ds_mus_mode,             // 非调试状态，核正在正常运行

    dm_ds_halting,              // 暂停/恢复状态，正在处理暂停请求或断点中断
    dm_ds_halted_waiting,       // 暂停/恢复状态，等待暂停处理
    dm_ds_resuming,             // 暂停/恢复状态，正在处理恢复请求

    dm_ds_command_start,        // 访问寄存器抽象命令状态，开始命令执行
    dm_ds_command_transfer,     // 访问寄存器抽象命令状态，传输数据
    dm_ds_command_done,         // 访问寄存器抽象命令状态，完成命令执行
    dm_ds_command_progbuf,      // 程序缓存执行状态，执行抽象命令

    dm_ds_error_detected,       // 抽象命令错误状态，检测到错误
    dm_ds_error_wait,           // 抽象命令错误状态，等待错误处理

    dm_ds_quick_access_halt,    // 快速访问抽象命令状态，暂停处理
    dm_ds_quick_access_resume,  // 快速访问抽象命令状态，恢复处理
    dm_ds_quick_access_exec,    // 程序缓存执行状态，执行快速访问命令
} dm_debug_status_t;

/**
 * 3.12.1 Debug Module Status (dmstatus, at 0x11)
 */
typedef union {
    struct {
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
    };

    uint32_t raw_value;
} dm_reg_dmstatus_t;

/**
 * 3.12.2 Debug Module Control (dmcontrol, at 0x10)
 */
typedef union {
    struct {
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
    };

    uint32_t raw_value;
} dm_reg_dmcontrol_t;

/**
 * 3.12.3 Hart Info (hartinfo, at 0x12)
 */
typedef union {
    struct {
        uint32_t    dataaddr:12;
        uint32_t    datasize:4;
        uint32_t    dataaccess:1;
        uint32_t    reserve0:3;
        uint32_t    nscratch:4;
        uint32_t    reserve1:8;
    };

    uint32_t raw_value;
} dm_reg_hartinfo_t;

/**
 * 3.12.6 Abstract Control and Status (abstractcs, at 0x16)
 */
typedef union {
    struct {
        uint32_t    datacount:4;
        uint32_t    reserve0:4;

        /**
         * Gets set if an abstract command fails. The bits in this field remain set until they are cleared by writing 1 
         * to them. No abstract command is started until the value is reset to 0. This field only contains a valid 
         * value if busy is 0.
         * 0 (none): No error.
         * 1 (busy): An abstract command was executing while command, abstractcs, or abstractauto was written, or when 
         * one of the data or progbuf registers was read or written. This status is only written if cmderr contains 0.
         * 2 (not supported): The requested command is not supported, regardless of whether the hart is running or not.
         * 3 (exception): An exception occurred while executing the command (e.g. while executing the Program Buffer).
         * 4 (halt/resume): The abstract command couldn’t execute because the hart wasn’t in the required state 
         * (running/halted), or unavailable.
         * 5 (bus): The abstract command failed due to a bus error (e.g. alignment, access size, or timeout).
         * 7 (other): The command failed for another reason.
         */
        uint32_t    cmderr:3;
        uint32_t    reserve1:1;
        uint32_t    busy:1;
        uint32_t    reserve2:11;
        uint32_t    progbufsize:5;
        uint32_t    reserve3:3;
    };

    uint32_t raw_value;
} dm_reg_abstractcs_t;
#define DM_ABSTRACTCS_CMDERR_NONE               0
#define DM_ABSTRACTCS_CMDERR_BUSY               1
#define DM_ABSTRACTCS_CMDERR_NOT_SUPPORTED      2
#define DM_ABSTRACTCS_CMDERR_EXCEPTION          3
#define DM_ABSTRACTCS_CMDERR_HALT_OR_RESUME     4
#define DM_ABSTRACTCS_CMDERR_BUS                5
#define DM_ABSTRACTCS_CMDERR_OTHER              7

/**
 * 3.12.7 Abstract Command (command, at 0x17)
 */
typedef union {
    struct {
        /**
         * W
         */
        uint32_t control:24;
        /**
         * 0 Access Register Command
         * 1 Quick Access
         * 2 Access Memory Command
         * W
         */
        uint32_t cmdtype:8;
    };

    /**
     * 3.6.1.1 Access Register
     */
    struct {
        uint32_t regno:16;
        uint32_t write:1;
        uint32_t transfer:1;
        uint32_t postexec:1;
        uint32_t aarpostincrement:1;
        uint32_t aarsize:3;
        uint32_t reserve0:1;

        /**
         * type is 0
         * W
         */
        uint32_t cmdtype:8;
    } reg;
    
    /**
     * 3.6.1.2 Quick Access
     */
    struct {
        uint32_t reserve0:24;

        /**
         * type is 1
         * W
         */
        uint32_t cmdtype:8;
    } quick;
    
    /**
     * 3.6.1.3 Access Memory
     */
    struct {
        uint32_t reserve0:14;
        uint32_t target_specific:2;
        uint32_t write:1;
        uint32_t reserve1:2;
        uint32_t aampostincrement:1;

        /**
         * 3.6.1.3 Access Memory
         * 0: Access the lowest 8 bits of the memory location.
         * 1: Access the lowest 16 bits of the memory location.
         * 2: Access the lowest 32 bits of the memory location.
         * 3: Access the lowest 64 bits of the memory location.
         * 4: Access the lowest 128 bits of the memory location.
         */
        uint32_t aamsize:3;
        uint32_t aamvirtual:1;

        /**
         * type is 2
         * W
         */
        uint32_t cmdtype:8;
    } memory;

    uint32_t raw_value;
} dm_reg_command_t;

#define DM_COMMAND_MEMORY_AAMSIZE_8bits             0
#define DM_COMMAND_MEMORY_AAMSIZE_16bits            1
#define DM_COMMAND_MEMORY_AAMSIZE_32bits            2
#define DM_COMMAND_MEMORY_AAMSIZE_64bits            3
#define DM_COMMAND_MEMORY_AAMSIZE_128bits           4

typedef struct {
    dm_regs_idx_t idx;      // 寄存器索引
    uint32_t phy_addr;      // 映射的寄存器物理地址
} dm_reg_map_item_t;

/**
 * 3.1.6 Machine Status Registers (mstatus and mstatush)
 *   0x300
 */
typedef union {
    struct {
        uint32_t            reserve0:1;
        uint32_t            sie:1;
        uint32_t            reserve1:1;
        uint32_t            mie:1;
        uint32_t            reserve2:1;
        uint32_t            spie:1;
        uint32_t            ube:1;
        uint32_t            mpie:1;
        uint32_t            spp:1;

        /**
         * 3.1.6.6 Extension Context Status in mstatus Register
         *   Status --  FS and VS Meaning
         *   0 --       Off
         *   1 --       Initial
         *   2 --       Clean
         *   3 --       Dirty
         */
        uint32_t            vs:2;

        uint32_t            mpp:2;

        /**
         * 3.1.6.6 Extension Context Status in mstatus Register
         *   Status --  FS and VS Meaning
         *   0 --       Off
         *   1 --       Initial
         *   2 --       Clean
         *   3 --       Dirty
         */
        uint32_t            fs:2;

        /**
         * 3.1.6.6 Extension Context Status in mstatus Register
         *   Status --  XS Meaning
         *   0 --       All off
         *   1 --       None dirty or clean, some on
         *   2 --       None dirty, some clean
         *   3 --       Some dirty
         */
        uint32_t            xs:2;

        uint32_t            mprv:1;
        uint32_t            sum:1;
        uint32_t            mxr:1;
        uint32_t            tvm:1;
        uint32_t            tw:1;
        uint32_t            tsr:1;
        uint32_t            reserve3:8;
        uint32_t            sd:1;
    };

    uint32_t raw_value;
} std_reg_mstatus_t;

/**
 * 3.1.1 Machine ISA Register misa
 *   0x301
 */
typedef union {
    struct {
        uint32_t        extensions:26;
        uint32_t        reserve0:4;

        /**
         * The MXL (Machine XLEN) field encodes the native base integer ISA width
         * MXL --   XLEN
         * 1 --     32
         * 2 --     64
         * 3 --     128
         */
        uint32_t        mxl:2;
    };

    uint32_t raw_value;
} std_reg_misa_t;

#define STD_MISA_MXL_32             1
#define STD_MISA_MXL_64             2
#define STD_MISA_MXL_128            3

/**
 * 4.8.1 Debug Control and Status (dcsr, at 0x7b0)
 */
typedef union {
    struct {
        uint32_t    prv:2;
        uint32_t    step:1;
        uint32_t    nmip:1;
        uint32_t    mprven:1;
        uint32_t    reserve0:1;
        /**
         * Explains why Debug Mode was entered. When there are multiple reasons to enter Debug Mode in a single cycle, 
         * hardware should set cause to the cause with the highest priority.
         * 1: An ebreak instruction was executed. (priority 3)
         * 2: The Trigger Module caused a breakpoint exception. (priority 4, highest)
         * 3: The debugger requested entry to Debug Mode using haltreq. (priority 1)
         * 4: The hart single stepped because step was set. (priority 0, lowest)
         * 5: The hart halted directly out of reset due to resethaltreq. It is also acceptable to report 3 when this 
         * happens. (priority 2)
         * Other values are reserved for future use.
         */
        uint32_t    cause:3;
        uint32_t    stoptime:1;
        uint32_t    stopcount:1;
        uint32_t    stepie:1;
        uint32_t    ebreaku:1;
        uint32_t    ebreaks:1;
        uint32_t    reserve1:1;
        uint32_t    ebreakm:1;
        uint32_t    reserve2:12;
        uint32_t    xdebugver:4;
    };

    uint32_t raw_value;
} cd_reg_dcsr_t;

#define CD_DCSR_CAUSE_EBREAK            1
#define CD_DCSR_CAUSE_BREAKPOINT_EX     2
#define CD_DCSR_CAUSE_HALTREQ           3
#define CD_DCSR_CAUSE_STEP              4
#define CD_DCSR_CAUSE_RESET             5

/**
 * 4.8.2 Debug PC (dpc, at 0x7b1)
 */
typedef union {
    uint32_t raw_value;
} cd_reg_dpc_t;

/**
 * 5.2.1 Trigger Select (tselect, at 0x7a0)
 */
typedef union {
    struct {
        uint32_t    index;
    };
    
    uint32_t raw_value;
} tm_reg_tselect_t;

/**
 * 5.2.2 Trigger Data 1 (tdata1, at 0x7a1)
 */
typedef union {
    struct {
        uint32_t    data:27;
        uint32_t    dmode:1;

        /**
         * 0: There is no trigger at this tselect.
         * 1: The trigger is a legacy SiFive address match trigger. These should not be implemented and aren’t further documented here.
         * 2: The trigger is an address/data match trigger. The remaining bits in this register act as described in mcontrol.
         * 3: The trigger is an instruction count trigger. The remaining bits in this register act as described in icount.
         * 4: The trigger is an interrupt trigger. The remaining bits in this register act as described in itrigger.
         * 5: The trigger is an exception trigger. The remaining bits in this register act as described in etrigger.
         * 15: This trigger exists (so enumeration shouldn’t terminate), but is not currently available.
         * Other values are reserved for future use.
         */
        uint32_t    type:4;
    };
    
    uint32_t raw_value;
} tm_reg_tdata1_t;

#define TM_TDATA1_NONE                      0
#define TM_TDATA1_LEGACY_SIFIVE             1
#define TM_TDATA1_ADDR_OR_DATA              2
#define TM_TDATA1_ICOUNT                    3
#define TM_TDATA1_INTERRUPT                 4
#define TM_TDATA1_EXCEPTION                 5
#define TM_TDATA1_EXISTS                    15

#define TM_TDATA1_MASK_NONE                 (1<<TM_TDATA1_NONE)
#define TM_TDATA1_MASK_LEGACY_SIFIVE        (1<<TM_TDATA1_LEGACY_SIFIVE)
#define TM_TDATA1_MASK_ADDR_OR_DATA         (1<<TM_TDATA1_ADDR_OR_DATA)
#define TM_TDATA1_MASK_ICOUNT               (1<<TM_TDATA1_ICOUNT)
#define TM_TDATA1_MASK_INTERRUPT            (1<<TM_TDATA1_INTERRUPT)
#define TM_TDATA1_MASK_EXCEPTION            (1<<TM_TDATA1_EXCEPTION)
#define TM_TDATA1_MASK_EXISTS               (1<<TM_TDATA1_EXISTS)

/**
 * 
 */
typedef union {
    struct {
        uint32_t            load:1;
        uint32_t            store:1;
        uint32_t            execute:1;
        uint32_t            u:1;
        uint32_t            s:1;
        uint32_t            reserve0:1;
        uint32_t            m:1;
        uint32_t            match:4;
        uint32_t            chain:1;
        uint32_t            action:4;
        uint32_t            sizelo:2;
        uint32_t            timing:1;
        uint32_t            select:1;
        uint32_t            hit:1;
        /*
        This field only exists if XLEN is greater than 32
        // uint32_t            sizehi:2;
        // uint32_t            reserve1:30;
        */
        uint32_t            maskmax:6;
        uint32_t            dmode:1;
        uint32_t            type:4;
    };
    
    uint32_t raw_value;
} tm_reg_mcontrol_t;

/**
 * 
 */
typedef union {
    struct {
    };
    
    uint32_t raw_value;
} tm_reg_icount_t;

/**
 * 
 */
typedef union {
    struct {
    };
    
    uint32_t raw_value;
} tm_reg_itrigger_t;

/**
 * 
 */
typedef union {
    struct {
    };
    
    uint32_t raw_value;
} tm_reg_etrigger_t;

/**
 * 
 */
typedef union {
    struct {
    };
    
    uint32_t raw_value;
} tm_reg_tdata2_t;

/**
 * 
 */
typedef union {
    struct {
    };
    
    uint32_t raw_value;
} tm_reg_tdata3_t;

/**
 * 
 */
typedef union {
    struct {
    };
    
    uint32_t raw_value;
} tm_reg_textra32_t;

/**
 * 
 */
typedef union {
    struct {
    };
    
    uint32_t raw_value;
} tm_reg_textra64_t;

/**
 * 5.2.5 Trigger Info (tinfo, at 0x7a4)
 */
typedef union {
    struct {
        uint32_t        info:16;
    };
    
    uint32_t raw_value;
} tm_reg_tinfo_t;

/**
 * 
 */
typedef union {
    struct {
    };
    
    uint32_t raw_value;
} tm_reg_tcontrol_t;

/**
 * 
 */
typedef union {
    struct {
    };
    
    uint32_t raw_value;
} tm_reg_mcontext_t;

/**
 * 
 */
typedef union {
    struct {
    };
    
    uint32_t raw_value;
} tm_reg_scontext_t;


#endif
