package pipeline_manual

import chisel3._
import config.AutoConfig._
import config.ManuConfig._

class GprFile() extends Module {
  val io = IO(new Bundle {
    val read1 = Flipped(new RegReadIO(GPR_ADDR_W, CONFIG_ADDR_WIDTH))
    val read2 = Flipped(new RegReadIO(GPR_ADDR_W, CONFIG_ADDR_WIDTH))
    val a0    = Output(UInt(CONFIG_ADDR_WIDTH.W))
    val a1    = Output(UInt(CONFIG_ADDR_WIDTH.W))
    val a2    = Output(UInt(CONFIG_ADDR_WIDTH.W))
    val write = Flipped(new RegWriteIO(GPR_ADDR_W, CONFIG_ADDR_WIDTH))
  })

  val gprs = Module(new GprsExt())
  gprs.clock := clock
  gprs.reset := reset

  gprs.rs1      := io.read1.addr
  io.read1.data := gprs.src1
  gprs.rs2      := io.read2.addr
  io.read2.data := gprs.src2
  io.a0         := gprs.a0
  io.a1         := gprs.a1
  io.a2         := gprs.a2

  gprs.wen   := io.write.wen
  gprs.waddr := io.write.waddr
  gprs.wdata := io.write.wdata
}
