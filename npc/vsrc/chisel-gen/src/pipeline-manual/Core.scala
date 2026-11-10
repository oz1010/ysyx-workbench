package pipeline_manual

import chisel3._
import chisel3.util._
import scala.language.reflectiveCalls
import config.AutoConfig._
import config.ManuConfig._

/** RV32E 五级流水线核（内部顶层，Chisel 隐式 clock/reset）。 IFU --(IF/ID)--> IDU --(ID/EX)-->
  * EXU --(EX/MEM)--> LSU --(MEM/WB)--> WBU 每级间均为 valid/ready 握手（Decoupled）；
  * ICache/DCache 经仲裁器共用 AXI4 读通道，store 由 DCache 写直通 AXI4 写通道。
  * 框架：模块例化与信号连接已完成，各模块内部实现留空。
  */
class riscv32e_core() extends RawModule {
  val clock        = IO(Input(Clock()))
  val reset        = IO(Input(Bool())) // 同步复位，高有效
  val reset_pc     = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val io_interrupt = IO(Input(Bool()))
  val io_if        = IO(new CacheIO())
  val io_if_flush  = IO(Output(Bool()))
  val io_mem       = IO(new CacheIO())
  val gpr          = IO(new RegWriteIO(GPR_ADDR_W, CONFIG_DATA_WIDTH))
  val gpr_a0       = IO(Output(UInt(CONFIG_DATA_WIDTH.W)))
  val gpr_a1       = IO(Output(UInt(CONFIG_DATA_WIDTH.W)))
  val gpr_a2       = IO(Output(UInt(CONFIG_DATA_WIDTH.W)))
  val csr          = IO(new RegWriteIO(CSR_ADDR_W, CONFIG_DATA_WIDTH))
  val trap         = IO(new TrapIO())
  val pc           = IO(Output(UInt(CONFIG_ADDR_WIDTH.W)))
  val inst_pc      = IO(Output(UInt(CONFIG_ADDR_WIDTH.W)))
  val inst_done    = IO(Output(Bool()))

