package pipeline_chisel2

import chisel3._
import chisel3.util._

/**
 * ICache：指令 Cache（只读）。
 * CPU 侧（io.cpu）与 IFU 握手；未命中经 io.refill 向仲裁器发整行读请求填充。
 * 框架：端口与连接已定义，内部实现留空。
 */
class ICache(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val cpu    = Flipped(new CacheCpuIO(p)) // IFU 侧
    val refill = new RefillIO(p)            // → 总线仲裁器（行填充）
  })

  // TODO: tag/data 阵列、组相联查找、替换策略、填充状态机
  io.cpu.req.ready    := false.B
  io.cpu.resp.valid   := false.B
  io.cpu.resp.data    := 0.U
  io.refill.req.valid := false.B
  io.refill.req.addr  := 0.U
}
