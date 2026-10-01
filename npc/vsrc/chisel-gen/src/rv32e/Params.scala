package rv32e

/**
 * 统一配置：所有"关键参数"集中在此，例化时像 Verilog parameter 一样调整。
 *
 * 例：
 * {{{
 *   val core = Module(new Rv32eCore(CoreParams(
 *     SRAM_READ_DELAY = 1,
 *     ICACHE_LINES    = 128,
 *     DCACHE_LINES    = 128
 *   )))
 * }}}
 */
case class CoreParams(
    /* ---- 指定要求的 parameter ---- */
    val INST_WIDTH: Int = 32,     // 指令宽度（RV32I 子集固定 32）
    val SRAM_READ_DELAY: Int = 0, // SRAM 读延迟（0 = 组合读；>=1 表示同步 SRAM 延迟拍数）
    val ADDR_WIDTH: Int = 32,     // 地址宽度
    val DATA_WIDTH: Int = 32,     // 数据宽度（AXI4 数据总线宽度）
    val BRESP_WIDTH: Int = 2,     // AXI4 BRESP 宽度
    val RRESP_WIDTH: Int = 2,     // AXI4 RRESP 宽度
    /* ---- 其余关键参数（同样通过本配置统一调整） ---- */
    val RESET_VEC: Long = 0x00000000L, // 复位取指地址
    val ICACHE_LINES: Int = 64,        // ICache 行数（直接映射）
    val DCACHE_LINES: Int = 64,        // DCache 行数（直接映射）
    val LINE_BYTES: Int = 16,          // Cache 行字节数
    val STORE_BUF_DEPTH: Int = 8,      // 写直通 Store Buffer 深度
    val MVENDORID: Long = 0x00000000L, // CSR mvendorid 只读值
    val MARCHID: Long = 0x00000000L,   // CSR marchid 只读值
    val INT_CAUSE: Long = 0x8000000BL  // 机器外部中断 mcause（io.interrupt）
) {
  require(INST_WIDTH == 32, "RV32E 指令宽度固定为 32")
  require(DATA_WIDTH == 32, "当前实现 AXI4 数据宽度为 32")
  require(ADDR_WIDTH == 32)
  require(LINE_BYTES >= 4 && LINE_BYTES % 4 == 0, "Cache 行需为 4 字节整数倍")
  require(SRAM_READ_DELAY >= 0)
  require(isPow2(LINE_BYTES) && isPow2(ICACHE_LINES) && isPow2(DCACHE_LINES))

  val LINE_WORDS: Int = LINE_BYTES / 4 // 每行 32bit 字数
  val XLEN: Int = 32
  val REG_NUM: Int = 16 // RV32E：仅 x0~x15

  private def isPow2(n: Int): Boolean = n > 0 && (n & (n - 1)) == 0
}
