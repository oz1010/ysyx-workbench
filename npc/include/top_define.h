#ifndef __TOP_DEFINE_H__
#define __TOP_DEFINE_H__

#include "macro.h"

#ifndef TOP_NAME
#error You need macro TOP_NAME firstly
#endif

#define TOP_DPI_HEADER_FILE str(concat3(V, TOP_NAME, __Dpi.h))
#include TOP_DPI_HEADER_FILE

#define TOP_HEADER_FILE str(TOP_FILE)
#include TOP_HEADER_FILE

#define TOP_ROOT_HEADER_FILE str(concat3(V, TOP_NAME, ___024root.h))
#include TOP_ROOT_HEADER_FILE

#define TOP_ROOT_CLASS concat(V, TOP_NAME)
#define TOP_STR str(TOP_NAME)

#define TOP_CORE0_NAME ysyx_23060295_CORE0
#define TOP_S_X concat4(TOP_NAME, __DOT__asic__DOT__cpu__DOT__cpu__DOT__, TOP_CORE0_NAME, __DOT__m_gprs__DOT__x)
#define TOP_S_PC concat4(TOP_NAME, __DOT__asic__DOT__cpu__DOT__cpu__DOT__, TOP_CORE0_NAME, __DOT__wbu__DOT__pc)
#define TOP_S_CORE_INST_DONE concat3(TOP_NAME, __DOT__asic__DOT__cpu__DOT__cpu__DOT__, core_inst_done)
#define TOP_ASIC_AXI4RAM_MEMORY concat(TOP_NAME, __DOT__asic__DOT__axi4ram__DOT__mem_ext__DOT__Memory)

#endif
