package pipeline_manual

import chisel3._
import chisel3.util._

class ResetPcGetter(addrWidth: Int) extends BlackBox {
  val io = IO(new Bundle {
    val reset_pc = Output(UInt(addrWidth.W))
  })
}
