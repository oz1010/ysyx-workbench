#include <am.h>
#include <klib.h>
#include <klib-macros.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

void __floatsidf() {
    panic("unimplement __floatsidf");
}
void __subdf3() {
    panic("unimplement __subdf3");
}
void __fixdfsi() {
    panic("unimplement __fixdfsi");
}
void __divdf3() {
    panic("unimplement __divdf3");
}
void __fixunsdfsi() {
    panic("unimplement __fixunsdfsi");
}
void __muldf3() {
    panic("unimplement __muldf3");
}
#endif
