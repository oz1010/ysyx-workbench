package pipeline_manual

import chisel3._
import chisel3.util._

/** RV32E 五级流水线核（内部顶层，Chisel 隐式 clock/reset）。 IFU --(IF/ID)--> IDU --(ID/EX)-->
  * EXU --(EX/MEM)--> LSU --(MEM/WB)--> WBU 每级间均为 valid/ready 握手（Decoupled）；
  * ICache/DCache 经仲裁器共用 AXI4 读通道，store 由 DCache 写直通 AXI4 写通道。
  * 框架：模块例化与信号连接已完成，各模块内部实现留空。
  */
class riscv32e_core(p: CoreParams) extends RawModule {
  val clk = IO(Input(Clock()))
  val rst = IO(Input(Bool())) // 同步复位，高有效
  val io_interrupt = IO(Input(Bool()))
  val io_master = IO(new Axi4IO(p))
  val pc = IO(Output(UInt(p.ADDR_WIDTH.W)))
  val valid = IO(Output(Bool())) // 完成一条指令（单周期脉冲）

  // val core = withClockAndReset(clk, rst) { Module(new Rv32eCore(p)) }
  // core.io.interrupt := io_interrupt
  // io_master <> core.io.master
  // pc := core.io.pc
  // valid := core.io.valid

  withClockAndReset(clk, rst) {
    // ---------------- 子模块 ----------------
    val ifu = Module(new Ifu(p))
    val idu = Module(new Idu(p))
    val exu = Module(new Exu(p))
    val lsu = Module(new Lsu(p))
    val wbu = Module(new Wbu(p))
    val icache = Module(new ICache(p))
    val dcache = Module(new DCache(p))
    val arbiter = Module(new Axi4IOArbiter(p, 2))
    val m_gprs = Module(new GprFile(p))
    val m_csrs = Module(new CsrFile(p))

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
    // TODO 增加调试信息
    // m_gprs.io.read1 <> idu.io.gprRead1
    m_gprs.io.read2 <> idu.io.gprRead2
    m_gprs.io.write <> wbu.io.gprWrite

    // ---------------- CSR ----------------
    // TODO 增加调试信息
    exu.io.csrRead.data := 0.U
    // m_csrs.io.read <> exu.io.csrRead
    // m_csrs.io.write <> wbu.io.csrWrite
    m_csrs.io.trap <> wbu.io.csrTrap
    // m_csrs.io.mret  := wbu.io.csrMret

    // ---------------- ICache ----------------
    icache.io.cpu <> ifu.io.cache
    icache.io.master <> arbiter.io.clients(0)

    // ---------------- DCache ----------------
    dcache.io.cpu <> lsu.io.cache
    dcache.io.master <> arbiter.io.clients(1)

    // ---------------- AXI4仲裁器 ----------------
    io_master <> arbiter.io.master

    // ---------------- WBU 中断 ----------------
    wbu.io.interrupt := io_interrupt

    // ---------------- 关键输出 ----------------
    // io.pc := wbu.io.out.bits.pc
    valid := wbu.io.out.valid

    // TODO 增加调试信息
    val core_pc = RegInit(0.U(p.ADDR_WIDTH.W))
    val core_dnpc = RegInit(0.U(p.ADDR_WIDTH.W))
    val core_gpraddr = RegInit(0.U(p.GPR_ADDR_W.W))
    idu.io.gprRead1.data := 0.U
    m_gprs.io.read1.en := true.B
    m_gprs.io.read1.addr := core_gpraddr
    m_csrs.io.read.en := true.B
    m_csrs.io.read.addr := core_gpraddr
    m_csrs.io.write.en := true.B
    m_csrs.io.write.addr := core_gpraddr
    m_csrs.io.write.data := core_pc
    core_gpraddr := core_gpraddr + 1.U
    when(wbu.io.gprWrite.en && wbu.io.gprWrite.addr(1) =/= 0.U) {
      core_pc := wbu.io.out.bits.pc
      core_dnpc := wbu.io.out.bits.pc
    }.otherwise {
      core_pc := core_pc + wbu.io.out.bits.pc + m_gprs.io.read1.data + core_dnpc + m_csrs.io.read.data
    }
    pc := core_pc
  }
}
