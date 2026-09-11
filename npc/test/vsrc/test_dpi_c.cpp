#include <iostream>

extern "C"
{
    
#define CALL_EMPTY_FUNC(code)                                                   \
    ({                                                                          \
        printf("call empty func %s %s:%d\n", __FUNCTION__, __FILE__, __LINE__); \
        code;                                                                   \
    })


void exit_simu(int code)
{
    CALL_EMPTY_FUNC(-1);
}
void invalid_inst(int pc, int inst)
{
    CALL_EMPTY_FUNC(-1);
}
void dpi_cpu_stat_ctrl(int dtype, int delta)
{
    CALL_EMPTY_FUNC(-1);
}
int fetch_inst(int addr)
{
    return CALL_EMPTY_FUNC(-1);
}
void write_raw_mem(int addr, int len, int inst)
{
    CALL_EMPTY_FUNC(-1);
}
int read_raw_mem(int addr, int len)
{
    return CALL_EMPTY_FUNC(-1);
}
int get_reset_pc()
{
    return CALL_EMPTY_FUNC(-1);
}
int sext(int x, int len)
{
    return CALL_EMPTY_FUNC(-1);
}
void write_raw_csr(int idx, int data)
{
    CALL_EMPTY_FUNC(-1);
}
int read_raw_csr(int idx)
{
    return CALL_EMPTY_FUNC(-1);
}
int dpi_raise_intr(int NO, int epc)
{
    return CALL_EMPTY_FUNC(-1);
}
int dpi_query_intr()
{
    return CALL_EMPTY_FUNC(-1);
}
void dpi_uart_write(int addr, int len, int inst)
{
    CALL_EMPTY_FUNC(-1);
}
int dpi_rtc_read(int addr, int len)
{
    return CALL_EMPTY_FUNC(-1);
}
void dpi_dev_skip(int write, int addr, int req_info, int data)
{
    CALL_EMPTY_FUNC(-1);
}
int dpi_test_intf(int write, int addr, int len, int data)
{
    return CALL_EMPTY_FUNC(-1);
}
void dpi_psram_write(int addr, int len, int data)
{
    CALL_EMPTY_FUNC(-1);
}
int dpi_psram_read(int addr, int len)
{
    return CALL_EMPTY_FUNC(-1);
}
int dpi_check_dev_addr(int addr, int attr)
{
    return CALL_EMPTY_FUNC(-1);
}
int dpi_vdev_read(int addr, int len)
{
    return CALL_EMPTY_FUNC(-1);
}
void dpi_vdev_write(int addr, int data, int len)
{
    CALL_EMPTY_FUNC(-1);
}
void dpi_add_monitor_item(int mid, int pc, int arg)
{
    CALL_EMPTY_FUNC(-1);
}

}
