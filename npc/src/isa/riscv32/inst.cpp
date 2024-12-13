/***************************************************************************************
 * Copyright (c) 2014-2022 Zihao Yu, Nanjing University
 *
 * NEMU is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 *          http://license.coscl.org.cn/MulanPSL2
 *
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
 * EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
 * MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 *
 * See the Mulan PSL v2 for more details.
 ***************************************************************************************/

#include "local-include/reg.h"
#include <cpu/cpu.h>
#include <cpu/ifetch.h>
#include <cpu/decode.h>

#include "generated/autoconf.h"
#include "dm/dtm.h"
extern CPU_state cpu;

extern int exec_vsimu(Decode *s);

int isa_exec_once(Decode *s)
{
#if CONFIG_DEBUG_MODULE
    // read instruction before debug
    vaddr_t snpc1 = s->snpc;
    s->isa.inst.val = inst_fetch(&snpc1, 4);
    dtm_update(DM_EXEC_INST_BEFORE, s->isa.inst.val, &cpu);

    // read instruction before execution
    vaddr_t snpc2 = s->snpc;
    s->isa.inst.val = inst_fetch(&snpc2, 4);
    s->snpc = snpc2;
#else
    s->isa.inst.val = inst_fetch(&s->snpc, 4);
#endif

    int ret = exec_vsimu(s);
    IFDEF(CONFIG_DEBUG_MODULE, dtm_update(DM_EXEC_INST_AFTER, s->isa.inst.val, &cpu));

    return ret;
}
