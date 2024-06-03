#include <iostream>
#include "svdpi.h"
#include "Vtop__Dpi.h"

void exit_simu(int code)
{
    std::cout<< "Normal exit simu with " <<code <<std::endl;
    exit(code);
}

void invalid_inst(int pc, int inst)
{
    std::cout<< "Invalid inst 0x" <<std::hex <<inst <<" at 0x" <<pc <<std::endl;
    exit(-1);
}
