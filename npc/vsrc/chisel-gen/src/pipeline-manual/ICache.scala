package pipeline_manual

import chisel3._
import chisel3.util._

class ICache(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val cpu    = Flipped(new CacheIO(p))
    val master = new Axi4IO(p)
  })

  // TODO 临时关闭功能
  io.cpu.req.ready  := 0.U
  io.cpu.resp.valid := 0.U
  io.cpu.resp.data  := 0.U
  // TODO 临时禁用读
  io.master.arvalid := false.B
  io.master.araddr  := 0.U
  io.master.arid    := 0.U
  io.master.arlen   := 0.U
  io.master.arsize  := 0.U
  io.master.arburst := 0.U
  io.master.rready  := false.B
  // TODO 禁用写
  io.master.awvalid := false.B
  io.master.awaddr  := 0.U
  io.master.awid    := 0.U
  io.master.awlen   := 0.U
  io.master.awsize  := 0.U
  io.master.awburst := 0.U
  io.master.wvalid  := false.B
  io.master.wdata   := 0.U
  io.master.wstrb   := 0.U
  io.master.wlast   := 0.U
  io.master.bready  := false.B
}
