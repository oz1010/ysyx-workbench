package pipeline_chisel2

import chisel3._
import chisel3.util._

/**
 * 总线仲裁器：仲裁 ICache / DCache 的行填充请求，共用 AXI4 读通道。
 * 主设备单一，ID 恒为 0；写通道由 DCache 写直通直连 io_master，不经仲裁器。
 * 框架：端口与连接已定义，内部实现留空。
 */
class BusArbiter(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val icache = Flipped(new RefillIO(p)) // ICache 行读请求
    val dcache = Flipped(new RefillIO(p)) // DCache 行读请求
    val master = new AxiReadMasterIO(p)   // → AXI4 读通道
  })

  // TODO: 请求优先级仲裁、AR 突发（arlen/arsize/arburst）与 R 通道数据分发
  io.icache.gnt        := false.B
  io.icache.resp.valid := false.B
  io.icache.resp.data  := 0.U
  io.icache.resp.last  := false.B
  io.dcache.gnt        := false.B
  io.dcache.resp.valid := false.B
  io.dcache.resp.data  := 0.U
  io.dcache.resp.last  := false.B
  io.master.araddr     := 0.U
  io.master.arid       := 0.U
  io.master.arlen      := 0.U
  io.master.arsize     := 0.U
  io.master.arburst    := 0.U
  io.master.arvalid    := false.B
  io.master.rready     := false.B
}
