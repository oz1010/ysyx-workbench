package pipeline_manual

import chisel3._
import chisel3.util._

/** EXU：ALU、前递（EX/MEM、MEM/WB）、分支解析与静态预测修正、 CSR 读（返回旧值）、异常检测（含访存/跳转地址非对齐）。
  */
class Exu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val csrRead = new RegReadIO(p.CSR_ADDR_W, p.XLEN)
    val in = Flipped(Decoupled(new IdBundle(p)))
    val out = Decoupled(new ExBundle(p))
    val redirect = Output(new Redirect(p)) // 预测修正/跳转（→ IFU）
  })

  // TODO 临时不写逻辑
  io.in.ready := false.B
  io.redirect.valid := false.B
  io.redirect.target := 0.U

  val exReg = Reg(new ExBundle(p))
  exReg.pc := io.in.bits.pc
  exReg.aluResult := 0.U
  exReg.storeData := 0.U
  exReg.rdAddr := io.in.bits.rdAddr
  exReg.ctrl := io.in.bits.ctrl
  exReg.csrAddr := 0.U
  exReg.csrWdata := 0.U
  exReg.csrRdata := 0.U
  exReg.excValid := 0.U
  exReg.excCause := 0.U

  io.out.valid := false.B
  io.out.bits := exReg

  io.csrRead.en := false.B
  io.csrRead.addr := 0.U
}
