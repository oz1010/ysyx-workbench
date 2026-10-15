package pipeline_manual

import chisel3._
import chisel3.util._

/** RV32E 五级流水线核（内部顶层，Chisel 隐式 clock/reset）。 IFU --(IF/ID)--> IDU --(ID/EX)-->
  * EXU --(EX/MEM)--> LSU --(MEM/WB)--> WBU 每级间均为 valid/ready 握手（Decoupled）；
  * ICache/DCache 经仲裁器共用 AXI4 读通道，store 由 DCache 写直通 AXI4 写通道。
  * 框架：模块例化与信号连接已完成，各模块内部实现留空。
  */
class riscv32e_core(p: CoreParams) extends RawModule {
  val clk          = IO(Input(Clock()))
  val rst          = IO(Input(Bool()))  // 同步复位，高有效
  val io_interrupt = IO(Input(Bool()))
  val io_master    = IO(new Axi4IO(p))
  val pc           = IO(Output(UInt(p.ADDR_WIDTH.W)))
  val valid        = IO(Output(Bool())) // 完成一条指令（单周期脉冲）

  withClockAndReset(clk, rst) {
    // ---------------- 实例化模块 ----------------
    val ifu        = Module(new Ifu(p))
    val idu        = Module(new Idu(p))
    val exu        = Module(new Exu(p))
    val lsu        = Module(new Lsu(p))
    val wbu        = Module(new Wbu(p))
    val icache     = Module(new ICache(p))
    val dcache     = Module(new DCache(p))
    val arbiter    = Module(new Axi4IOArbiter(p, 2))
    val m_gprs     = Module(new GprFile(p))
    val m_csrs     = Module(new CsrFile(p))
    val regIfId    = Module(new PipelineReg(new IfBundle(p)))
    val regIdEx    = Module(new PipelineReg(new IdBundle(p)))
    val regExLs    = Module(new PipelineReg(new ExBundle(p)))
    val regLsWb    = Module(new PipelineReg(new LsBundle(p)))
    val hazardUnit = Module(new HazardUnit(p))

    // ---------------- 全局控制信号收集 ----------------
    val exRedirect  = exu.io.redirect
    val wbRedirect  = wbu.io.redirect
    val globalFlush = exRedirect.valid || wbRedirect.valid
    val loadStall   = hazardUnit.io.stallIfId
    // 将控制信号连接至 Hazard 单元
    hazardUnit.io.idRs1      := regIdEx.io.out.bits.rs1Addr
    hazardUnit.io.idRs2      := regIdEx.io.out.bits.rs2Addr
    hazardUnit.io.idValid    := regIdEx.io.out.valid
    hazardUnit.io.exRd       := regExLs.io.out.bits.rdAddr
    hazardUnit.io.exIsLoad   := regExLs.io.out.bits.ctrl.load
    hazardUnit.io.exValid    := regExLs.io.out.valid
    hazardUnit.io.exRedirect := exRedirect.valid
    hazardUnit.io.wbRedirect := wbRedirect.valid

    // ---------------- IFU ----------------
    ifu.io.cache <> icache.io.cpu
    ifu.io.exRedirect := exRedirect
    ifu.io.wbRedirect := wbRedirect
    // IFU->IDU
    regIfId.io.in <> ifu.io.out
    regIfId.io.flush <> globalFlush
    regIfId.io.stall <> loadStall
    regIfId.io.out <> idu.io.in

    // ---------------- IDU ----------------
    idu.io.loadStall  := loadStall
    idu.io.exRedirect := exRedirect
    idu.io.wbRedirect := wbRedirect
    idu.io.gprWrite   := wbu.io.gprWrite
    idu.io.gprRead1 <> m_gprs.io.read1
    idu.io.gprRead2 <> m_gprs.io.read2
    // IDU->EXU
    regIdEx.io.in <> idu.io.out
    regIdEx.io.flush  := globalFlush || loadStall // Load-Use 时向 EX 级注入气泡
    regIdEx.io.stall  := false.B
    regIdEx.io.out <> exu.io.in

    // ---------------- EXU ----------------
    // EXU的前递(Forwarding)数据源
    exu.io.lsValid   := regExLs.io.in.valid
    exu.io.lsStage   := regExLs.io.in.bits
    exu.io.wbValid   := regLsWb.io.in.valid
    exu.io.wbStage   := regLsWb.io.in.bits
    exu.io.wbData    := wbu.io.gprWrite.data
    // csr寄存器组
    exu.io.csrRead <> m_csrs.io.read
    // EXU->LSU
    regExLs.io.in <> exu.io.out
    regExLs.io.flush := globalFlush
    regExLs.io.stall := false.B
    regExLs.io.out <> lsu.io.in

    // ---------------- LSU ----------------
    lsu.io.cache <> dcache.io.cpu
    lsu.io.kill      := wbRedirect.valid // 异常时终止访存
    // LSU->WBU
    regLsWb.io.in <> lsu.io.out
    regLsWb.io.flush := globalFlush
    regLsWb.io.stall := false.B
    regLsWb.io.out <> wbu.io.in

    // ---------------- WBU ----------------
    wbu.io.interrupt := io_interrupt
    wbu.io.gprWrite <> m_gprs.io.write
    wbu.io.csrWrite <> m_csrs.io.write
    wbu.io.csrTrap <> m_csrs.io.trap
    wbu.io.out.ready := true.B
    wbu.io.csrMie    := false.B
    wbu.io.csrMepc   := m_csrs.io.mepc
    wbu.io.csrMtvec  := m_csrs.io.mtvec

    // ---------------- AXI4仲裁器 ----------------
    arbiter.io.master <> io_master
    arbiter.io.clients(0) <> icache.io.master
    arbiter.io.clients(1) <> dcache.io.master

    // ---------------- 关键输出 ----------------
    val core_pc   = RegInit(0.U(p.ADDR_WIDTH.W))
    val core_dnpc = RegInit(0.U(p.ADDR_WIDTH.W))
    core_pc := wbu.io.out.bits.pc
    pc      := core_pc
    valid   := wbu.io.out.valid
    when(wbu.io.out.valid) {
      core_pc := wbu.io.out.bits.pc
    }
    when(lsu.io.out.valid) {
      core_dnpc := lsu.io.out.bits.pc
    }
  }
}
