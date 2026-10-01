package rv32e

import circt.stage.ChiselStage

/** 生成 Verilog（默认参数；可在此修改 CoreParams(...) 以调整配置） */
object EmitVerilog extends App {
  val params = CoreParams() // 例如：CoreParams(SRAM_READ_DELAY = 1, ICACHE_LINES = 128)
  val f = ChiselStage.emitSystemVerilogFile(new Rv32eTop(params), Array("--target-dir", "generated"))
  println(s"Generated: $f")
}
