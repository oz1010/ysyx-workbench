package pipeline_manual

import chisel3._
import chisel3.util._

/** CSR 文件：mstatus(mtvec/mepc/mcause/mvendorid/marchid) 仅实现 M
  * 模式最常用的位：mstatus.MIE(bit3)、mstatus.MPIE(bit7)。
  */
class CsrFile(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val read  = Flipped(new RegReadIO(p.CSR_ADDR_W, p.XLEN))
    val write = Flipped(new RegWriteIO(p.CSR_ADDR_W, p.XLEN))
    val trap  = Flipped(new TrapIO(p))
    // // MRET 返回
    // val mret   = Input(Bool())
    // // 状态输出
    // val mie      = Output(Bool())       // mstatus.MIE
    // val mtvec    = Output(UInt(p.XLEN.W))
    // val mepc     = Output(UInt(p.XLEN.W))
  })

  val csrs = RegInit(VecInit(Seq.fill(p.CSR_COUNT)(0.U(p.XLEN.W))))

  // TODO 临时不写逻辑
  io.read.data := csrs(1)
  csrs(1)      := csrs(1) + 1.U
  when(io.write.en) {
    csrs(1) := io.write.data
  }
}
