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

#define R(i) gpr(i)
#define Mr vaddr_read
#define Mw vaddr_write

enum {
  TYPE_I, TYPE_U, TYPE_S, TYPE_J, TYPE_B, TYPE_R,
  TYPE_N, // none
};

#define src1R() do { *src1 = R(rs1); } while (0)
#define src2R() do { *src2 = R(rs2); } while (0)
#define immI() do { *imm = SEXT(BITS(i, 31, 20), 12); } while(0)
#define immU() do { *imm = SEXT(BITS(i, 31, 12), 20) << 12; } while(0)
#define immS() do { *imm = (SEXT(BITS(i, 31, 25), 7) << 5) | BITS(i, 11, 7); } while(0)
#define immJ() do { *imm = (SEXT(BITS(i, 31, 31), 2) << 20) | (SEXT(BITS(i, 30, 21), 11) << 1) | (SEXT(BITS(i, 20, 20), 2) << 11) | (SEXT(BITS(i, 19, 12), 9) << 12); } while(0)
#define immB() do { *imm = (SEXT(BITS(i, 31, 31), 2) << 12) | (SEXT(BITS(i, 30, 25), 7) << 5) | (SEXT(BITS(i, 11, 8), 5) << 1) | (SEXT(BITS(i, 7, 7), 2) << 11); } while(0)
#define immR() do { *imm = 0; } while(0)

#define unsigned_lt(a,b) (a<b)
#define signed_lt(a,b) do{printf("unimplement signed_lt\n");exit(-1);}while(0)

static void decode_operand(Decode *s, int *rd, word_t *src1, word_t *src2, word_t *imm, int type) {
  uint32_t i = s->isa.inst.val;
  int rs1 = BITS(i, 19, 15);
  int rs2 = BITS(i, 24, 20);
  *rd     = BITS(i, 11, 7);
  switch (type) {
    case TYPE_I: src1R();          immI(); break;
    case TYPE_U:                   immU(); break;
    case TYPE_S: src1R(); src2R(); immS(); break;
    case TYPE_J:                   immJ(); break;
    case TYPE_B: src1R(); src2R(); immB(); break;
    case TYPE_R: src1R(); src2R(); immR(); break;
  }
}

// static void exec_temp(Decode*s, int *_rd, word_t *_src1, word_t *_src2, word_t*_imm)
// {
//   int rd = *_rd;
//   word_t src1 = *_src1;
//   word_t src2 = *_src2;
//   word_t imm = *_imm;
//   printf("=== inst:%#010x rd:%d src1:%#x src2:%#x imm:%#x\n", s->isa.inst.val, rd, src1, src2, imm);

//   // uint32_t ex0 = SEXT(imm, 12);
//   // R(rd) = src1 + SEXT(imm, 12);
//   // printf("=== ex0 %x\n", ex0);

//   R(rd) = s->pc + 4; s->dnpc = (src1 + SEXT(imm, 12))&~1;
//   // printf("=== ex0 %x\n", ex0);

//   // exit(-1);
// }

