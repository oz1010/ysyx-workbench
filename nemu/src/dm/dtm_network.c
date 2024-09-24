#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <sys/epoll.h>
#include <pthread.h>

#include "generated/autoconf.h"
#include "dm/dtm_network.h"
#include "debug.h"

pthread_t dm_server_tid;
dtmn_msg_queue_t dtmn_msg_queue;

#define DM_SERVER_TIMEOUT_MS 100

static uint32_t dtmn_msg_queue_get_used_size(dtmn_msg_queue_t *q)
{
    uint32_t used_cnt = (q->w_cnt - q->r_cnt);
    return (used_cnt <= DTMN_MSG_QUEUE_MSGS_MAX) ? used_cnt : 0;
}

static uint32_t dtmn_msg_queue_get_free_size(dtmn_msg_queue_t *q)
{
    uint32_t free_cnt = DTMN_MSG_QUEUE_MSGS_MAX - (q->w_cnt - q->r_cnt);
    return (free_cnt <= DTMN_MSG_QUEUE_MSGS_MAX) ? free_cnt : 0;
}

int dtmn_msg_queue_push(dtmn_msg_queue_t *q, dtm_msg_t *msg)
{
    dtm_msg_t *dst_msg = NULL;

    pthread_mutex_lock(&q->mutex);
    uint32_t free_size = dtmn_msg_queue_get_free_size(q);
    if (free_size) {
        dst_msg = &q->msgs[q->w_cnt & DTMN_MSG_QUEUE_MSGS_MASK];
        ++q->w_cnt;
    }
    pthread_mutex_unlock(&q->mutex);
    
    if (dst_msg) {
        memcpy(dst_msg, msg, sizeof(dtm_msg_header_t) + msg->header.num_bytes);
    }

    if (free_size==0) {
        LOG_ERROR("msg queue full");
        return -1;
    }

    return 0;
}

int dtmn_msg_queue_pop(dtmn_msg_queue_t *q, dtm_msg_t *msg)
{
    dtm_msg_t *src_msg = NULL;

    pthread_mutex_lock(&q->mutex);
    uint32_t used_size = dtmn_msg_queue_get_used_size(q);
    if (used_size) {
        src_msg = &q->msgs[q->r_cnt & DTMN_MSG_QUEUE_MSGS_MASK];
        ++q->r_cnt;
    }
    pthread_mutex_unlock(&q->mutex);

    if (src_msg) {
        memcpy(msg, src_msg, sizeof(dtm_msg_header_t) + src_msg->header.num_bytes);
        return 0;
    }

    return -1;
}

static void dtmn_msg_parse(dtmn_msg_queue_t *q, uint8_t *buf, uint32_t *buf_idx, int client_fd)
{
    static dtm_msg_t parsed_msg = {0};

    dtm_msg_t *msg = &parsed_msg;
    uint32_t buf_size = *buf_idx;

    // 判断消息头部，若匹配中则拷贝数据至消息头部
    if (buf_size < sizeof(dtm_msg_header_t))
        return;
    int32_t find_header = (msg->header.count>=0 && msg->header.prefix==DTM_MSG_PREFIX);
    uint8_t *cur_buf = buf;
    if (!find_header) {
        size_t check_cnt = buf_size - sizeof(dtm_msg_header_t) + 1;
        for (size_t i=0; i<check_cnt; ++i, ++cur_buf) {
            dtm_msg_t *recv_msg = (dtm_msg_t *)cur_buf;
            if ((recv_msg->header.prefix == DTM_MSG_PREFIX) &&
                (recv_msg->header.num_bytes <= DTM_MSG_BODY_MAX) &&
                (recv_msg->header.postfix == DTM_MSG_POSTFIX)) {
                    find_header = 1;
                    memcpy(msg, recv_msg, sizeof(dtm_msg_header_t));
                    msg->header.count = 0;
                    cur_buf += sizeof(dtm_msg_header_t);
                    break;
            }
        }
    }

    // 若已经匹配中消息头部，拷贝数据至消息体
    // 否则跳过所有消息
    uint8_t *end_buf = &buf[buf_size - 1];
    int32_t end_size = (int32_t)(end_buf - cur_buf + 1);
    if (find_header) {
        if (msg->header.count < msg->header.num_bytes) {
            int32_t cp_cnt = msg->header.num_bytes - msg->header.count;
            assert(end_size<=buf_size);
            if (end_size>0) {
                if (cp_cnt>end_size) cp_cnt = end_size;
                memcpy(&msg->body[msg->header.count], cur_buf, cp_cnt);
                msg->header.count += cp_cnt;
                cur_buf += cp_cnt;
                end_size -= cp_cnt;
            }
        }

        // 消息解析完成，拷贝所有消息并切换到下一个体中
        if (msg->header.count == msg->header.num_bytes) {
            msg->header.client_fd = client_fd;
            dtmn_msg_queue_push(q, msg);
            dtm_msg_reset(msg);
        }
    } 
    
    // 缓存中未处理完的数据
    if (end_size) {
        if (end_size>buf_size) {
            end_size = 0;
        } else {
            int32_t i;
            for (i=0; i<end_size; ++i)
                buf[i] = cur_buf[i];
            memset(&buf[i], 0, buf_size - end_size);
        }
    }
    *buf_idx = end_size;
}

