#ifndef __TOP_DEFINE_H__
#define __TOP_DEFINE_H__

#include "macro.h"

#ifndef TOP_NAME
#error You need macro TOP_NAME firstly
#endif

#define TOP_DPI_HEADER_FILE str(concat(TOP_NAME, __Dpi.h))
#include TOP_DPI_HEADER_FILE

#define TOP_ROOT_HEADER_FILE str(concat(TOP_NAME, ___024root.h))
#include TOP_ROOT_HEADER_FILE

#define TOP_ROOT_CLASS concat(TOP_NAME, ___024root)

#endif
