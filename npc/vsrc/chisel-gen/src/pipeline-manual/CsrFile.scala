package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._

/** CSR 文件：mstatus(mtvec/mepc/mcause/mvendorid/marchid) 仅实现 M
  * 模式最常用的位：mstatus.MIE(bit3)、mstatus.MPIE(bit7)。
  */
class CsrFile() extends Module {
  val io = IO(new Bundle {
    val read  = Flipped(new RegReadIO(CSR_ADDR_W, CONFIG_ADDR_WIDTH))
    val write = Flipped(new RegWriteIO(CSR_ADDR_W, CONFIG_ADDR_WIDTH))
    val trap  = Flipped(new TrapIO())
    // // MRET 返回
    // val mret   = Input(Bool())
    // // 状态输出
    // val mie      = Output(Bool())       // mstatus.MIE
    val mepc  = Output(UInt(CONFIG_ADDR_WIDTH.W))
    val mtvec = Output(UInt(CONFIG_ADDR_WIDTH.W))
  })

  val csrs = RegInit(VecInit(Seq.fill(CSR_COUNT)(0.U(CONFIG_ADDR_WIDTH.W))))

  def getCsrIdx(addr: UInt): UInt = {
    MuxLookup(addr(CSR_ADDR_W - 1, 0), 0.U)(
      Seq(
        CSRAddr.MSTATUS   -> 1.U,
        CSRAddr.MTVEC     -> 2.U,
        CSRAddr.MEPC      -> 3.U,
        CSRAddr.MCAUSE    -> 4.U,
        CSRAddr.MTVAL     -> 5.U,
        CSRAddr.MVENDORID -> 6.U,
        CSRAddr.MARCHID   -> 7.U
      )
    )
  }

  val readIdx  = getCsrIdx(io.read.addr)
  val writeIdx = getCsrIdx(io.write.waddr)

  // CSR 更新（同周期冲突时：MRET < 陷阱 < CSR 写）
  io.read.data := csrs(readIdx)
  io.mepc      := csrs(getCsrIdx(CSRAddr.MEPC))
  io.mtvec     := csrs(getCsrIdx(CSRAddr.MTVEC))
  when(io.write.wen) {
    csrs(writeIdx) := io.write.wdata
  }.elsewhen(io.trap.en) {
    csrs(getCsrIdx(CSRAddr.MEPC))   := io.trap.epc
    csrs(getCsrIdx(CSRAddr.MCAUSE)) := io.trap.cause
    csrs(getCsrIdx(CSRAddr.MTVAL))  := io.trap.tval
  }
}
