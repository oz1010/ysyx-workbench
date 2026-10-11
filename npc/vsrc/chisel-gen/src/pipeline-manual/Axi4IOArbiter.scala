package pipeline_manual

import chisel3._
import chisel3.util._

/** 总线仲裁器：仲裁 ICache / DCache 的行填充请求，共用 AXI4 读通道。 主设备单一，ID 恒为 0；写通道由 DCache 写直通直连
  * io_master，不经仲裁器。 框架：端口与连接已定义，内部实现留空。
  */
// TODO 2. 输入应该是一个axi4通道数组 3. 读写分离
class Axi4IOArbiter(
  p: CoreParams,
  ClientNum: Int
) extends Module {

  require(ClientNum > 0, "ClientNum must be greater than 0")

  val io = IO(new Bundle {
    val clients = Vec(ClientNum, Flipped(new Axi4IO(p))) // 将客户端请求分发到总线上
    val master  = new Axi4IO(p)
  })

  // TODO 读通道仲裁
  for (i <- 0 until ClientNum) {
    io.clients(i).arready := false.B
    io.clients(i).rvalid  := false.B
    io.clients(i).rdata   := 0.U
    io.clients(i).rresp   := 0.U
    io.clients(i).rlast   := false.B
    io.clients(i).rid     := 0.U
  }

  // TODO 写通道仲裁
  for (i <- 0 until ClientNum) {
    io.clients(i).awready := false.B
    io.clients(i).wready  := false.B
    io.clients(i).bvalid  := false.B
    io.clients(i).bresp   := 0.U
    io.clients(i).bid     := 0.U
  }

  // TODO: 请求优先级仲裁、AR 突发（arlen/arsize/arburst）与 R 通道数据分发
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