  withClockAndReset(clock, reset) {
    // ---------------- 实例化模块 ----------------
    val ifu        = Module(new Ifu())
    val idu        = Module(new Idu())
    val exu        = Module(new Exu())
    val lsu        = Module(new Lsu())
    val wbu        = Module(new Wbu())
    val m_gprs     = Module(new GprFile())
    val m_csrs     = Module(new CsrFile())
    val regIfId    = Module(new PipelineReg(new IfBundle()))
    val regIdEx    = Module(new PipelineReg(new IdBundle()))
    val regExLs    = Module(new PipelineReg(new ExBundle()))
    val regLsWb    = Module(new PipelineReg(new LsBundle()))
    val hazardUnit = Module(new HazardUnit())

    // ---------------- 全局控制信号收集 ----------------
    val exRedirect  = exu.io.redirect
    val wbRedirect  = wbu.io.redirect
    val globalFlush = exRedirect.valid || wbRedirect.valid
    val loadStall   = hazardUnit.io.stallEx
    // load 留在 MEM 等待响应，相关指令保持在 EX，不能 flush 丢弃
    hazardUnit.io.exRs1    := regIdEx.io.out.bits.rs1Addr
    hazardUnit.io.exRs2    := regIdEx.io.out.bits.rs2Addr
    hazardUnit.io.exValid  := regIdEx.io.out.valid
    hazardUnit.io.lsRd     := regExLs.io.out.bits.rdAddr
    hazardUnit.io.lsIsLoad := regExLs.io.out.bits.ctrl.isLoad && regExLs.io.out.bits.ctrl.isRdWen
    hazardUnit.io.lsValid  := regExLs.io.out.valid && !regExLs.io.out.bits.expt.en

    // ---------------- IFU ----------------
    ifu.io.reset_pc   := reset_pc
    ifu.io.cache <> io_if
    ifu.io.exRedirect := exRedirect
    ifu.io.wbRedirect := wbRedirect
    // IFU->IDU
    regIfId.io.in <> ifu.io.out
    regIfId.io.flush <> globalFlush
    regIfId.io.stall  := false.B
    regIfId.io.out <> idu.io.in

    // ---------------- IDU ----------------
    idu.io.exRedirect := exRedirect
    idu.io.wbRedirect := wbRedirect
    idu.io.gprWrite   := wbu.io.gprWrite
    idu.io.gprRead1 <> m_gprs.io.read1
    idu.io.gprRead2 <> m_gprs.io.read2
    // IDU->EXU
    regIdEx.io.in <> idu.io.out
    regIdEx.io.flush  := globalFlush
    regIdEx.io.stall  := false.B
    regIdEx.io.out <> exu.io.in

    // ---------------- EXU ----------------
    // 前递只跨真实级间边界：MEM 优先于 WB，不能连接 EXU 自己的输出
    exu.io.lsValid := regExLs.io.out.valid
    exu.io.lsStage := regExLs.io.out.bits
    exu.io.wbValid := wbu.io.gprWrite.wen
    exu.io.wbStage := regLsWb.io.out.bits
    exu.io.wbData  := wbu.io.gprWrite.wdata
    // CSR 在 EX 读旧值前等待更老指令提交，避免 CSR RAW 和 trap 状态错拍。
    val csrStall = regIdEx.io.out.bits.ctrl.isCsrOp &&
      (regExLs.io.out.valid || regLsWb.io.out.valid)
    exu.io.loadStall := loadStall || csrStall
    // csr寄存器组
    exu.io.csrRead <> m_csrs.io.read
    // EXU->LSU
    regExLs.io.in <> exu.io.out
    // EX 修正时保留跳转指令自身和更老指令；只有 WB 陷阱/MRET/FENCE.I 冲刷后端。
    regExLs.io.flush := wbRedirect.valid
    regExLs.io.stall := false.B
    regExLs.io.out <> lsu.io.in

    // ---------------- LSU ----------------
    lsu.io.cache <> io_mem
    lsu.io.kill      := wbRedirect.valid || wbu.io.blockMem // 重定向接受当拍即阻止年轻访存
    // LSU->WBU
    regLsWb.io.in <> lsu.io.out
    regLsWb.io.flush := wbRedirect.valid
    regLsWb.io.stall := false.B
    regLsWb.io.out <> wbu.io.in

    // ---------------- WBU ----------------
    wbu.io.interrupt := io_interrupt
    wbu.io.gprA0 <> m_gprs.io.a0
    gpr_a0           := m_gprs.io.a0
    gpr_a1           := m_gprs.io.a1
    gpr_a2           := m_gprs.io.a2
    wbu.io.gprWrite <> m_gprs.io.write
    wbu.io.csrWrite <> m_csrs.io.write
    wbu.io.csrTrap <> m_csrs.io.trap
    wbu.io.csrStatus := m_csrs.io.status
    // 对外接口镜像内部同拍提交事件，不另行寄存或产生写使能。
    gpr              := wbu.io.gprWrite
    csr              := wbu.io.csrWrite
    trap             := wbu.io.csrTrap
    io_if_flush      := wbu.io.fenceI
    wbu.io.out.ready := true.B
    wbu.io.csrMepc   := m_csrs.io.mepc
    wbu.io.csrMtvec  := m_csrs.io.mtvec

    // ---------------- 性能监控 ----------------
    val perfMonitor = Module(new PerfMonitor())
    perfMonitor.io.ifReq := io_if.req
    perfMonitor.io.ifOut := ifu.io.out
    perfMonitor.io.idOut := idu.io.out
    perfMonitor.io.exOut := exu.io.out
    perfMonitor.io.lsOut := lsu.io.out
    perfMonitor.io.wbOut := wbu.io.out
    perfMonitor.io.gprWrite <> wbu.io.gprWrite
    perfMonitor.io.csrWrite <> wbu.io.csrWrite
    perfMonitor.io.exRedirect <> exRedirect
    perfMonitor.io.wbRedirect <> wbRedirect

    // ---------------- 关键输出 ----------------
    pc        := wbu.io.out.bits.dnpc // 下一条待执行指令的架构 PC，空闲时保持
    inst_pc   := wbu.io.out.bits.pc   // 最近完成指令的 PC
    inst_done := wbu.io.out.fire
  }
}
