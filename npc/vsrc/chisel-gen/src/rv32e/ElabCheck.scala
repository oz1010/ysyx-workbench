package rv32e

import circt.stage.ChiselStage

/**  elaboration 冒烟检查：验证不同 CoreParams 配置都能生成 SystemVerilog */
object ElabCheck extends App {
  val configs = Seq(
    ("default", CoreParams()),
    ("delay2_big", CoreParams(SRAM_READ_DELAY = 2, ICACHE_LINES = 256, DCACHE_LINES = 128, STORE_BUF_DEPTH = 16)),
    ("delay1_small", CoreParams(SRAM_READ_DELAY = 1, ICACHE_LINES = 32, DCACHE_LINES = 32, LINE_BYTES = 32, MVENDORID = 0x1234ABCDL, MARCHID = 42))
  )
  configs.foreach { case (name, p) =>
    val f = ChiselStage.emitSystemVerilogFile(new Rv32eTop(p), Array("--target-dir", s"generated_elab/$name"))
    println(s"[$name] OK: $f")
  }
  println("ELAB CHECK PASSED")
}
