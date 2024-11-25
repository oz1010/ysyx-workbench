#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include "cpu/cpu-exec.h"
#include "memory/paddr.h"
#include "dm/dtm.h"

void init_monitor(int argc, char* argv[]);
void sdb_mainloop();

int main(int argc, char** argv)
{
    printf("Start NPC ...\n");

    init_monitor(argc, argv);

#ifdef CONFIG_TARGET_AM
    cpu_exec(-1);
#else
    /* Receive commands from user. */
    sdb_mainloop();
#endif

    return !(npc_ctx.state == NPC_END && npc_ctx.halt_ret == 0 || (npc_ctx.state == NPC_QUIT));
}
