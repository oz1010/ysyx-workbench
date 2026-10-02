package rv32e

import chisel3._
import chisel3.util._

/**
 * RV32E 五级流水线核顶层。
 *   IFU --(IF/ID)--> IDU --(ID/EX)--> EXU --(EX/MEM)--> LSU --(MEM/WB)--> WBU
 *   ICache/DCache 经仲裁器共用 AXI4 读通道；store 经 StoreBuffer 走写通道。
 */
class Rv32eCore(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val interrupt = Input(Bool())
    val master    = new Axi4MasterIO(p)
    val pc        = Output(UInt(p.ADDR_WIDTH.W)) // 当前取指 PC（关键输出）
  })

  // ---------------- 子模块 ----------------
  val ifu  = Module(new Ifu(p))
  val idu  = Module(new Idu(p))
  val exu  = Module(new Exu(p))
  val lsu  = Module(new Lsu(p))
  val wbu  = Module(new Wbu(p))
  val icache = Module(new Cache(p, p.ICACHE_LINES, readOnly = true))
  val arbiter = Module(new BusArbiter(p))
  val sbuffer = Module(new StoreBuffer(p))

  // ---------------- AXI 连接 ----------------
  icache.io.cpu    <> ifu.io.cache
  icache.io.refill <> arbiter.io.icache
  lsu.io.refill     <> arbiter.io.dcache
  lsu.io.storeEnq  <> sbuffer.io.enq

  io.master.araddr  := arbiter.io.araddr
  io.master.arlen   := arbiter.io.arlen
  io.master.arsize  := arbiter.io.arsize
  io.master.arburst := arbiter.io.arburst
  io.master.arvalid := arbiter.io.arvalid
  arbiter.io.arready := io.master.arready
  arbiter.io.rdata   := io.master.rdata
  arbiter.io.rvalid  := io.master.rvalid
  arbiter.io.rlast   := io.master.rlast
  io.master.rready   := arbiter.io.rready

  io.master.awaddr  := sbuffer.io.awaddr
  io.master.awlen   := sbuffer.io.awlen
  io.master.awsize  := sbuffer.io.awsize
  io.master.awburst := sbuffer.io.awburst
  io.master.awvalid := sbuffer.io.awvalid
  sbuffer.io.awready := io.master.awready
  io.master.wdata   := sbuffer.io.wdata
  io.master.wstrb   := sbuffer.io.wstrb
  io.master.wlast   := sbuffer.io.wlast
  io.master.wvalid  := sbuffer.io.wvalid
  sbuffer.io.wready := io.master.wready
  sbuffer.io.bvalid := io.master.bvalid
  io.master.bready  := sbuffer.io.bready

  // ---------------- IFU ----------------
  ifu.io.wbRedirect := wbu.io.redirect
  ifu.io.exRedirect := exu.io.redirect

  // ---------------- IDU ----------------
  idu.io.ifid       := ifu.io.ifid
  idu.io.ifidValid  := ifu.io.ifidValid
  idu.io.exRedirect := exu.io.redirect
  idu.io.wbRedirect := wbu.io.redirect
  idu.io.rfWen      := wbu.io.rfWen
  idu.io.rfRd       := wbu.io.rfRd
  idu.io.rfData     := wbu.io.rfData

  // ---------------- 冒险 / 流水线推进 ----------------
  // lsuConsume：LSU 本周期消费 EX/MEM（非访存直通 / 访存响应返回）
  // EX/MEM 与 ID/EX 同步装载（lsuConsume 时）；load-use 时 IF/ID 保持、
  // ID/EX 插气泡（在 IDU 内完成），故 EX/MEM 恒与 ID/EX 配对前进，不会重复执行。
  val lsuConsume = lsu.io.exReady
  val idAdvance  = lsuConsume && !idu.io.loadStall
  idu.io.idReady := lsuConsume
  ifu.io.consume := idAdvance

  // ---------------- EX/MEM 寄存器 ----------------
  val exmemValid = RegInit(false.B)
  val exmem      = Reg(new ExMemBundle(p))
  when(wbu.io.redirect.valid) {
    exmemValid := false.B // 陷阱/MRET：younger 指令作废
  }.elsewhen(lsuConsume) {
    exmem      := exu.io.out
    exmemValid := idu.io.idexValid // 分支指令本身继续流动，仅冲刷其 younger 级
  }

  // ---------------- EXU ----------------
  exu.io.idex      := idu.io.idex
  exu.io.idexValid := idu.io.idexValid
  exu.io.memStage  := exmem
  exu.io.memValid  := exmemValid
  exu.io.wbStage   := lsu.io.memwb
  exu.io.wbValid   := lsu.io.memwbValid
  exu.io.wbData    := wbu.io.rfData
  exu.io.csrRdata  := wbu.io.csrRdata

  // ---------------- LSU ----------------
  lsu.io.exmem      := exmem
  lsu.io.exmemValid := exmemValid
  lsu.io.kill       := wbu.io.redirect.valid
  // store 只有在"更老指令不可能陷入/中断"时才允许下发，防止错误路径上的 store 提交
  val olderCanTrap = lsu.io.memwbValid &&
    (lsu.io.memwb.excValid || lsu.io.memwb.ctrl.mret)
  lsu.io.allowStore := !io.interrupt && !olderCanTrap && !wbu.io.redirect.valid

  // ---------------- WBU ----------------
  wbu.io.memwb      := lsu.io.memwb
  wbu.io.memwbValid := lsu.io.memwbValid
  wbu.io.interrupt  := io.interrupt
  wbu.io.csrRaddr   := exu.io.csrRaddr

  io.pc := ifu.io.pc
}

/**
 * 对外封装：显式 clk / rst（同步高有效复位）端口。
 */
class Rv32eTop(p: CoreParams) extends RawModule {
  val io = IO(new Bundle {
    val clk       = Input(Clock())
    val rst       = Input(Bool()) // 同步复位，高有效
    val interrupt = Input(Bool())
    val master    = new Axi4MasterIO(p)
    val pc        = Output(UInt(p.ADDR_WIDTH.W))
  })

  val core = withClockAndReset(io.clk, io.rst) { Module(new Rv32eCore(p)) }
  core.io.interrupt := io.interrupt
  core.io.master    <> io.master
  io.pc             := core.io.pc
}
