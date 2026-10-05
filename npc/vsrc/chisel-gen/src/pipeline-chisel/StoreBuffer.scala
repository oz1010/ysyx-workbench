package pipeline_chisel

import chisel3._
import chisel3.util._

/**
 * 写直通 Store Buffer：
 *   DCache 的 store 只写入本缓冲即返回（不等待 AXI 完成）；
 *   缓冲以单 beat AXI 写（awlen=0, awsize=2, INCR）发往总线，深度可配。
 */
class StoreBuffer(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    // Store Buffer 是消费方（ready 输出）
    val enq = new Bundle {
      val valid = Input(Bool())
      val ready = Output(Bool())
      val bits  = Input(new StoreReq(p))
    }
    // AXI4 写通道（直接挂到 master 口）
    val awaddr  = Output(UInt(p.ADDR_WIDTH.W))
    val awlen   = Output(UInt(8.W))
    val awsize  = Output(UInt(3.W))
    val awburst = Output(UInt(2.W))
    val awvalid = Output(Bool())
    val awready = Input(Bool())
    val wdata   = Output(UInt(p.DATA_WIDTH.W))
    val wstrb   = Output(UInt((p.DATA_WIDTH / 8).W))
    val wlast   = Output(Bool())
    val wvalid  = Output(Bool())
    val wready  = Input(Bool())
    val bvalid  = Input(Bool())
    val bready  = Output(Bool())
  })

  val queue = Module(new Queue(new StoreReq(p), p.STORE_BUF_DEPTH))
  queue.io.enq <> io.enq

  val sIdle :: sAw :: sW :: sB :: Nil = Enum(4)
  val state = RegInit(sIdle)
  val cur   = Reg(new StoreReq(p))

  // 输出默认值
  io.awaddr := 0.U; io.awlen := 0.U; io.awsize := 0.U; io.awburst := 0.U
  io.awvalid := false.B
  io.wdata := 0.U; io.wstrb := 0.U; io.wlast := false.B
  io.wvalid := false.B
  io.bready := false.B
  queue.io.deq.ready := false.B

  switch(state) {
    is(sIdle) {
      when(queue.io.deq.valid) {
        cur := queue.io.deq.bits
        state := sAw
      }
    }
    is(sAw) {
      io.awvalid := true.B
      io.awaddr  := cur.addr
      io.awlen   := 0.U
      io.awsize  := 2.U // 4 字节
      io.awburst := 1.U // INCR
      when(io.awready) { state := sW }
    }
    is(sW) {
      io.wvalid := true.B
      io.wdata  := cur.data
      io.wstrb  := cur.strb
      io.wlast  := true.B
      when(io.wready) {
        queue.io.deq.ready := true.B
        state := sB
      }
    }
    is(sB) {
      io.bready := true.B
      when(io.bvalid) { state := sIdle }
    }
  }
}
