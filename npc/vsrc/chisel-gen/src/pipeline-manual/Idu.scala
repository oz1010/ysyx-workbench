package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._

/** IDU：译码。
  *   - RV32I(RV32E) 基础指令集，SYSTEM 支持 ECALL/EBREAK/MRET/CSR 指令。
  */
class Idu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val in         = Flipped(Decoupled(new IfBundle(p)))
    val out        = Decoupled(new IdBundle(p))
    val gprRead1   = new OldRegReadIO(p.GPR_ADDR_W, CONFIG_ADDR_WIDTH)
    val gprRead2   = new OldRegReadIO(p.GPR_ADDR_W, CONFIG_ADDR_WIDTH)
    val gprWrite   = Flipped(new OldRegWriteIO(p.GPR_ADDR_W, CONFIG_ADDR_WIDTH))
    val loadStall  = Input(Bool()) // load-use RAW 冒险，请求 stall
    val exRedirect = Input(new Redirect(p))
    val wbRedirect = Input(new Redirect(p))
  })

  // ---------------- 译码 ----------------
  val inst   = io.in.bits.inst
  val opcode = inst(6, 0)
  val funct3 = inst(14, 12)
  val funct7 = inst(31, 25)

  val oldctrl = Wire(new OldCtrl)
  oldctrl.aluOp    := 0.U
  oldctrl.usePc    := false.B
  oldctrl.useImm   := false.B
  oldctrl.isBranch := false.B
  oldctrl.isJal    := false.B
  oldctrl.isJalr   := false.B
  oldctrl.load     := false.B
  oldctrl.store    := false.B
  oldctrl.memOp    := 0.U
  oldctrl.wbSel    := WbSel.ALU
  oldctrl.rdWen    := false.B
  oldctrl.csrOp    := 0.U
  oldctrl.csrImm   := false.B
  oldctrl.fence    := false.B
  oldctrl.ecall    := false.B
  oldctrl.ebreak   := false.B
  oldctrl.mret     := false.B
  oldctrl.illegal  := true.B

  /*
  io.inst_code := MuxCase(INST_INVALID, Seq(
    (io.inst === BitPat("b???????_?????_?????_???_?????_01101_11")) -> INST_LUI,
    (io.inst === BitPat("b???????_?????_?????_???_?????_00101_11")) -> INST_AUIPC,
    (io.inst === BitPat("b???????_?????_?????_???_?????_11011_11")) -> INST_JAL,
    (io.inst === BitPat("b???????_?????_?????_000_?????_11001_11")) -> INST_JALR,
    (io.inst === BitPat("b???????_?????_?????_000_?????_11000_11")) -> INST_BEQ,
    (io.inst === BitPat("b???????_?????_?????_001_?????_11000_11")) -> INST_BNE,
    (io.inst === BitPat("b???????_?????_?????_100_?????_11000_11")) -> INST_BLT,
    (io.inst === BitPat("b???????_?????_?????_101_?????_11000_11")) -> INST_BGE,
    (io.inst === BitPat("b???????_?????_?????_110_?????_11000_11")) -> INST_BLTU,
    (io.inst === BitPat("b???????_?????_?????_111_?????_11000_11")) -> INST_BGEU,
    (io.inst === BitPat("b???????_?????_?????_000_?????_00000_11")) -> INST_LB,
    (io.inst === BitPat("b???????_?????_?????_001_?????_00000_11")) -> INST_LH,
    (io.inst === BitPat("b???????_?????_?????_010_?????_00000_11")) -> INST_LW,
    (io.inst === BitPat("b???????_?????_?????_100_?????_00000_11")) -> INST_LBU,
    (io.inst === BitPat("b???????_?????_?????_101_?????_00000_11")) -> INST_LHU,
    (io.inst === BitPat("b???????_?????_?????_000_?????_01000_11")) -> INST_SB,
    (io.inst === BitPat("b???????_?????_?????_001_?????_01000_11")) -> INST_SH,
    (io.inst === BitPat("b???????_?????_?????_010_?????_01000_11")) -> INST_SW,
    (io.inst === BitPat("b???????_?????_?????_000_?????_00100_11")) -> INST_ADDI,
    (io.inst === BitPat("b???????_?????_?????_010_?????_00100_11")) -> INST_SLTI,
    (io.inst === BitPat("b???????_?????_?????_011_?????_00100_11")) -> INST_SLTIU,
    (io.inst === BitPat("b???????_?????_?????_100_?????_00100_11")) -> INST_XORI,
    (io.inst === BitPat("b???????_?????_?????_110_?????_00100_11")) -> INST_ORI,
    (io.inst === BitPat("b???????_?????_?????_111_?????_00100_11")) -> INST_ANDI,
    (io.inst === BitPat("b0000000_?????_?????_001_?????_00100_11")) -> INST_SLLI,
    (io.inst === BitPat("b0000000_?????_?????_101_?????_00100_11")) -> INST_SRLI,
    (io.inst === BitPat("b0100000_?????_?????_101_?????_00100_11")) -> INST_SRAI,
    (io.inst === BitPat("b0000000_?????_?????_000_?????_01100_11")) -> INST_ADD,
    (io.inst === BitPat("b0100000_?????_?????_000_?????_01100_11")) -> INST_SUB,
    (io.inst === BitPat("b0000000_?????_?????_001_?????_01100_11")) -> INST_SLL,
    (io.inst === BitPat("b0000000_?????_?????_010_?????_01100_11")) -> INST_SLT,
    (io.inst === BitPat("b0000000_?????_?????_011_?????_01100_11")) -> INST_SLTU,
    (io.inst === BitPat("b0000000_?????_?????_100_?????_01100_11")) -> INST_XOR,
    (io.inst === BitPat("b0000000_?????_?????_101_?????_01100_11")) -> INST_SRL,
    (io.inst === BitPat("b0100000_?????_?????_101_?????_01100_11")) -> INST_SRA,
    (io.inst === BitPat("b0000000_?????_?????_110_?????_01100_11")) -> INST_OR,
    (io.inst === BitPat("b0000000_?????_?????_111_?????_01100_11")) -> INST_AND,
    (io.inst === BitPat("b0000000_00000_00000_001_00000_00011_11")) -> INST_FENCE_I,
    (io.inst === BitPat("b0000000_00000_00000_000_00000_11100_11")) -> INST_ECALL,
    (io.inst === BitPat("b0000000_00001_00000_000_00000_11100_11")) -> INST_EBREAK,
    (io.inst === BitPat("b???????_?????_?????_001_?????_11100_11")) -> INST_CSRRW,
    (io.inst === BitPat("b???????_?????_?????_010_?????_11100_11")) -> INST_CSRRS,
    // Privileged Instructions ref. RISC-V开放架构设计之道-V1.0.0 p101
    (io.inst === BitPat("b0011000_00010_00000_000_00000_11100_11")) -> INST_MRET
  ))
   */

  switch(opcode) {
    is("b0110111".U) { // LUI
      oldctrl.illegal := false.B; oldctrl.useImm := true.B;
      oldctrl.rdWen   := true.B
    }
    is("b0010111".U) { // AUIPC
      oldctrl.illegal := false.B; oldctrl.usePc := true.B;
      oldctrl.useImm  := true.B;
      oldctrl.rdWen   := true.B
    }
    is("b1101111".U) { // JAL
      oldctrl.illegal := false.B; oldctrl.isJal := true.B;
      oldctrl.rdWen   := true.B;
      oldctrl.wbSel   := WbSel.PC_4
    }
    is("b1100111".U) { // JALR
      when(funct3 === 0.U) {
        oldctrl.illegal := false.B; oldctrl.isJalr := true.B;
        oldctrl.rdWen   := true.B
        oldctrl.useImm  := true.B; oldctrl.wbSel   := WbSel.PC_4
      }
    }
    is("b1100011".U) { // BRANCH：beq/bne/blt/bge/bltu/bgeu
      when(funct3 =/= 2.U && funct3 =/= 3.U) {
        oldctrl.illegal := false.B; oldctrl.isBranch := true.B
      }
    }
    is("b0000011".U) { // LOAD：lb/lh/lw/lbu/lhu
      when(
        funct3 === 0.U || funct3 === 1.U || funct3 === 2.U ||
          funct3 === 4.U || funct3 === 5.U
      ) {
        oldctrl.illegal := false.B; oldctrl.load := true.B;
        oldctrl.useImm  := true.B
        oldctrl.rdWen   := true.B; oldctrl.wbSel := WbSel.LOAD;
        oldctrl.memOp   := funct3
      }
    }
    is("b0100011".U) { // STORE：sb/sh/sw
      when(funct3 === 0.U || funct3 === 1.U || funct3 === 2.U) {
        oldctrl.illegal := false.B; oldctrl.store := true.B;
        oldctrl.useImm  := true.B
        oldctrl.memOp   := funct3
      }
    }
    is("b0010011".U) { // OP-IMM
      oldctrl.illegal := false.B; oldctrl.useImm := true.B;
      oldctrl.rdWen   := true.B
      switch(funct3) {
        is(0.U) { oldctrl.aluOp := AluOp.ADD } // ADDI
        is(1.U) { when(funct7 === 0.U) { oldctrl.aluOp := AluOp.SLL } } // SLLI
        is(2.U) { oldctrl.aluOp := AluOp.SLT } // SLTI
        is(3.U) { oldctrl.aluOp := AluOp.SLTU } // SLTIU（立即数零扩展，见 imm 处理）
        is(4.U) { oldctrl.aluOp := AluOp.XOR } // XORI
        is(5.U) { // SRLI / SRAI
          when(funct7 === 0.U) { oldctrl.aluOp := AluOp.SRL }
            .elsewhen(funct7 === 0x20.U) { oldctrl.aluOp := AluOp.SRA }
            .otherwise { oldctrl.illegal := true.B }
        }
        is(6.U) { oldctrl.aluOp := AluOp.OR } // ORI
        is(7.U) { oldctrl.aluOp := AluOp.AND } // ANDI
      }
    }
    is("b0110011".U) { // OP
      switch(funct3) {
        is(0.U) { // ADD / SUB
          when(funct7 === 0.U) {
            oldctrl.aluOp := AluOp.ADD; oldctrl.illegal := false.B;
            oldctrl.rdWen := true.B
          }
            .elsewhen(funct7 === 0x20.U) {
              oldctrl.aluOp := AluOp.SUB; oldctrl.illegal := false.B;
              oldctrl.rdWen := true.B
            }
        }
        is(1.U) {
          when(funct7 === 0.U) {
            oldctrl.aluOp := AluOp.SLL; oldctrl.illegal := false.B;
            oldctrl.rdWen := true.B
          }
        }
        is(2.U) {
          when(funct7 === 0.U) {
            oldctrl.aluOp := AluOp.SLT; oldctrl.illegal := false.B;
            oldctrl.rdWen := true.B
          }
        }
        is(3.U) {
          when(funct7 === 0.U) {
            oldctrl.aluOp := AluOp.SLTU; oldctrl.illegal := false.B;
            oldctrl.rdWen := true.B
          }
        }
        is(4.U) {
          when(funct7 === 0.U) {
            oldctrl.aluOp := AluOp.XOR; oldctrl.illegal := false.B;
            oldctrl.rdWen := true.B
          }
        }
        is(5.U) { // SRL / SRA
          when(funct7 === 0.U) {
            oldctrl.aluOp := AluOp.SRL; oldctrl.illegal := false.B;
            oldctrl.rdWen := true.B
          }
            .elsewhen(funct7 === 0x20.U) {
              oldctrl.aluOp := AluOp.SRA; oldctrl.illegal := false.B;
              oldctrl.rdWen := true.B
            }
        }
        is(6.U) {
          when(funct7 === 0.U) {
            oldctrl.aluOp := AluOp.OR; oldctrl.illegal := false.B;
            oldctrl.rdWen := true.B
          }
        }
        is(7.U) {
          when(funct7 === 0.U) {
            oldctrl.aluOp := AluOp.AND; oldctrl.illegal := false.B;
            oldctrl.rdWen := true.B
          }
        }
      }
    }
    is("b0001111".U) { // FENCE：按 NOP 处理
      oldctrl.illegal := false.B; oldctrl.fence := true.B
    }
    is("b1110011".U) { // SYSTEM
      switch(funct3) {
        is(0.U) { // ECALL / EBREAK / MRET
          when(inst(31, 20) === 0x000.U) {
            oldctrl.illegal := false.B; oldctrl.ecall := true.B
          }
            .elsewhen(inst(31, 20) === 0x001.U) {
              oldctrl.illegal := false.B; oldctrl.ebreak := true.B
            }
            .elsewhen(inst(31, 20) === 0x302.U) {
              oldctrl.illegal := false.B; oldctrl.mret := true.B
            }
        }
        is(1.U) {
          oldctrl.illegal := false.B; oldctrl.csrOp := CsrOp.RW;
          oldctrl.rdWen   := true.B;
          oldctrl.wbSel   := WbSel.CSR
        } // CSRRW
        is(2.U) {
          oldctrl.illegal := false.B; oldctrl.csrOp := CsrOp.RS;
          oldctrl.rdWen   := true.B;
          oldctrl.wbSel   := WbSel.CSR
        } // CSRRS
        is(3.U) {
          oldctrl.illegal := false.B; oldctrl.csrOp := CsrOp.RC;
          oldctrl.rdWen   := true.B;
          oldctrl.wbSel   := WbSel.CSR
        } // CSRRC
        is(5.U) {
          oldctrl.illegal := false.B; oldctrl.csrOp := CsrOp.RW;
          oldctrl.csrImm  := true.B;
          oldctrl.rdWen   := true.B; oldctrl.wbSel  := WbSel.CSR
        }
        is(6.U) {
          oldctrl.illegal := false.B; oldctrl.csrOp := CsrOp.RS;
          oldctrl.csrImm  := true.B;
          oldctrl.rdWen   := true.B; oldctrl.wbSel  := WbSel.CSR
        }
        is(7.U) {
          oldctrl.illegal := false.B; oldctrl.csrOp := CsrOp.RC;
          oldctrl.csrImm  := true.B;
          oldctrl.rdWen   := true.B; oldctrl.wbSel  := WbSel.CSR
        }
      }
    }
  }

  val usesRs1 = oldctrl.usePc === false.B && (opcode === "b1100111".U || opcode === "b0000011".U || opcode === "b0100011".U ||
    opcode === "b1100011".U || opcode === "b0010011".U || opcode === "b0110011".U ||
    (opcode === "b1110011".U && oldctrl.csrImm === false.B && oldctrl.csrOp =/= 0.U))
  val usesRs2 =
    opcode === "b0100011".U || opcode === "b1100011".U || opcode === "b0110011".U
  val usesRd  = oldctrl.rdWen
  when(
    (usesRs1 && inst(19) === 1.U) || (usesRs2 && inst(24) === 1.U) ||
      (usesRd && inst(11) === 1.U)
  ) {
    oldctrl.illegal := true.B
  }

  // ---------------- 立即数 ----------------
  val immI   = Cat(Fill(20, inst(31)), inst(31, 20))
  val immS   = Cat(Fill(20, inst(31)), inst(31, 25), inst(11, 7))
  val immB   = Cat(
    Fill(19, inst(31)),
    inst(31),
    inst(7),
    inst(30, 25),
    inst(11, 8),
    0.U(1.W)
  )
  val immU   = Cat(inst(31, 12), 0.U(12.W))
  val immJ   = Cat(
    Fill(11, inst(31)),
    inst(31),
    inst(19, 12),
    inst(20),
    inst(30, 21),
    0.U(1.W)
  )
  val imm    = MuxLookup(opcode, immI)(
    Seq(
      "b1100011".U -> immB, // B
      "b0110111".U -> immU, // U
      "b0010111".U -> immU, // U
      "b1101111".U -> immJ, // J
      "b0100011".U -> immS  // S
    )
  )
  val immSel = Mux(
    opcode === "b0010011".U && funct3 === 3.U,
    Cat(0.U(20.W), inst(31, 20)), // SLTIU：零扩展
    imm
  )

  // ---------------- 读寄存器 ----------------
  val rs1Addr = inst(18, 15)
  val rs2Addr = inst(23, 20)
  val rdAddr  = inst(10, 7)
  io.gprRead1.en   := true.B
  io.gprRead1.addr := rs1Addr
  io.gprRead2.en   := true.B
  io.gprRead2.addr := rs2Addr
  // 旁路：本周期 WBU 正在写同一寄存器时直接取写回值（覆盖距离-3 RAW）
  val rs1Val = Mux(
    rs1Addr === 0.U,
    0.U,
    Mux(
      io.gprWrite.en && io.gprWrite.addr === rs1Addr,
      io.gprWrite.data,
      io.gprRead1.data
    )
  )
  val rs2Val = Mux(
    rs2Addr === 0.U,
    0.U,
    Mux(
      io.gprWrite.en && io.gprWrite.addr === rs2Addr,
      io.gprWrite.data,
      io.gprRead2.data
    )
  )

  // ---------------- 流水线处理 ----------------
  val stalled = io.loadStall
  io.in.ready            := io.out.ready && !stalled
  io.out.valid           := io.in.valid && !stalled
  io.out.bits.pc         := io.in.bits.pc
  io.out.bits.inst       := io.in.bits.inst
  io.out.bits.rs1Val     := rs1Val
  io.out.bits.rs2Val     := rs2Val
  io.out.bits.imm        := immSel
  io.out.bits.rs1Addr    := rs1Addr
  io.out.bits.rs2Addr    := rs2Addr
  io.out.bits.rdAddr     := rdAddr
  io.out.bits.oldctrl    := oldctrl
  io.out.bits.predTaken  := io.in.bits.predTaken
  io.out.bits.predTarget := io.in.bits.predTarget
}
