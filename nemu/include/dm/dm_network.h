#ifndef __DM_NETWORK_H__
#define __DM_NETWORK_H__

#include <stdint.h>
#include <pthread.h>

#include <dm/dm_interface.h>

#define DMN_MSG_QUEUE_MAX       32
#define DMN_MSG_QUEUE_MASK      (DMN_MSG_QUEUE_MAX - 1)

#if ((DMN_MSG_QUEUE_MAX-1) & DMN_MSG_QUEUE_MAX)
#error DMN_MSG_QUEUE_MAX must be an exponent of 2
#endif

typedef struct _dm_msg_queue_s
{
    pthread_mutex_t mutex;
    uint32_t w_cnt;
    uint32_t r_cnt;
    dm_msg_t msgs[DMN_MSG_QUEUE_MAX];
} dm_msg_queue_t;

extern dm_msg_queue_t dm_msg_queue;

int init_dm_network();
int dm_msg_queue_push(dm_msg_queue_t *q, dm_msg_t *msg);
int dm_msg_queue_pop(dm_msg_queue_t *q, dm_msg_t *msg);

#endif
