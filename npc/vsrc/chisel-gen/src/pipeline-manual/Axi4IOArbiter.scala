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

  val indexWidth = log2Ceil(ClientNum)
  require(ClientNum > 0, "ClientNum must be greater than 0")

  val io = IO(new Bundle {
    val clients = Vec(ClientNum, Flipped(new Axi4IO(p))) // 将客户端请求分发到总线上
    val master  = new Axi4IO(p)
  })

  val sIdle :: sRead :: Nil = Enum(2)
  val state                 = RegInit(sIdle)
  val grantID               = RegInit(0.U(log2Ceil(ClientNum).W)) // 当前获得总线仲裁权的客户端 ID
  val rrPtr                 = RegInit(
    0.U(log2Ceil(ClientNum).W)
  ) // 轮询指针寄存器：记录上一次获得授权的客户端编号，公平调度的核心

  // -------------------------------------------------------------------------
  // 1. 默认驱动赋值（避免组合逻辑锁存器与默认高阻）
  // -------------------------------------------------------------------------

  // 默认对所有客户端的读通道反馈
  for (i <- 0 until ClientNum) {
    io.clients(i).arready := io.master.arready
    io.clients(i).rvalid  := false.B
    io.clients(i).rdata   := io.master.rdata
    io.clients(i).rresp   := io.master.rresp
    io.clients(i).rlast   := io.master.rlast
    io.clients(i).rid     := io.master.rid
  }

  // 默认Master读通道信号
  io.master.arvalid := false.B
  io.master.araddr  := 0.U
  io.master.arid    := 0.U
  io.master.arlen   := 0.U
  io.master.arsize  := 0.U
  io.master.arburst := 0.U
  io.master.rready  := false.B

  // TODO 临时禁用客户端写
  for (i <- 0 until ClientNum) {
    io.clients(i).awready := false.B
    io.clients(i).wready  := false.B
    io.clients(i).bvalid  := false.B
    io.clients(i).bresp   := 0.U
    io.clients(i).bid     := 0.U
  }

  // TODO 临时禁用写
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

  // -------------------------------------------------------------------------
  // 2. 仲裁逻辑与状态机实现
  // -------------------------------------------------------------------------
  val anyArvalid = io.clients.map(_.arvalid).reduce(_ || _)
  // 轮询仲裁：从 rrPtr 的下一个客户端开始优先查找，rrPtr 本身最后检查
  // candidates中是一个元组(arvalid,idx)...
  val candidates = (1 to ClientNum).map { offset =>
    val idx = (rrPtr +& offset.U) % ClientNum.U(indexWidth - 1, 0)
    io.clients(idx).arvalid -> idx
  }
  val chosenId   =
    Mux(anyArvalid, PriorityMux(candidates), 0.U(indexWidth - 1, 0))

  // -------------------------------------------------------------------------
  // 3. 状态机与指针更新
  // -------------------------------------------------------------------------
  switch(state) {
    is(sIdle) {
      when(anyArvalid) {
        grantID := chosenId
        state   := sRead
      }
    }
    is(sRead) {
      when(io.master.rvalid && io.master.rready && io.master.rlast) {
        rrPtr := ((grantID + 1.U) % ClientNum.U)(indexWidth - 1, 0)
        state := sIdle
      }
    }
  }

  // -------------------------------------------------------------------------
  // 4. 信号多路复用绑定master
  // -------------------------------------------------------------------------
  val currentClient = io.clients(grantID)
  switch(state) {
    is(sIdle) {
      when(anyArvalid) {
        // 条件是所有客户端arvalid逻辑综合，必须手动设置值
        io.master.arvalid := true.B
        io.master.araddr  := io.clients(chosenId).araddr
        io.master.arid    := io.clients(chosenId).arid
        io.master.arlen   := io.clients(chosenId).arlen
        io.master.arsize  := io.clients(chosenId).arsize
        io.master.arburst := io.clients(chosenId).arburst
      }
    }
    is(sRead) {
      // 在读突发传输中，保持当前 grantID 对应的 AR 信号（如果 AR 已经握手成功，arvalid 可以拉低，但地址总线可以保持稳定）
      io.master.arvalid := false.B
      io.master.araddr  := currentClient.araddr
      io.master.arid    := currentClient.arid
      io.master.arlen   := currentClient.arlen
      io.master.arsize  := currentClient.arsize
      io.master.arburst := currentClient.arburst

      // 将 Master 的读数据原封不动分发给当前获得仲裁权的客户端
      currentClient.rvalid := io.master.rvalid
      currentClient.rdata  := io.master.rdata
      currentClient.rresp  := io.master.rresp
      currentClient.rlast  := io.master.rlast
      currentClient.rid    := io.master.rid
      io.master.rready     := currentClient.rready
    }
  }
}
