package pipeline_chisel

import chisel3._
import chisel3.util._

/**
 * LSU（MEM 级）：封装 DCache，完成 load 数据抽取/符号扩展，
 * 产生 MEM/WB 寄存器；store 经 Cache 写直通到 Store Buffer。
 */
class Lsu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val exmem      = Input(new ExMemBundle(p))
    val exmemValid = Input(Bool())
    val exReady    = Output(Bool())     // EX/MEM 可装载新内容（可前递给 ID/EX）
    val kill       = Input(Bool())      // WBU 陷阱/MRET：冲刷 EX/MEM 及其后
    val allowStore = Input(Bool())      // 允许发出 store（无更老指令可能陷入/中断）
    val memwb      = Output(new MemWbBundle(p))
    val memwbValid = Output(Bool())
    val storeEnq   = new Bundle { // 生产方，接 StoreBuffer
      val valid = Output(Bool())
      val ready = Input(Bool())
      val bits  = Output(new StoreReq(p))
    }
    val refill = new RefillMasterIO(p) // DCache 行读请求，接总线仲裁器
  })

  val dcache = Module(new Cache(p, readOnly = false,
    W = p.CACHE_WAYS, N = p.CACHE_SET_BITS, M = p.CACHE_BLOCK_BITS))
  io.storeEnq <> dcache.store.get
  // refill 透传（请求：dcache 输出 -> LSU 输出；授权/数据：LSU 输入 -> dcache 输入）
  io.refill.req         := dcache.io.refill.req
  dcache.io.refill.gnt  := io.refill.gnt
  dcache.io.refill.resp := io.refill.resp

  val in    = io.exmem
  val v     = io.exmemValid
  val memOp = v && (in.ctrl.load || in.ctrl.store)

  // ---------------- 字节使能 ----------------
  val addr = in.aluResult
  val wstrb = MuxLookup(in.ctrl.memOp, 0.U)(Seq(
    0.U -> (1.U(4.W) << addr(1, 0)),          // SB
    1.U -> Mux(addr(1) === 1.U, "b1100".U, "b0011".U), // SH
    2.U -> "b1111".U                           // SW
  ))

  // ---------------- DCache 请求 ----------------
  dcache.io.cpu.req.valid   := memOp && !io.kill && (in.ctrl.load || io.allowStore)
  dcache.io.cpu.req.addr    := addr
  dcache.io.cpu.req.wdata   := in.storeData
  dcache.io.cpu.req.wstrb   := wstrb
  dcache.io.cpu.req.isWrite := in.ctrl.store

  // ---------------- MEM 级握手 ----------------
  val busy    = RegInit(false.B)
  val reqFire = !busy && memOp && dcache.io.cpu.req.ready && dcache.io.cpu.req.valid
  val respFire = busy && dcache.io.cpu.resp.valid

  when(respFire) { busy := false.B }
  when(reqFire)  { busy := true.B }

  // EX/MEM 在本周期被消费（写入 MEM/WB），下一周期可装载
  val consume = Mux(busy, respFire, !memOp)
  io.exReady := consume

  // ---------------- load 数据抽取 ----------------
  val rdata  = dcache.io.cpu.resp.data
  val off    = addr(1, 0)
  val byteSel = Mux(off(1), Mux(off(0), rdata(31, 24), rdata(23, 16)),
                              Mux(off(0), rdata(15, 8), rdata(7, 0)))
  val halfSel = Mux(off(1), rdata(31, 16), rdata(15, 0))
  val loadData = MuxLookup(in.ctrl.memOp, rdata)(Seq(
    0.U -> Cat(Fill(24, byteSel(7)), byteSel), // LB
    1.U -> Cat(Fill(16, halfSel(15)), halfSel), // LH
    2.U -> rdata,                               // LW
    4.U -> Cat(0.U(24.W), byteSel),             // LBU
    5.U -> Cat(0.U(16.W), halfSel)              // LHU
  ))

  // ---------------- MEM/WB 寄存器 ----------------
  val memwbValidReg = RegInit(false.B)
  val memwbReg      = Reg(new MemWbBundle(p))
  when(io.kill) {
    memwbValidReg := false.B // 冲刷：陷阱指令之后的 younger 指令作废
  }.elsewhen(consume) {
    memwbValidReg := v
    memwbReg.pc        := in.pc
    memwbReg.aluResult := in.aluResult
    memwbReg.loadData  := loadData
    memwbReg.rdAddr    := in.rdAddr
    memwbReg.ctrl      := in.ctrl
    memwbReg.csrAddr   := in.csrAddr
    memwbReg.csrWdata  := in.csrWdata
    memwbReg.csrRdata  := in.csrRdata
    memwbReg.excValid  := in.excValid
    memwbReg.excCause  := in.excCause
  }

  io.memwb      := memwbReg
  io.memwbValid := memwbValidReg
}
