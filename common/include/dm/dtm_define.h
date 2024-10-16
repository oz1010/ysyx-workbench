#ifndef __DTM_DEFINE_H__
#define __DTM_DEFINE_H__

#include <stdint.h>
#include <assert.h>
#include <string.h>
#include <stdbool.h>

#define DTM_MSG_PREFIX              0x55443322
#define DTM_MSG_POSTFIX             0xFFEEDDCC
#define DTM_MSG_BODY_MAX            128

#define DTM_MSG_PARSE_VALUE(TYPE, NAME) TYPE NAME=*(TYPE *)body_data;body_data+=sizeof(TYPE);(void)NAME
#define DTM_MSG_PARSE_ARRAY(TYPE, NAME, SIZE) TYPE NAME=(TYPE)body_data;body_data+=(SIZE);(void)NAME
#define DTM_MSG_IDCODE_VALUE(VERSION, PART_NUM, MANUF_BANK, MANUF_ID) (uint32_t)(((VERSION)&0xF)<<28 | ((PART_NUM)&0xFFFF)<<12 | ((MANUF_BANK)&0xF)<<8 | ((MANUF_ID)&0x7F)<<1 | 1)

// dtm通信消息头部
typedef struct _dtm_msg_header_s
{
    uint32_t prefix;    // 消息前缀
    int32_t num_bytes;   // 消息体字节长度
    union {
        int32_t count;  // 已经接收消息体总长度，当长度小于0时，说明之前未解析到消息头部
        int client_fd;  // 消息客户端文件描述符。接收完成后，count没有其他用处。
    };
    uint32_t postfix;   // 消息后缀
} dtm_msg_header_t;
/**
 * dtm通信消息
 * 基本请求格式：命令类型(1) | 请求数据(xx)
 * 基本响应格式：命令类型(1) | 响应数据(xx)
 * scan消息：
 *   请求：ir(1) | fields(4) | {bits(4) | value(bits/8)}(fileds)
 *   响应：{val_bytes(1) | value(val_bytes)}(fileds)
 */
typedef struct _dtm_msg_s
{
    dtm_msg_header_t header;
    union {
        uint8_t body[DTM_MSG_BODY_MAX];
    };
} dtm_msg_t;

static inline int dtm_msg_package_body(dtm_msg_t *msg, const void *data, int data_bytes
)
{
	dtm_msg_header_t *msg_header = &msg->header;
	uint8_t *msg_body = &msg->body[0];

	assert(data_bytes <= (DTM_MSG_BODY_MAX - msg_header->num_bytes) && "found large data into package");

	memcpy(&msg_body[msg_header->num_bytes], data, data_bytes);
	msg_header->prefix = DTM_MSG_PREFIX;
	msg_header->num_bytes += data_bytes;
	msg_header->postfix = DTM_MSG_POSTFIX;

    return 0;
}

static inline void dtm_msg_reset(dtm_msg_t *msg)
{
    memset(msg, -1, sizeof(dtm_msg_t));
    msg->header.count = -1;
}

static inline void dtm_msg_init(dtm_msg_t *msg)
{
    dtm_msg_header_t *msg_header = &msg->header;
    
    memset(msg, 0, sizeof(dtm_msg_t));
    msg_header->prefix = DTM_MSG_PREFIX;
	msg_header->postfix = DTM_MSG_POSTFIX;
}

#endif
