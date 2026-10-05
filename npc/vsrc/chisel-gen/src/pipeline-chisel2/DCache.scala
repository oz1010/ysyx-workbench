package pipeline_chisel2

import chisel3._
import chisel3.util._

/**
 * DCache：数据 Cache（写直通）。
 * CPU 侧（io.cache）与 LSU 握手；未命中经 io.refill 向仲裁器发整行读请求填充；
 * store 经 io.write（AXI4 写通道）写直通主存。
 * 框架：端口与连接已定义，内部实现留空。
 */
class DCache(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val cpu    = Flipped(new CacheCpuIO(p))   // LSU 侧
    val refill = new RefillIO(p)              // → 总线仲裁器（行填充）
    val write  = new AxiWriteMasterIO(p)      // → AXI4 写通道（写直通）
  })

  // TODO: tag/data 阵列、组相联查找、写直通下发、填充状态机
  io.cpu.req.ready    := false.B
  io.cpu.resp.valid   := false.B
  io.cpu.resp.data    := 0.U
  io.refill.req.valid := false.B
  io.refill.req.addr  := 0.U
  io.write.awaddr     := 0.U
  io.write.awid       := 0.U
  io.write.awlen      := 0.U
  io.write.awsize     := 0.U
  io.write.awburst    := 0.U
  io.write.awvalid    := false.B
  io.write.wdata      := 0.U
  io.write.wstrb      := 0.U
  io.write.wlast      := false.B
  io.write.wvalid     := false.B
  io.write.bready     := false.B
}
