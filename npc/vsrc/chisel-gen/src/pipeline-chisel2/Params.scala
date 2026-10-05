package pipeline_chisel2

import chisel3.util.log2Ceil

/**
 * 统一配置：所有关键参数集中在此文件，例化时像 Verilog parameter 一样调整。
 *
 * 例：
 * {{{
 *   val core = Module(new Rv32eCore(CoreParams(
 *     SRAM_READ_DELAY = 1,
 *     ICACHE_WAYS     = 16
 *   )))
 * }}}
 */
case class CoreParams(
    /* ---- 基础位宽 ---- */
    val INST_WIDTH: Int = 32,     // 指令宽度（RV32I 子集固定 32）
    val XLEN: Int = 32,           // 通用寄存器宽度
    val ADDR_WIDTH: Int = 32,     // 地址宽度
    val DATA_WIDTH: Int = 32,     // AXI4 数据总线宽度
    /* ---- AXI4 接口 ---- */
    val AXI_ID_WIDTH: Int = 4,    // AXI4 ID 位宽（单一主设备，ID 恒为 0）
    val BRESP_WIDTH: Int = 2,     // AXI4 BRESP 宽度
    val RRESP_WIDTH: Int = 2,     // AXI4 RRESP 宽度
    /* ---- 存储 / 时序 ---- */
    val SRAM_READ_DELAY: Int = 0, // SRAM 读延迟（0 = 组合读；>=1 表示同步 SRAM 延迟拍数）
    val RESET_VEC: Long = 0x00000000L, // 复位取指地址
    /* ---- 寄存器堆（RV32E） ---- */
    val REG_NUM: Int = 16,        // RV32E：仅 x0~x15
    /* ---- ICache ---- */
    val ICACHE_WAYS: Int = 8,     // 路数 W（每组块数，组相联）
    val ICACHE_SET_BITS: Int = 4, // 组索引位数 N（组数 = 2^N）
    val ICACHE_BLOCK_BITS: Int = 4, // 块内偏移位数 M（块字节数 = 2^M）
    /* ---- DCache ---- */
    val DCACHE_WAYS: Int = 8,     // 路数 W
    val DCACHE_SET_BITS: Int = 4, // 组索引位数 N
    val DCACHE_BLOCK_BITS: Int = 4, // 块内偏移位数 M
    /* ---- CSR 只读常量 ---- */
    val MVENDORID: Long = 0x00000000L, // CSR mvendorid 只读值
    val MARCHID: Long = 0x00000000L,   // CSR marchid 只读值
    val INT_CAUSE: Long = 0x8000000BL  // 机器外部中断 mcause（io.interrupt）
) {
  require(INST_WIDTH == 32, "RV32E 指令宽度固定为 32")
  require(XLEN == 32 && ADDR_WIDTH == 32 && DATA_WIDTH == 32)
  require(AXI_ID_WIDTH > 0)
  require(SRAM_READ_DELAY >= 0)
  require(REG_NUM == 16, "RV32E 固定 16 个寄存器")

  /* ---- ICache 派生参数 ---- */
  require(ICACHE_WAYS >= 2, "组相联路数 W 至少为 2")
  require(ICACHE_SET_BITS >= 0 && ICACHE_BLOCK_BITS >= 2)
  require(ADDR_WIDTH > ICACHE_SET_BITS + ICACHE_BLOCK_BITS, "tag 位宽需为正")
  val ICACHE_LINE_BYTES: Int = 1 << ICACHE_BLOCK_BITS // 行字节数（2^M）
  val ICACHE_LINE_WORDS: Int = ICACHE_LINE_BYTES / 4  // 每行 32bit 字数

  /* ---- DCache 派生参数 ---- */
  require(DCACHE_WAYS >= 2)
  require(DCACHE_SET_BITS >= 0 && DCACHE_BLOCK_BITS >= 2)
  require(ADDR_WIDTH > DCACHE_SET_BITS + DCACHE_BLOCK_BITS)
  val DCACHE_LINE_BYTES: Int = 1 << DCACHE_BLOCK_BITS
  val DCACHE_LINE_WORDS: Int = DCACHE_LINE_BYTES / 4

  /* ---- 寄存器号位宽 ---- */
  val REG_ADDR_WIDTH: Int = log2Ceil(REG_NUM) // RV32E：4bit

  /* ---- CSR 地址（M 模式最常用的 6 个） ---- */
  val CSR_MSTATUS: Int   = 0x300 // 机器状态
  val CSR_MTVEC: Int     = 0x305 // 陷阱向量
  val CSR_MEPC: Int      = 0x341 // 陷阱 PC
  val CSR_MCAUSE: Int    = 0x342 // 陷阱原因
  val CSR_MVENDORID: Int = 0xF11 // 厂商 ID（只读）
  val CSR_MARCHID: Int   = 0xF12 // 架构 ID（只读）
}
