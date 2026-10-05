package pipeline_chisel

import chisel3._
import chisel3.util._

object State extends ChiselEnum {
  val sIdle, sRead = Value
}
import State._

/**
 * AXI4 读通道仲裁器：ICache 与 DCache 的行读(refill)请求共用一组 AR/R 通道。
 *   - DCache 优先，轮询(rr)保证公平；
 *   - 同一时间只允许一个 burst 在读通道上（简单且可靠）；
 *   - 写通道由 StoreBuffer 独立驱动，与读通道并行。
 */
class BusArbiter(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val icache = new RefillSlaveIO(p)
    val dcache = new RefillSlaveIO(p)
    // AXI4 读通道
    val araddr  = Output(UInt(p.ADDR_WIDTH.W))
    val arlen   = Output(UInt(8.W))
    val arsize  = Output(UInt(3.W))
    val arburst = Output(UInt(2.W))
    val arvalid = Output(Bool())
    val arready = Input(Bool())
    val rdata   = Input(UInt(p.DATA_WIDTH.W))
    val rvalid  = Input(Bool())
    val rlast   = Input(Bool())
    val rready  = Output(Bool())
  })

  // val sIdle :: sRead :: Nil = Enum(2)
  val state  = RegInit(sIdle)
  val grantD = RegInit(false.B) // 当前读归属：true = DCache
  val rr     = RegInit(false.B) // true = 下轮 ICache 优先

  val iReq = io.icache.req.valid
  val dReq = io.dcache.req.valid
  // 选择：rr 时 ICache 优先，否则 DCache 优先
  val selI = iReq && (rr || !dReq)
  val selD = dReq && (!rr || !iReq)

  io.arlen   := (p.LINE_WORDS - 1).U
  io.arsize  := 2.U
  io.arburst := 1.U // INCR

  // 输出默认值
  io.araddr := 0.U
  io.arvalid := false.B
  io.rready := false.B
  io.icache.gnt := false.B
  io.dcache.gnt := false.B
  io.icache.resp.valid := false.B
  io.dcache.resp.valid := false.B
  io.icache.resp.data  := 0.U
  io.dcache.resp.data  := 0.U
  io.icache.resp.last  := false.B
  io.dcache.resp.last  := false.B

  switch(state) {
    is(sIdle) {
      when(selI || selD) {
        io.arvalid := true.B
        io.araddr  := Mux(selD, io.dcache.req.addr, io.icache.req.addr)
        when(io.arready) {
          grantD := selD
          rr     := selI // 服务完一方后，另一方获得下轮优先权
          state  := sRead
        }
        // 授权与 AR 握手同周期给出，Cache 随后进入 sRefill 收数，不会丢首拍
        io.dcache.gnt := selD
        io.icache.gnt := selI
      }
    }
    is(sRead) {
      io.rready := true.B
      when(grantD) {
        io.dcache.resp.valid := io.rvalid
        io.dcache.resp.data  := io.rdata
        io.dcache.resp.last  := io.rlast
      }.otherwise {
        io.icache.resp.valid := io.rvalid
        io.icache.resp.data  := io.rdata
        io.icache.resp.last  := io.rlast
      }
      when(io.rvalid && io.rlast) { state := sIdle }
    }
  }
}
