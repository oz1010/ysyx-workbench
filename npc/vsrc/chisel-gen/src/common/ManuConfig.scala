package config

import chisel3._
import chisel3.util._

// 手动配置项
object ManuConfig {
  val GPR_COUNT: Int  = 16
  val GPR_ADDR_W: Int = log2Ceil(GPR_COUNT)
  val CSR_COUNT: Int  = 8 // TODO 可以改为非映射版本，重新映射，固定实现几个
  val CSR_ADDR_W: Int = 12

  val INT_CAUSE: Long = 0x8000000bL // 机器外部中断 mcause（io.interrupt）
}
