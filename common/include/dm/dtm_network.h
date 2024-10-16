#ifndef __DTM_NETWORK_H__
#define __DTM_NETWORK_H__

#include <stdint.h>
#include <pthread.h>

#include "dm/dm_interface.h"

#define DTMN_MSG_QUEUE_MSGS_MAX     32
#define DTMN_MSG_QUEUE_MSGS_MASK    (DTMN_MSG_QUEUE_MSGS_MAX - 1)
#define DTMN_MSG_QUEUE_MAX          4

#if ((DTMN_MSG_QUEUE_MSGS_MAX-1) & DTMN_MSG_QUEUE_MSGS_MAX)
#error DTMN_MSG_QUEUE_MSGS_MAX must be an exponent of 2
#endif

typedef struct _dtmn_msg_queue_s
{
    pthread_mutex_t mutex;
    uint32_t w_cnt;
    uint32_t r_cnt;
    dtm_msg_t msgs[DTMN_MSG_QUEUE_MSGS_MAX];
} dtmn_msg_queue_t;

extern dtmn_msg_queue_t dtmn_msg_queue;

int dtmn_init();
int dtmn_msg_queue_push(dtmn_msg_queue_t *q, dtm_msg_t *msg);
int dtmn_msg_queue_pop(dtmn_msg_queue_t *q, dtm_msg_t *msg);

#endif
