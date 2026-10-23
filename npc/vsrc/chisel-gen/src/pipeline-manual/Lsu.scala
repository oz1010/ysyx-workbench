package pipeline_manual

import chisel3._
import chisel3.util._
import scala.language.reflectiveCalls
import config.AutoConfig._
import config.ManuConfig._

/** LSU：单笔 CacheIO 访存，锁存响应以承受 WB 反压，load 按原始字节 lane 抽取。
  * 冲刷后排空已接受请求的响应，不将旧响应交给新指令；已发出的 store 无法撤销。
  */
class Lsu() extends Module {
  val io = IO(new Bundle {
    val cache = new CacheIO()
    val in    = Flipped(Decoupled(new ExBundle()))
    val out   = Decoupled(new LsBundle())
    val kill  = Input(Bool())
  })

  val in = io.in.bits
  val isMemInst = (in.ctrl.isLoad || in.ctrl.isStore) && !in.expt.en
  val pending = RegInit(false.B)
  val discard = RegInit(false.B)
  val responseValid = RegInit(false.B)
  val responseData = Reg(UInt(CONFIG_DATA_WIDTH.W))

  // 每条访存只接受一次请求；响应与下游消费解耦，不因反压重发 store。
  io.cache.req.valid := io.in.valid && isMemInst && !io.kill && !reset.asBool &&
    !pending && !responseValid && !discard
  io.cache.req.addr  := in.aluResult
  io.cache.req.op    := in.ctrl.memOp
  io.cache.req.wdata := in.storeData
  io.cache.rsp.ready := pending || io.cache.req.fire
  when(io.cache.req.fire) {
    pending := true.B
  }
  when(io.cache.rsp.fire) {
    pending := false.B
    discard := false.B
    when(!discard && !io.kill) {
      responseValid := true.B
      responseData  := io.cache.rsp.data
    }
  }
  when(io.out.fire) {
    responseValid := false.B
  }
  when(io.kill) {
    responseValid := false.B
    when(pending && !io.cache.rsp.fire) {
      discard := true.B
    }
  }

  val addr = in.aluResult
  val rdata = responseData
  val off = addr(1, 0)
  val byteSel = Mux(
    off(1),
    Mux(off(0), rdata(31, 24), rdata(23, 16)),
    Mux(off(0), rdata(15, 8), rdata(7, 0))
  )
  val halfSel = Mux(off(1), rdata(31, 16), rdata(15, 0))
  val loadData = MuxLookup(in.ctrl.memOp, rdata)(
    Seq(
      MemOp.LB  -> Cat(Fill(24, byteSel(7)), byteSel),
      MemOp.LH  -> Cat(Fill(16, halfSel(15)), halfSel),
      MemOp.LW  -> rdata,
      MemOp.LBU -> Cat(0.U(24.W), byteSel),
      MemOp.LHU -> Cat(0.U(16.W), halfSel)
    )
  )

  // 带异常的访存不访问 Cache，直接把完整异常信息送往 WB。
  val memWait = isMemInst && !responseValid
  io.in.ready           := io.out.ready && !memWait && !io.kill
  io.out.valid          := io.in.valid && !memWait && !io.kill
  io.out.bits.pc        := in.pc
  io.out.bits.dnpc      := in.dnpc
  io.out.bits.aluResult := in.aluResult
  io.out.bits.loadData  := loadData
  io.out.bits.rdAddr    := in.rdAddr
  io.out.bits.ctrl      := in.ctrl
  io.out.bits.csrAddr   := in.csrAddr
  io.out.bits.csrWdata  := in.csrWdata
  io.out.bits.csrRdata  := in.csrRdata
  io.out.bits.expt      := in.expt
}
