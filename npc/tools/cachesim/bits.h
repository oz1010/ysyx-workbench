#pragma once

#define BIT_MASK(n) ((1<<(n))-1)
#define GET_BITS(value, start, width) (((value)>>(start)) & BIT_MASK(width))
