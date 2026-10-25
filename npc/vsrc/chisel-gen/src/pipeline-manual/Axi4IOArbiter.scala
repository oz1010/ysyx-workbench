package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._

/** 通用 AXI4 仲裁器：读写独立轮询，每个方向最多一笔在途事务，ID 原样透传。
  * 读授权保持到最后一拍 R 握手，写授权保持到 B 握手；AW / W 可独立握手。
  */
class Axi4IOArbiter(
  ClientNum: Int
) extends Module {
  require(ClientNum > 0, "ClientNum must be greater than 0")
  val indexWidth = math.max(1, log2Ceil(ClientNum))

  val io = IO(new Bundle {
    val clients = Vec(ClientNum, Flipped(new Axi4IO()))
    val master  = new Axi4IO()
  })

  val rIdle :: rAddr :: rData :: Nil = Enum(3)
  val readState                     = RegInit(rIdle)
  val readGrant                     = RegInit(0.U(indexWidth.W))
  val wIdle :: wRequest :: wResponse :: Nil = Enum(3)
  val writeState                          = RegInit(wIdle)
  val writeGrant                          = RegInit(0.U(indexWidth.W))
  val awDone                              = RegInit(false.B)
  val wDone                               = RegInit(false.B)

  Axi4MasterDefaults(io.master)
  for (client <- io.clients) {
    Axi4SlaveDefaults(client)
  }

  // 先锁定客户端，再驱动总线，保证地址背压期间授权不会随新请求变化。
  val readArbiter  = Module(new RRArbiter(UInt(indexWidth.W), ClientNum))
  val writeArbiter = Module(new RRArbiter(UInt(indexWidth.W), ClientNum))
  for (i <- 0 until ClientNum) {
    readArbiter.io.in(i).valid  := io.clients(i).arvalid
    readArbiter.io.in(i).bits   := i.U
    writeArbiter.io.in(i).valid := io.clients(i).awvalid || io.clients(i).wvalid
    writeArbiter.io.in(i).bits  := i.U
  }
  readArbiter.io.out.ready  := readState === rIdle
  writeArbiter.io.out.ready := writeState === wIdle

  when(readArbiter.io.out.fire) {
    readGrant := readArbiter.io.out.bits
    readState := rAddr
  }
  when(writeArbiter.io.out.fire) {
    writeGrant := writeArbiter.io.out.bits
    writeState := wRequest
    awDone     := false.B
    wDone      := false.B
  }

  val readClient  = if (ClientNum == 1) io.clients(0) else io.clients(readGrant)
  val writeClient = if (ClientNum == 1) io.clients(0) else io.clients(writeGrant)

  io.master.araddr  := readClient.araddr
  io.master.arid    := readClient.arid
  io.master.arlen   := readClient.arlen
  io.master.arsize  := readClient.arsize
  io.master.arburst := readClient.arburst

  when(readState === rAddr) {
    io.master.arvalid  := readClient.arvalid
    readClient.arready := io.master.arready
    when(io.master.arFire) {
      readState := rData
    }
  }
  when(readState === rData) {
    readClient.rvalid := io.master.rvalid
    readClient.rdata  := io.master.rdata
    readClient.rresp  := io.master.rresp
    readClient.rlast  := io.master.rlast
    readClient.rid    := io.master.rid
    io.master.rready  := readClient.rready
    when(io.master.rFire && io.master.rlast) {
      readState := rIdle
    }
  }

  io.master.awaddr  := writeClient.awaddr
  io.master.awid    := writeClient.awid
  io.master.awlen   := writeClient.awlen
  io.master.awsize  := writeClient.awsize
  io.master.awburst := writeClient.awburst
  io.master.wdata   := writeClient.wdata
  io.master.wstrb   := writeClient.wstrb
  io.master.wlast   := writeClient.wlast

  when(writeState === wRequest) {
    io.master.awvalid   := writeClient.awvalid && !awDone
    writeClient.awready := io.master.awready && !awDone
    io.master.wvalid    := writeClient.wvalid && !wDone
    writeClient.wready  := io.master.wready && !wDone

    when(io.master.awFire) {
      awDone := true.B
    }
    when(io.master.wFire && io.master.wlast) {
      wDone := true.B
    }
    when(
      (awDone || io.master.awFire) &&
        (wDone || (io.master.wFire && io.master.wlast))
    ) {
      writeState := wResponse
    }
  }
  when(writeState === wResponse) {
    writeClient.bvalid := io.master.bvalid
    writeClient.bresp  := io.master.bresp
    writeClient.bid    := io.master.bid
    io.master.bready   := writeClient.bready
    when(io.master.bFire) {
      writeState := wIdle
    }
  }
}
