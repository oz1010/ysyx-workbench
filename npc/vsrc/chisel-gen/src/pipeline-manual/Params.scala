package pipeline_manual

import chisel3.util.log2Up

/** 统一配置：所有"关键参数"集中在此，例化时像 Verilog parameter 一样调整。
  *
  * 例：
  * {{{
  *   val core = Module(new Rv32eCore(CoreParams(
  *     SRAM_READ_DELAY  = 1,
  *     CACHE_WAYS       = 16,
  *     CACHE_SET_BITS   = 4,
  *     CACHE_BLOCK_BITS = 4
  *   )))
  * }}}
  */
case class CoreParams(
  /* ---- 指定要求的 parameter ---- */
  val INST_WIDTH: Int = 32,          // 指令宽度（RV32I 子集固定 32）
  val SRAM_READ_DELAY: Int = 0,      // SRAM 读延迟（0 = 组合读；>=1 表示同步 SRAM 延迟拍数）
  val ADDR_WIDTH: Int = 32,          // 地址宽度
  val DATA_WIDTH: Int = 32,          // 数据宽度（AXI4 数据总线宽度）
  val BRESP_WIDTH: Int = 2,          // AXI4 BRESP 宽度
  val RRESP_WIDTH: Int = 2,          // AXI4 RRESP 宽度
  val RESET_PC: Long = 0x3000_00f4L, // 复位取指地址
  val CACHE_WAYS: Int = 8,           // Cache 路数 W（每组 cache 块数，组相联）
  val CACHE_SET_BITS: Int = 4,       // Cache 组索引位数 N（组数 = 2^N）
  val CACHE_BLOCK_BITS: Int = 4,     // Cache 块内偏移位数 M（块字节数 = 2^M）
  val STORE_BUF_DEPTH: Int = 8,      // 写直通 Store Buffer 深度
  val MVENDORID: Long = 0x00000000L, // CSR mvendorid 只读值
  val MARCHID: Long = 0x00000000L,   // CSR marchid 只读值
  val INT_CAUSE: Long = 0x8000000bL, // 机器外部中断 mcause（io.interrupt）
  val RESET_PC_EN: Boolean = false   // 是否使用复位取指地址
) {
  require(INST_WIDTH == 32, "RV32E 指令宽度固定为 32")
  require(DATA_WIDTH == 32, "当前实现 AXI4 数据宽度为 32")
  require(ADDR_WIDTH == 32)
  require(CACHE_WAYS >= 2, "组相联路数 W 至少为 2")
  require(CACHE_SET_BITS >= 0 && CACHE_BLOCK_BITS >= 2)
  require(ADDR_WIDTH > CACHE_SET_BITS + CACHE_BLOCK_BITS, "tag 位宽需为正")
  require(SRAM_READ_DELAY >= 0)

  val LINE_BYTES: Int = 1 << CACHE_BLOCK_BITS // Cache 行字节数（2^M）
  val LINE_WORDS: Int = LINE_BYTES / 4        // 每行 32bit 字数
  val XLEN: Int       = 32
  val GPR_COUNT: Int  = 16                    // RV32E：仅 x0~x15
  val GPR_ADDR_W: Int = log2Up(GPR_COUNT)     // GSR地址宽度
  val CSR_COUNT: Int  = 8                     // 重新映射，固定实现几个
  val CSR_ADDR_W: Int = 12                    // CSR地址宽度
}
