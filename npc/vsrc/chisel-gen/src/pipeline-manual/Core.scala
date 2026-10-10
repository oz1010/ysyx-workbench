package pipeline_manual

import chisel3._
import chisel3.util._

/** RV32E 五级流水线核（内部顶层，Chisel 隐式 clock/reset）。 IFU --(IF/ID)--> IDU --(ID/EX)-->
  * EXU --(EX/MEM)--> LSU --(MEM/WB)--> WBU 每级间均为 valid/ready 握手（Decoupled）；
  * ICache/DCache 经仲裁器共用 AXI4 读通道，store 由 DCache 写直通 AXI4 写通道。
  * 框架：模块例化与信号连接已完成，各模块内部实现留空。
  */
class Rv32eCore(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val interrupt = Input(Bool()) // io_interrupt
    val master = new Axi4IO(p) // io_master（AXI4 主设备）
    val pc = Output(UInt(p.ADDR_WIDTH.W)) // 当前取指 PC（关键输出）
    val valid = Output(Bool()) // 完成一条指令（单周期脉冲）
  })

  // ---------------- 子模块 ----------------
  val ifu = Module(new Ifu(p))
  val idu = Module(new Idu(p))
  val exu = Module(new Exu(p))
  val lsu = Module(new Lsu(p))
  val wbu = Module(new Wbu(p))
  val icache = Module(new ICache(p))
  val dcache = Module(new DCache(p))
  val arbiter = Module(new Axi4IOArbiter(p, 2))
  val gpr = Module(new GprFile(p))
  val csr = Module(new CsrFile(p))

  // ---------------- 流水线级间握手 ----------------
  ifu.io.out <> idu.io.in
  idu.io.out <> exu.io.in
  exu.io.out <> lsu.io.in
  lsu.io.out <> wbu.io.in
  wbu.io.out.ready := true.B

  // ---------------- 重定向（WBU 陷阱/MRET > EX 预测修正） ----------------
  ifu.io.exRedirect := exu.io.redirect
  ifu.io.wbRedirect := wbu.io.redirect
  lsu.io.kill := wbu.io.redirect.valid

  // ---------------- GSR ----------------
  gpr.io.read1 <> idu.io.gprRead1
  gpr.io.read2 <> idu.io.gprRead2
  gpr.io.write <> wbu.io.gprWrite

  // ---------------- CSR ----------------
  csr.io.read <> exu.io.csrRead
  csr.io.write <> wbu.io.csrWrite
  csr.io.trap <> wbu.io.csrTrap
  // csr.io.mret  := wbu.io.csrMret

  // ---------------- ICache ----------------
  icache.io.cpu <> ifu.io.cache
  icache.io.master <> arbiter.io.clients(0)

  // ---------------- DCache ----------------
  dcache.io.cpu <> lsu.io.cache
  dcache.io.master <> arbiter.io.clients(1)

  // ---------------- AXI4仲裁器 ----------------
  io.master <> arbiter.io.master

  // ---------------- WBU 中断 ----------------
  wbu.io.interrupt := io.interrupt

  // ---------------- 关键输出 ----------------
  io.pc := wbu.io.out.bits.pc
  io.valid := wbu.io.out.valid
}

/** 对外顶层（drop-in 替代 npc 手写 riscv32e_core）：
  *   - RawModule，显式 clk / rst（同步高有效复位）端口；
  *   - 端口名与 npc 例化完全一致（io_interrupt / io_master_* / pc / valid）。
  */
class riscv32e_core(p: CoreParams) extends RawModule {
  val clk = IO(Input(Clock()))
  val rst = IO(Input(Bool())) // 同步复位，高有效
  val io_interrupt = IO(Input(Bool()))
  val io_master = IO(new Axi4IO(p))
  val pc = IO(Output(UInt(p.ADDR_WIDTH.W)))
  val valid = IO(Output(Bool())) // 完成一条指令（单周期脉冲）

  val core = withClockAndReset(clk, rst) { Module(new Rv32eCore(p)) }
  core.io.interrupt := io_interrupt
  io_master <> core.io.master
  pc := core.io.pc
  valid := core.io.valid
}
