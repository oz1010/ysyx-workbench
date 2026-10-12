package pipeline_manual

import chisel3._
import chisel3.util._

class ResetPcGetter(addrWidth: Int)
    extends BlackBox(Map("ADDR_WIDTH" -> addrWidth)) {
  val io = IO(new Bundle {
    val clk      = Input(Clock())
    val rst      = Input(Bool())
    val reset_pc = Output(UInt(addrWidth.W))
  })
}
