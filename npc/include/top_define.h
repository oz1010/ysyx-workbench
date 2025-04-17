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

#define TOP_S_X concat5(TOP_NAME, __DOT__, TOP_CORE0_NAME, __DOT__, wbu__DOT__x)
#define TOP_S_PC concat5(TOP_NAME, __DOT__, TOP_CORE0_NAME, __DOT__, wbu__DOT__pc)

#endif
