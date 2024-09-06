#ifndef __DM_INTERFACE_H__
#define __DM_INTERFACE_H__

#include <stdint.h>
#include <assert.h>
#include <string.h>
#include <stdbool.h>

#define DMN_MSG_PREFIX          0x55443322
#define DMN_MSG_POSTFIX         0xFFEEDDCC
#define DMN_MSG_BODY_MAX        128

#define DMM_PARSE_VALUE(TYPE, NAME) TYPE NAME=*(TYPE *)body_data;body_data+=sizeof(TYPE);(void)NAME
#define DMM_PARSE_ARRAY(TYPE, NAME, SIZE) TYPE NAME=(TYPE)body_data;body_data+=(SIZE);(void)NAME
#define DMM_IDCODE_VALUE(VERSION, PART_NUM, MANUF_BANK, MANUF_ID) (uint32_t)(((VERSION)&0xF)<<28 | ((PART_NUM)&0xFFFF)<<12 | ((MANUF_BANK)&0xF)<<8 | ((MANUF_ID)&0x7F)<<1 | 1)

/**
 * ref. RISC-V External Debug Support Version 0.13.2
 */
typedef enum _dmr_idx_e {
    // Abstract Data 0 - 11, P30
    dmri_data0 = 0x04,
    dmri_data1,
    dmri_data2,
    dmri_data3,
    dmri_data4,
    dmri_data5,
    dmri_data6,
    dmri_data7,
    dmri_data8,
    dmri_data9,
    dmri_data10,
    dmri_data11,
    // Debug Module Control, P22
    dmri_dmcontrol,
    // Debug Module Status, P20
    dmri_dmstatus,
    // Hart Info, P25
    dmri_hartinfo,
    // Halt Summary 1, P31
    dmri_haltsum1,
    // Hart Array Window Select, P26
    dmri_hawindowsel,
    // Hart Array Window, P26
    dmri_hawindow,
    // Abstract Control and Status, P27
    dmri_abstractcs,
    // Abstract Command, P28
    dmri_command,
    // Abstract Command Autoexec, P29
    dmri_abstractauto,
    // Configuration String Pointer 0, P29
    dmri_confstrptr0,
    // Configuration String Pointer 1, P29
    dmri_confstrptr1,
    // Configuration String Pointer 2, P29
    dmri_confstrptr2,
    // Configuration String Pointer 3, P29
    dmri_confstrptr3,
    // Next Debug Module, P30
    dmri_nextdm,
    // Program Buffer 0 - 15, P30
    dmri_progbuf0 = 0x20,
    dmri_progbuf1,
    dmri_progbuf2,
    dmri_progbuf3,
    dmri_progbuf4,
    dmri_progbuf5,
    dmri_progbuf6,
    dmri_progbuf7,
    dmri_progbuf8,
    dmri_progbuf9,
    dmri_progbuf10,
    dmri_progbuf11,
    dmri_progbuf12,
    dmri_progbuf13,
    dmri_progbuf14,
    dmri_progbuf15,
    // Authentication Data, P31
    dmri_authdata,
    // Halt Summary 2, P32
    dmri_haltsum2 = 0x34,
    // Halt Summary 3, P32
    dmri_haltsum3,
    // System Bus Address 127:96, P36
    dmri_sbaddress3 = 0x37,
    // System Bus Access Control and Status, P32
    dmri_sbcs,
    // System Bus Address 31:0, P34
    dmri_sbaddress0,
    // System Bus Address 63:32, P35
    dmri_sbaddress1,
    // System Bus Address 95:64, P35
    dmri_sbaddress2,
    // System Bus Data 31:0, P36
    dmri_sbdata0,
    // System Bus Data 63:32, P37
    dmri_sbdata1,
    // System Bus Data 95:64, P37
    dmri_sbdata2,
    // System Bus Data 127:96, P38
    dmri_sbdata3,
    // Halt Summary 0, P31
    dmri_haltsum0,

    dmri_count,
} dmr_idx_t;

