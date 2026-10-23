package pipeline_manual

import chisel3._
import chisel3.util._
import scala.language.reflectiveCalls
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
    // MRET 由 WBU 通过普通 CSR 写口更新，外部也能观察到同一事件。
    val status = Output(UInt(CONFIG_ADDR_WIDTH.W))
    val mepc  = Output(UInt(CONFIG_ADDR_WIDTH.W))
    val mtvec = Output(UInt(CONFIG_ADDR_WIDTH.W))
  })

  val csrs = RegInit(VecInit((0 until CSR_COUNT).map(i =>
    (if (i == 1) "h1800".U(CONFIG_ADDR_WIDTH.W) else 0.U(CONFIG_ADDR_WIDTH.W)))))

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

  // 当前指令写 CSR 后可接收中断：先普通写，再由 trap 覆盖陷阱状态。
  io.status    := csrs(getCsrIdx(CSRAddr.MSTATUS))
  io.read.data := csrs(readIdx)
  io.mepc      := csrs(getCsrIdx(CSRAddr.MEPC))
  io.mtvec     := csrs(getCsrIdx(CSRAddr.MTVEC))
  when(io.write.wen) {
    csrs(writeIdx) := io.write.wdata
  }
  when(io.trap.en) {
    csrs(getCsrIdx(CSRAddr.MSTATUS)) := io.trap.status
    csrs(getCsrIdx(CSRAddr.MEPC))   := Cat(io.trap.epc(31, 2), 0.U(2.W))
    csrs(getCsrIdx(CSRAddr.MCAUSE)) := io.trap.cause
    csrs(getCsrIdx(CSRAddr.MTVAL))  := io.trap.tval
  }
}
