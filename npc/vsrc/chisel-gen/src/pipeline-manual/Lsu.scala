package pipeline_manual

import chisel3._
import chisel3.util._

/** LSU（MEM 级）：封装 DCache，完成 load 数据抽取/符号扩展，
  *   - 产生 MEM/WB 寄存器；store 经 Cache 写直通到 Store Buffer。
  */
class Lsu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val cache = new CacheIO(p)
    val in    = Flipped(Decoupled(new ExBundle(p)))
    val out   = Decoupled(new LsBundle(p))
    val kill  = Input(Bool()) // WBU 陷阱/MRET：冲刷 EX/MEM 及其后
  })

  // TODO 临时不写逻辑
  io.in.ready := false.B

  io.cache.req.valid   := false.B
  io.cache.req.addr    := 0.U
  io.cache.req.wdata   := 0.U
  io.cache.req.wstrb   := 0.U
  io.cache.req.isWrite := false.B

  val lsReg = Reg(new LsBundle(p))
  lsReg.pc        := io.in.bits.pc
  lsReg.aluResult := io.in.bits.aluResult
  lsReg.loadData  := 0.U
  lsReg.rdAddr    := io.in.bits.rdAddr
  lsReg.ctrl      := io.in.bits.ctrl
  lsReg.csrAddr   := io.in.bits.csrAddr
  lsReg.csrWdata  := io.in.bits.csrWdata
  lsReg.csrRdata  := io.in.bits.csrRdata
  lsReg.excValid  := io.in.bits.excValid
  lsReg.excCause  := io.in.bits.excCause
  io.out.valid    := false.B
  io.out.bits     := lsReg
}
