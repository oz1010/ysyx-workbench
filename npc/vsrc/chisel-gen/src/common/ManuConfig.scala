package config

import chisel3._
import chisel3.util._

// 手动配置项
object ManuConfig {
  val GPR_COUNT: Int  = 16
  val GPR_ADDR_W: Int = log2Ceil(GPR_COUNT)
  val CSR_ADDR_W: Int = 12
}
