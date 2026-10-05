package pipeline_chisel2

import chisel3._
import chisel3.util._

/**
 * LSU：访存（经 DCache）+ MEM/WB 级间寄存器。
 * 上游 EX/MEM、下游 MEM/WB 均为 valid/ready 握手；
 * 访存请求经 io.cache 与 DCache 握手，错误路径访存由 kill 取消。
 * 框架：端口与连接已定义，内部实现留空。
 */
class Lsu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val in    = Flipped(Decoupled(new ExMemBundle(p))) // EX/MEM 级间
    val out   = Decoupled(new MemWbBundle(p))          // MEM/WB 级间
    val cache = new CacheCpuIO(p)                      // → DCache CPU 侧
    val kill  = Input(Bool())                          // 冲刷（WBU 重定向）
  })

  // TODO: load/store 下发、访存大小/符号处理、非访存指令直通
  io.in.ready          := false.B
  io.out.valid         := false.B
  io.out.bits          := DontCare
  io.cache.req.valid   := false.B
  io.cache.req.addr    := 0.U
  io.cache.req.wdata   := 0.U
  io.cache.req.wstrb   := 0.U
  io.cache.req.isWrite := false.B
}