typedef struct _dmr_map_item_s {
    dmr_idx_t idx;      // 寄存器索引
    uint32_t phy_addr;  // 映射的寄存器物理地址
} dmr_map_item_t;

// dm通信消息体类型，参考jtag_command_type枚举
typedef enum {
    DMM_BODY_UNKNOWN        = 0,
	DMM_BODY_SCAN           = 1,
	DMM_BODY_TLR_RESET      = 2,
	DMM_BODY_RUNTEST        = 3,
	DMM_BODY_RESET          = 4,
	DMM_BODY_PATHMOVE       = 6,
	DMM_BODY_SLEEP          = 7,
	DMM_BODY_STABLECLOCKS   = 8,
	DMM_BODY_TMS            = 9,

    DMM_BODY_TYPE_MAX
} dm_msg_body_type_t;
// dm通信消息头部
typedef struct _dm_msg_header_s
{
    uint32_t prefix;    // 消息前缀
    // dm_msg_body_type_t body_type; // 消息体类型
    int32_t num_bytes;   // 消息体字节长度
    // int32_t num_bits;    // 消息体位长度
    union {
        int32_t count;  // 已经接收消息体总长度，当长度小于0时，说明之前未解析到消息头部
        int client_fd;  // 消息客户端文件描述符。接收完成后，count没有其他用处。
    };
    uint32_t postfix;   // 消息后缀
} dm_msg_header_t;
// dm通信消息，访问寄存器
// ref. RISC-V External Debug Support Version 0.13.2, 3.6.1.1 Access Register, P13
typedef struct _dm_msg_access_register_s
{
    uint32_t regno : 16;
    uint32_t write;
    uint32_t transfer;
    uint32_t postexec;
    uint32_t w;
    // uint32_t w;
    // uint32_t w;
    // uint32_t w;
} dm_msg_access_register_t;
// // dm通信消息命令
// typedef struct _dm_msg_cmd_s
// {
//     uint8_t rw;         // 0--读，1--写
//     uint8_t cmdtype;    // 0--访问寄存器，1--内存
//     uint32_t reg_idx;   // 寄存器索引
//     uint32_t reg_val;   // 寄存器值
// } dm_msg_cmd_t;
/**
 * dm通信消息
 * 基本请求格式：命令类型(1) | 请求数据(xx)
 * 基本响应格式：命令类型(1) | 响应数据(xx)
 * scan消息：
 *   请求：ir(1) | fields(4) | {bits(4) | value(bits/8)}(fileds)
 *   响应：{val_bytes(1) | value(val_bytes)}(fileds)
 */
typedef struct _dm_msg_s
{
    dm_msg_header_t header;
    union {
        uint8_t body[DMN_MSG_BODY_MAX];
    };
} dm_msg_t;

int init_dm_interface();
int dmi_read(dmr_idx_t idx, uint32_t *val);
int dmi_write(dmr_idx_t idx, uint32_t val);

static inline int dmm_package_body(dm_msg_t *msg, const void *data, int data_bytes
)
{
	dm_msg_header_t *msg_header = &msg->header;
	uint8_t *msg_body = &msg->body[0];

	assert(data_bytes <= (DMN_MSG_BODY_MAX - msg_header->num_bytes) && "found large data into package");

	memcpy(&msg_body[msg_header->num_bytes], data, data_bytes);
	msg_header->prefix = DMN_MSG_PREFIX;
	msg_header->num_bytes += data_bytes;
	msg_header->postfix = DMN_MSG_POSTFIX;

    return 0;
}

static inline void dmm_reset(dm_msg_t *msg)
{
    memset(msg, -1, sizeof(dm_msg_t));
    msg->header.count = -1;
}

static inline void dmm_init(dm_msg_t *msg)
{
    dm_msg_header_t *msg_header = &msg->header;
    
    memset(msg, 0, sizeof(dm_msg_t));
    msg_header->prefix = DMN_MSG_PREFIX;
	msg_header->postfix = DMN_MSG_POSTFIX;
}

#endif
