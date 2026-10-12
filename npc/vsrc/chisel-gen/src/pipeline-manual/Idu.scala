package pipeline_manual

import chisel3._
import chisel3.util._

/** IDU：译码 + ID 寄存器 + RAW(load-use) 冒险检测。
  *   - RV32I(RV32E) 基础指令集，SYSTEM 支持 ECALL/EBREAK/MRET/CSR 指令。
  */
class Idu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val in         = Flipped(Decoupled(new IfBundle(p)))
    val out        = Decoupled(new IdBundle(p))
    val gprRead1   = new RegReadIO(p.GPR_ADDR_W, p.XLEN)
    val gprRead2   = new RegReadIO(p.GPR_ADDR_W, p.XLEN)
    val gprWrite   = Flipped(new RegWriteIO(p.GPR_ADDR_W, p.XLEN))
    val loadStall  = Output(Bool()) // load-use RAW 冒险，请求 stall
    val exRedirect = Input(new Redirect(p))
    val wbRedirect = Input(new Redirect(p))
  })

  // ---------------- 译码 ----------------
  val inst   = io.in.bits.inst
  val opcode = inst(6, 0)
  val funct3 = inst(14, 12)
  val funct7 = inst(31, 25)

  val ctrl = Wire(new Ctrl)
  ctrl.aluOp    := 0.U
  ctrl.usePc    := false.B
  ctrl.useImm   := false.B
  ctrl.isBranch := false.B
  ctrl.isJal    := false.B
  ctrl.isJalr   := false.B
  ctrl.load     := false.B
  ctrl.store    := false.B
  ctrl.memOp    := 0.U
  ctrl.wbSel    := WbSel.ALU
  ctrl.rdWen    := false.B
  ctrl.csrOp    := 0.U
  ctrl.csrImm   := false.B
  ctrl.fence    := false.B
  ctrl.ecall    := false.B
  ctrl.ebreak   := false.B
  ctrl.mret     := false.B
  ctrl.illegal  := true.B

  switch(opcode) {
    is("b0110111".U) { // LUI
      ctrl.illegal := false.B; ctrl.useImm := true.B; ctrl.rdWen := true.B
    }
    is("b0010111".U) { // AUIPC
      ctrl.illegal := false.B; ctrl.usePc := true.B; ctrl.useImm := true.B;
      ctrl.rdWen   := true.B
    }
    is("b1101111".U) { // JAL
      ctrl.illegal := false.B; ctrl.isJal := true.B; ctrl.rdWen := true.B;
      ctrl.wbSel   := WbSel.PC_4
    }
    is("b1100111".U) { // JALR
      when(funct3 === 0.U) {
        ctrl.illegal := false.B; ctrl.isJalr := true.B; ctrl.rdWen := true.B
        ctrl.useImm  := true.B; ctrl.wbSel   := WbSel.PC_4
      }
    }
    is("b1100011".U) { // BRANCH：beq/bne/blt/bge/bltu/bgeu
      when(funct3 =/= 2.U && funct3 =/= 3.U) {
        ctrl.illegal := false.B; ctrl.isBranch := true.B
      }
    }
    is("b0000011".U) { // LOAD：lb/lh/lw/lbu/lhu
      when(
        funct3 === 0.U || funct3 === 1.U || funct3 === 2.U ||
          funct3 === 4.U || funct3 === 5.U
      ) {
        ctrl.illegal := false.B; ctrl.load := true.B; ctrl.useImm    := true.B
        ctrl.rdWen   := true.B; ctrl.wbSel := WbSel.LOAD; ctrl.memOp := funct3
      }
    }
    is("b0100011".U) { // STORE：sb/sh/sw
      when(funct3 === 0.U || funct3 === 1.U || funct3 === 2.U) {
        ctrl.illegal := false.B; ctrl.store := true.B; ctrl.useImm := true.B
        ctrl.memOp   := funct3
      }
    }
    is("b0010011".U) { // OP-IMM
      ctrl.illegal := false.B; ctrl.useImm := true.B; ctrl.rdWen := true.B
      switch(funct3) {
        is(0.U) { ctrl.aluOp := AluOp.ADD } // ADDI
        is(1.U) { when(funct7 === 0.U) { ctrl.aluOp := AluOp.SLL } } // SLLI
        is(2.U) { ctrl.aluOp := AluOp.SLT } // SLTI
        is(3.U) { ctrl.aluOp := AluOp.SLTU } // SLTIU（立即数零扩展，见 imm 处理）
        is(4.U) { ctrl.aluOp := AluOp.XOR } // XORI
        is(5.U) { // SRLI / SRAI
          when(funct7 === 0.U) { ctrl.aluOp := AluOp.SRL }
            .elsewhen(funct7 === 0x20.U) { ctrl.aluOp := AluOp.SRA }
            .otherwise { ctrl.illegal := true.B }
        }
        is(6.U) { ctrl.aluOp := AluOp.OR } // ORI
        is(7.U) { ctrl.aluOp := AluOp.AND } // ANDI
      }
    }
    is("b0110011".U) { // OP
      switch(funct3) {
        is(0.U) { // ADD / SUB
          when(funct7 === 0.U) {
            ctrl.aluOp := AluOp.ADD; ctrl.illegal := false.B;
            ctrl.rdWen := true.B
          }
            .elsewhen(funct7 === 0x20.U) {
              ctrl.aluOp := AluOp.SUB; ctrl.illegal := false.B;
              ctrl.rdWen := true.B
            }
        }
        is(1.U) {
          when(funct7 === 0.U) {
            ctrl.aluOp := AluOp.SLL; ctrl.illegal := false.B;
            ctrl.rdWen := true.B
          }
        }
        is(2.U) {
          when(funct7 === 0.U) {
            ctrl.aluOp := AluOp.SLT; ctrl.illegal := false.B;
            ctrl.rdWen := true.B
          }
        }
        is(3.U) {
          when(funct7 === 0.U) {
            ctrl.aluOp := AluOp.SLTU; ctrl.illegal := false.B;
            ctrl.rdWen := true.B
          }
        }
        is(4.U) {
          when(funct7 === 0.U) {
            ctrl.aluOp := AluOp.XOR; ctrl.illegal := false.B;
            ctrl.rdWen := true.B
          }
        }
        is(5.U) { // SRL / SRA
          when(funct7 === 0.U) {
            ctrl.aluOp := AluOp.SRL; ctrl.illegal := false.B;
            ctrl.rdWen := true.B
          }
            .elsewhen(funct7 === 0x20.U) {
              ctrl.aluOp := AluOp.SRA; ctrl.illegal := false.B;
              ctrl.rdWen := true.B
            }
        }
        is(6.U) {
          when(funct7 === 0.U) {
            ctrl.aluOp := AluOp.OR; ctrl.illegal := false.B;
            ctrl.rdWen := true.B
          }
        }
        is(7.U) {
          when(funct7 === 0.U) {
            ctrl.aluOp := AluOp.AND; ctrl.illegal := false.B;
            ctrl.rdWen := true.B
          }
        }
      }
    }
    is("b0001111".U) { // FENCE：按 NOP 处理
      ctrl.illegal := false.B; ctrl.fence := true.B
    }
    is("b1110011".U) { // SYSTEM
      switch(funct3) {
        is(0.U) { // ECALL / EBREAK / MRET
          when(inst(31, 20) === 0x000.U) {
            ctrl.illegal := false.B; ctrl.ecall := true.B
          }
            .elsewhen(inst(31, 20) === 0x001.U) {
              ctrl.illegal := false.B; ctrl.ebreak := true.B
            }
            .elsewhen(inst(31, 20) === 0x302.U) {
              ctrl.illegal := false.B; ctrl.mret := true.B
            }
        }
        is(1.U) {
          ctrl.illegal := false.B; ctrl.csrOp := CsrOp.RW; ctrl.rdWen := true.B;
          ctrl.wbSel   := WbSel.CSR
        } // CSRRW
        is(2.U) {
          ctrl.illegal := false.B; ctrl.csrOp := CsrOp.RS; ctrl.rdWen := true.B;
          ctrl.wbSel   := WbSel.CSR
        } // CSRRS
        is(3.U) {
          ctrl.illegal := false.B; ctrl.csrOp := CsrOp.RC; ctrl.rdWen := true.B;
          ctrl.wbSel   := WbSel.CSR
        } // CSRRC
        is(5.U) {
          ctrl.illegal := false.B; ctrl.csrOp := CsrOp.RW;
          ctrl.csrImm  := true.B;
          ctrl.rdWen   := true.B; ctrl.wbSel  := WbSel.CSR
        }
        is(6.U) {
          ctrl.illegal := false.B; ctrl.csrOp := CsrOp.RS;
          ctrl.csrImm  := true.B;
          ctrl.rdWen   := true.B; ctrl.wbSel  := WbSel.CSR
        }
        is(7.U) {
          ctrl.illegal := false.B; ctrl.csrOp := CsrOp.RC;
          ctrl.csrImm  := true.B;
          ctrl.rdWen   := true.B; ctrl.wbSel  := WbSel.CSR
        }
      }
    }
  }

  val usesRs1 = ctrl.usePc === false.B && (opcode === "b1100111".U || opcode === "b0000011".U || opcode === "b0100011".U ||
    opcode === "b1100011".U || opcode === "b0010011".U || opcode === "b0110011".U ||
    (opcode === "b1110011".U && ctrl.csrImm === false.B && ctrl.csrOp =/= 0.U))
  val usesRs2 =
    opcode === "b0100011".U || opcode === "b1100011".U || opcode === "b0110011".U
  val usesRd  = ctrl.rdWen
  when(
    (usesRs1 && inst(19) === 1.U) || (usesRs2 && inst(24) === 1.U) ||
      (usesRd && inst(11) === 1.U)
  ) {
    ctrl.illegal := true.B
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

  // ---------------- RAW 冒险：load-use（相邻） ----------------
  val idValidReg = RegInit(false.B)
  val idReg      = Reg(new IdBundle(p))
  val loadStall  = idValidReg && idReg.ctrl.load && idReg.rdAddr =/= 0.U &&
    ((usesRs1 && rs1Addr === idReg.rdAddr) || (usesRs2 && rs2Addr === idReg.rdAddr))

  // ---------------- 阶段寄存器 ----------------
  val idReady = io.out.ready && !loadStall
  when(io.wbRedirect.valid || io.exRedirect.valid) {
    idValidReg := false.B
  }.elsewhen(idReady) {
    idValidReg       := io.in.valid
    idReg.pc         := io.in.bits.pc
    idReg.inst       := io.in.bits.inst
    idReg.rs1Val     := rs1Val
    idReg.rs2Val     := rs2Val
    idReg.imm        := immSel
    idReg.rs1Addr    := rs1Addr
    idReg.rs2Addr    := rs2Addr
    idReg.rdAddr     := rdAddr
    idReg.ctrl       := ctrl
    idReg.predTaken  := io.in.bits.predTaken
    idReg.predTarget := io.in.bits.predTarget
  }

  io.out.bits  := idReg
  io.out.valid := idValidReg
  io.loadStall := loadStall
  io.in.ready  := idReady
}
