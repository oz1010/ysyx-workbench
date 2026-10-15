package pipeline_manual

import chisel3._
import chisel3.util._

/** LSU（MEM 级）：封装 DCache，完成 load 数据抽取/符号扩展，
  *   - 产生 MEM/WB 寄存器；store 经 Cache 写直通到 Store Buffer。
  */
class Lsu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val cache = new CacheIO(p)
    val in    = Flipped(Decoupled(new ExBundle(p)))
    val out   = Decoupled(new LsBundle(p))
    val kill  = Input(Bool()) // WBU 陷阱/MRET：冲刷 EX/MEM 及其后
  })

  val in        = io.in.bits
  val isMemInst = in.ctrl.load || in.ctrl.store

  // 字节使能
  val addr  = in.aluResult
  val wstrb = MuxLookup(in.ctrl.memOp, 0.U)(
    Seq(
      MemOp.SB -> (1.U(4.W) << addr(1, 0)),                   // SB
      MemOp.SH -> Mux(addr(1) === 1.U, "b1100".U, "b0011".U), // SH
      MemOp.SW -> "b1111".U                                   // SW
    )
  )

  // dcache请求
  io.cache.req.valid   := io.in.valid && isMemInst && !io.kill
  io.cache.req.addr    := addr
  io.cache.req.wdata   := in.storeData
  io.cache.req.wstrb   := wstrb
  io.cache.req.isWrite := in.ctrl.store
  val memWait = isMemInst && !io.cache.resp.valid

  // load 数据抽取
  val rdata    = io.cache.resp.data
  val off      = addr(1, 0)
  val byteSel  = Mux(
    off(1),
    Mux(off(0), rdata(31, 24), rdata(23, 16)),
    Mux(off(0), rdata(15, 8), rdata(7, 0))
  )
  val halfSel  = Mux(off(1), rdata(31, 16), rdata(15, 0))
  val loadData = MuxLookup(in.ctrl.memOp, rdata)(
    Seq(
      MemOp.LB  -> Cat(Fill(24, byteSel(7)), byteSel),  // LB
      MemOp.LH  -> Cat(Fill(16, halfSel(15)), halfSel), // LH
      MemOp.LW  -> rdata,                               // LW
      MemOp.LBU -> Cat(0.U(24.W), byteSel),             // LBU
      MemOp.LHU -> Cat(0.U(16.W), halfSel)              // LHU
    )
  )

  // 流水线处理
  io.in.ready           := io.out.ready && !memWait
  io.out.valid          := io.in.valid && !memWait && !io.kill
  io.out.bits.pc        := in.pc
  io.out.bits.aluResult := in.aluResult
  io.out.bits.loadData  := loadData
  io.out.bits.rdAddr    := in.rdAddr
  io.out.bits.ctrl      := in.ctrl
  io.out.bits.csrAddr   := in.csrAddr
  io.out.bits.csrWdata  := in.csrWdata
  io.out.bits.csrRdata  := in.csrRdata
  io.out.bits.excValid  := in.excValid
  io.out.bits.excCause  := in.excCause
}
