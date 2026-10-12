package pipeline_manual

import chisel3._
import chisel3.util._

/** ICache：直通取指（passthrough，无缓存阵列）。 CPU 请求 -> AXI4 单拍读（arlen=0, INCR）-> 返回数据回传
  * CPU。 io.cpu.resp 脉冲一拍（IFU 在 resp.valid 且 reqPend 时无条件消费并回 idle）。
  */
class ICache(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val cpu    = Flipped(new CacheIO(p))
    val master = new Axi4IO(p)
  })

  // 禁用写通道
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

  // AXI4 固定参数：单一主设备，单拍 INCR 读
  io.master.arid    := Axi4ID.ICACHE.asUInt
  io.master.arlen   := 0.U                          // burst数量，2^n字节
  io.master.arsize  := log2Ceil(p.DATA_WIDTH / 8).U // 单个burst数据大小，2^n字节
  io.master.arburst := 1.U                          // 01=INCR

  val sIdle :: sRunning :: Nil = Enum(2)
  val state                    = RegInit(sIdle)
  val cpuReqDone               = io.cpu.req.valid && io.cpu.req.ready
  val axi4ARDone               = io.master.arvalid && io.master.arready
  val axi4RDone                = io.master.rvalid && io.master.rready

  // ---------------- CPU 读请求响应 ----------------
  val ready = RegInit(false.B)
  ready             := true.B
  io.cpu.req.ready  := state === sIdle && ready
  when(cpuReqDone) {
    state := sRunning
  }.elsewhen(axi4RDone) {
    state := sIdle
  }
  io.cpu.resp.valid := axi4RDone
  io.cpu.resp.data  := io.master.rdata

  // ---------------- AXI4 读地址通道 ----------------
  val arvalid   = RegInit(false.B)
  val araddrReg = RegEnable(io.cpu.req.addr, cpuReqDone)
  when(axi4ARDone) {
    arvalid := false.B
  }.elsewhen(cpuReqDone) {
    arvalid := true.B
  }
  io.master.arvalid := cpuReqDone || arvalid
  io.master.araddr := Mux(cpuReqDone, io.cpu.req.addr, araddrReg)

  // ---------------- AXI4 读通道 ----------------
  val rready = RegInit(false.B)
  io.master.rready := rready
  when(cpuReqDone) {
    rready := true.B
  }.elsewhen(axi4RDone) {
    rready := false.B
    assert(io.master.rlast)
  }
}
