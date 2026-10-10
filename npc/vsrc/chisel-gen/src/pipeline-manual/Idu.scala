package pipeline_manual

import chisel3._
import chisel3.util._

/** IDU：译码 + ID 寄存器 + RAW(load-use) 冒险检测。
  *   - RV32I(RV32E) 基础指令集，SYSTEM 支持 ECALL/EBREAK/MRET/CSR 指令。
  */
class Idu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val in = Flipped(Decoupled(new IfBundle(p)))
    val out = Decoupled(new IdBundle(p))
    val gprRead1 = new RegReadIO(p.GPR_ADDR_W, p.XLEN)
    val gprRead2 = new RegReadIO(p.GPR_ADDR_W, p.XLEN)
  })

  // ---------------- 译码 ----------------
  val ctrl = Wire(new Ctrl)
  ctrl.aluOp := 0.U
  ctrl.usePc := false.B
  ctrl.useImm := false.B
  ctrl.isBranch := false.B
  ctrl.isJal := false.B
  ctrl.isJalr := false.B
  ctrl.load := false.B
  ctrl.store := false.B
  ctrl.memOp := 0.U
  ctrl.wbSel := 0.U
  ctrl.rdWen := false.B
  ctrl.csrOp := 0.U
  ctrl.csrImm := false.B
  ctrl.fence := false.B
  ctrl.ecall := false.B
  ctrl.ebreak := false.B
  ctrl.mret := false.B
  ctrl.illegal := true.B

  // TODO 临时不写逻辑
  io.in.ready := false.B

  val idReg = Reg(new IdBundle(p))
  idReg.pc := io.in.bits.pc
  idReg.inst := io.in.bits.inst
  idReg.rs1Val := 0.U
  idReg.rs2Val := 0.U
  idReg.imm := 0.U
  idReg.rs1Addr := 0.U
  idReg.rs2Addr := 0.U
  idReg.rdAddr := 0.U
  idReg.ctrl := ctrl
  idReg.predTaken := io.in.bits.predTaken
  idReg.predTarget := io.in.bits.predTarget

  io.out.valid := false.B
  io.out.bits := idReg

  io.gprRead1.en := false.B
  io.gprRead1.addr := 0.U
  io.gprRead2.en := false.B
  io.gprRead2.addr := 0.U
}