static int dtmn_data_handle(int client_fd)
{
    static uint8_t dmn_buffer[4*DTM_MSG_BODY_MAX] = {0};
    static uint32_t dmn_buffer_idx = 0;

    size_t bytes_free = sizeof(dmn_buffer) - dmn_buffer_idx;
    size_t bytes_read = 0;
    if (bytes_free)
    {
        bytes_read = recv(client_fd, &dmn_buffer[dmn_buffer_idx], bytes_free, 0);
        if (bytes_read > 0) {
            // 解析缓存协议
            dmn_buffer_idx += bytes_read;
            dtmn_msg_parse(&dtmn_msg_queue, dmn_buffer, &dmn_buffer_idx, client_fd);
        } else if (bytes_read == 0) {
            LOG_INFO("client disconnected");
            close(client_fd);
        } else {
            LOG_ERROR("recv error");
            return -1;
        }
    }

    return bytes_read;
}

static void *dtmn_server_thread(void *arg)
{
    uint16_t bind_port = 0;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_addr_len = sizeof(client_addr);
    int server_fd;

    // 创建服务器socket
    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        LOG_ERROR("socket failed");
        exit(EXIT_FAILURE);
    }

#if CONFIG_DEBUG_MODULE
    bind_port = CONFIG_DM_PORT;
#endif

    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(bind_port);

    // 设置 SO_REUSEADDR 套接字选项，允许地址重用
    int opt = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, sizeof(opt)) < 0) {
        LOG_ERROR("socket setting failed");
        close(server_fd);
        exit(EXIT_FAILURE);
    }
    
    // 绑定端口
    if (bind(server_fd, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        LOG_ERROR("bind failed");
        close(server_fd);
        exit(EXIT_FAILURE);
    }
    
    // 监听端口
    if (listen(server_fd, 1) < 0) {
        LOG_ERROR("listen failed");
        close(server_fd);
        exit(EXIT_FAILURE);
    }
    
    LOG_INFO("DM server is listening on port %d", bind_port);

    // 进入主循环
    while (1) {
        int client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_addr_len);
        if (client_fd < 0)
        {
            LOG_ERROR("accept failed");
            continue;
        }

        while(dtmn_data_handle(client_fd) > 0);
    }
    
    // 销毁套接字、互斥锁
    close(server_fd);
    pthread_mutex_destroy(&dtmn_msg_queue.mutex);

    return 0;
}

int dtmn_init()
{
    // 初始化消息队列
    memset(&dtmn_msg_queue, 0, sizeof(dtmn_msg_queue));
    pthread_mutex_init(&dtmn_msg_queue.mutex, NULL);
    for (size_t i=0; i<(sizeof(dtmn_msg_queue.msgs)/sizeof(dtmn_msg_queue.msgs[0])); ++i)
        dtm_msg_reset(&dtmn_msg_queue.msgs[i]);

    // 创建dm服务器线程
    if (pthread_create(&dm_server_tid, NULL, dtmn_server_thread, NULL) != 0) {
        LOG_ERROR("Failed to create dm server thread");
        return EXIT_FAILURE;
    }

    return 0;
}