static int decode_exec(Decode *s) {
  int rd = 0;
  word_t src1 = 0, src2 = 0, imm = 0;
  s->dnpc = s->snpc;

#define INSTPAT_INST(s) ((s)->isa.inst.val)
#define INSTPAT_MATCH(s, name, type, ... /* execute body */ ) { \
  decode_operand(s, &rd, &src1, &src2, &imm, concat(TYPE_, type)); \
  __VA_ARGS__ ; \
}

  INSTPAT_START();
  // RV32I ref. RISC-V开放架构设计之道-V1.0.0 p16
  // INSTPAT("??????? ????? ????? 000 ????? 00000 00", xxx    , I, exec_temp(s,&rd,&src1,&src2,&imm) );
  INSTPAT("??????? ????? ????? ??? ????? 01101 11", lui    , U, R(rd) = imm );
  INSTPAT("??????? ????? ????? ??? ????? 00101 11", auipc  , U, R(rd) = s->pc + imm );
  // INSTPAT("??????? ????? ????? ??? ????? 11011 11", jal    , J, R(rd) = s->pc+4; s->dnpc += (imm - ((s->isa.inst.val&0x80000000)?(2*1024*1024):0)) );
  INSTPAT("??????? ????? ????? ??? ????? 11011 11", jal    , J, R(rd) = s->pc + 4; s->dnpc = s->pc + SEXT(imm, 21) );
  INSTPAT("??????? ????? ????? 000 ????? 11001 11", jalr   , I, R(rd) = s->pc + 4; s->dnpc = (src1 + SEXT(imm, 12))&~1 );
  INSTPAT("??????? ????? ????? 000 ????? 11000 11", beq    , B, if (src1 == src2) s->dnpc = s->pc + SEXT(imm, 13) );
  INSTPAT("??????? ????? ????? 001 ????? 11000 11", bne    , B, if (src1 != src2) s->dnpc = s->pc + SEXT(imm, 13) );
  // INSTPAT("??????? ????? ????? ??? ????? 00101 11", blt    , B, xxx );
  // INSTPAT("??????? ????? ????? ??? ????? 00101 11", bge    , B, xxx );
  INSTPAT("??????? ????? ????? 110 ????? 11000 11", bltu   , B, if (unsigned_lt(src1,src2)) s->dnpc = s->pc + SEXT(imm, 13) );
  // INSTPAT("??????? ????? ????? ??? ????? 00101 11", bgeu   , B, xxx );
  // INSTPAT("??????? ????? ????? ??? ????? 00101 11", lb     , I, xxx );
  // INSTPAT("??????? ????? ????? ??? ????? 00101 11", lh     , I, xxx );
  INSTPAT("??????? ????? ????? 010 ????? 00000 11", lw     , I, R(rd) = Mr(src1 + imm, 4) );
  INSTPAT("??????? ????? ????? 100 ????? 00000 11", lbu    , I, R(rd) = Mr(src1 + imm, 1) );
  // INSTPAT("??????? ????? ????? ??? ????? 00101 11", lhu    , I, xxx );
  INSTPAT("??????? ????? ????? 000 ????? 01000 11", sb     , S, Mw(src1 + imm, 1, src2) );
  // INSTPAT("??????? ????? ????? 000 ????? 01000 11", sh     , S, xxx );
  INSTPAT("??????? ????? ????? 010 ????? 01000 11", sw     , S, Mw(src1 + imm, 4, src2) );
  INSTPAT("??????? ????? ????? 000 ????? 00100 11", addi   , I, R(rd) = src1 + SEXT(imm, 12) );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", slti   , I, xxx );
  INSTPAT("??????? ????? ????? 011 ????? 00100 11", sltiu  , I, R(rd) = src1 < ((word_t)SEXT(imm, 12)) );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", xori   , I, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", ori    , I, xxx );
  INSTPAT("??????? ????? ????? 111 ????? 00100 11", andi   , I, R(rd) = src1 & SEXT(imm, 32) );
  INSTPAT("0000000 ????? ????? 001 ????? 00100 11", slli   , I, R(rd) = src1 << imm );
  INSTPAT("0000000 ????? ????? 101 ????? 00100 11", srli   , I, R(rd) = src1 >> (src2 & 0x1F) );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", srai   , I, xxx );
  INSTPAT("0000000 ????? ????? 000 ????? 01100 11", add    , R, R(rd) = src1 + src2 );
  INSTPAT("0100000 ????? ????? 000 ????? 01100 11", sub    , R, R(rd) = src1 - src2 );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", sll    , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", slt    , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", sltu   , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", xor    , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", srl    , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", sra    , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", or     , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", and    , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", fence  , I, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", fence.i, I, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", ecall  , I, xxx );
  INSTPAT("0000000 00001 00000 000 00000 11100 11", ebreak , I, NEMUTRAP(s->pc, R(10))); // R(10) is $a0
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", csrrw  , I, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", csrrs  , I, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", csrrc  , I, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", csrrwi , I, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", csrrsi , I, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", csrrci , I, xxx );

  // RV32M ref. RISC-V开放架构设计之道-V1.0.0 p45
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", mul    , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", mulh   , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", mulhsu , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", mulhu  , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", div    , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", divu   , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", rem    , R, xxx );
  // INSTPAT("??????? ????? ????? 000 ????? 00100 11", remu   , R, xxx );

  INSTPAT("??????? ????? ????? ??? ????? ????? ??", inv    , N, INV(s->pc));
  INSTPAT_END();

  R(0) = 0; // reset $zero to 0

  return 0;
}

int isa_exec_once(Decode *s) {
  s->isa.inst.val = inst_fetch(&s->snpc, 4);
  return decode_exec(s);
}
