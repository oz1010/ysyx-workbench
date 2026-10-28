package pipeline_manual

import chisel3._
import config.AutoConfig._
import config.ManuConfig._

class CsrFile() extends Module {
  val io = IO(new Bundle {
    val read   = Flipped(new RegReadIO(CSR_ADDR_W, CONFIG_ADDR_WIDTH))
    val write  = Flipped(new RegWriteIO(CSR_ADDR_W, CONFIG_ADDR_WIDTH))
    val trap   = Flipped(new TrapIO())
    val status = Output(UInt(CONFIG_ADDR_WIDTH.W))
    val mepc   = Output(UInt(CONFIG_ADDR_WIDTH.W))
    val mtvec  = Output(UInt(CONFIG_ADDR_WIDTH.W))
  })

  val csrs = Module(new CsrsExt())
  csrs.clock := clock
  csrs.reset := reset

  csrs.raddr   := io.read.addr
  io.read.data := csrs.rdata
  csrs.wen     := io.write.wen
  csrs.waddr   := io.write.waddr
  csrs.wdata   := io.write.wdata

  csrs.trap_en     := io.trap.en
  csrs.trap_epc    := io.trap.epc
  csrs.trap_cause  := io.trap.cause
  csrs.trap_tval   := io.trap.tval
  csrs.trap_status := io.trap.status

  io.status := csrs.status
  io.mepc   := csrs.mepc
  io.mtvec  := csrs.mtvec
}
