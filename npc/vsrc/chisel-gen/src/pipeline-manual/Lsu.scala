package pipeline_manual

import chisel3._
import chisel3.util._

/** LSU（MEM 级）：封装 DCache，完成 load 数据抽取/符号扩展，
  *   - 产生 MEM/WB 寄存器；store 经 Cache 写直通到 Store Buffer。
  */
class Lsu(p: CoreParams) extends Module {
  val io    = IO(new Bundle {
    val cache = new CacheIO(p)
    val in    = Flipped(Decoupled(new ExBundle(p)))
    val out   = Decoupled(new LsBundle(p))
    val kill  = Input(Bool()) // WBU 陷阱/MRET：冲刷 EX/MEM 及其后
  })
  val in    = io.in.bits
  val v     = io.in.valid
  val memOp = v && (in.ctrl.load || in.ctrl.store)

  // ---------------- 字节使能 ----------------
  val addr  = in.aluResult
  val wstrb = MuxLookup(in.ctrl.memOp, 0.U)(
    Seq(
      MemOp.SB -> (1.U(4.W) << addr(1, 0)),                   // SB
      MemOp.SH -> Mux(addr(1) === 1.U, "b1100".U, "b0011".U), // SH
      MemOp.SW -> "b1111".U                                   // SW
    )
  )

  // ---------------- Cache 请求 ----------------
  io.cache.req.valid   := memOp && !io.kill && in.ctrl.load // TODO 暂时忽略allowStore的逻辑
  io.cache.req.addr    := addr
  io.cache.req.wdata   := in.storeData
  io.cache.req.wstrb   := wstrb
  io.cache.req.isWrite := in.ctrl.store

  // ---------------- 缓存握手 ----------------
  val busy     = RegInit(false.B)
  val reqFire  = !busy && memOp && io.cache.req.valid && io.cache.req.ready
  val respFire = busy && io.cache.resp.valid
  when(respFire) { busy := false.B }
  when(reqFire) { busy := true.B }

  // EX/LS 在本周期被消费（写入 LS/WB），下一周期可装载
  val consume = Mux(busy, respFire, !memOp)
  io.in.ready := consume

  // ---------------- load 数据抽取 ----------------
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

  // ---------------- 流水线寄存器 ----------------
  val lsValid = RegInit(false.B)
  val lsReg   = Reg(new LsBundle(p))
  when(io.kill) {
    lsValid := false.B
  }.elsewhen(consume) {
    lsValid         := v
    lsReg.pc        := in.pc
    lsReg.aluResult := in.aluResult
    lsReg.loadData  := loadData
    lsReg.rdAddr    := in.rdAddr
    lsReg.ctrl      := in.ctrl
    lsReg.csrAddr   := in.csrAddr
    lsReg.csrWdata  := in.csrWdata
    lsReg.csrRdata  := in.csrRdata
    lsReg.excValid  := in.excValid
    lsReg.excCause  := in.excCause
  }

  io.out.bits  := lsReg
  io.out.valid := lsValid
}
