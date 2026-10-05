package pipeline_chisel2

import chisel3._
import chisel3.util._

/**
 * RV32E 五级流水线核（内部顶层，Chisel 隐式 clock/reset）。
 *   IFU --(IF/ID)--> IDU --(ID/EX)--> EXU --(EX/MEM)--> LSU --(MEM/WB)--> WBU
 * 每级间均为 valid/ready 握手（Decoupled）；
 * ICache/DCache 经仲裁器共用 AXI4 读通道，store 由 DCache 写直通 AXI4 写通道。
 * 框架：模块例化与信号连接已完成，各模块内部实现留空。
 */
class Rv32eCore(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val interrupt = Input(Bool())   // io_interrupt
    val master    = new Axi4MasterIO(p) // io_master（AXI4 主设备）
    val pc        = Output(UInt(p.ADDR_WIDTH.W)) // 当前取指 PC（关键输出）
    val valid     = Output(Bool())  // 完成一条指令（单周期脉冲）
  })

  // ---------------- 子模块 ----------------
  val ifu     = Module(new Ifu(p))
  val idu     = Module(new Idu(p))
  val exu     = Module(new Exu(p))
  val lsu     = Module(new Lsu(p))
  val wbu     = Module(new Wbu(p))
  val icache  = Module(new ICache(p))
  val dcache  = Module(new DCache(p))
  val arbiter = Module(new BusArbiter(p))
  val csr     = Module(new CsrFile(p))

  // ---------------- 流水线级间握手 ----------------
  ifu.io.out <> idu.io.in   // IF/ID
  idu.io.out <> exu.io.in   // ID/EX
  exu.io.out <> lsu.io.in   // EX/MEM
  lsu.io.out <> wbu.io.in   // MEM/WB

  // ---------------- 重定向（WBU 陷阱/MRET > EX 预测修正） ----------------
  ifu.io.exRedirect := exu.io.redirect
  ifu.io.wbRedirect := wbu.io.redirect
  lsu.io.kill       := wbu.io.redirect.valid

  // ---------------- 写回（WBU → IDU 寄存器堆） ----------------
  idu.io.rfWen  := wbu.io.rfWen
  idu.io.rfRd   := wbu.io.rfRd
  idu.io.rfData := wbu.io.rfData

  // ---------------- CSR ----------------
  csr.io.raddr := exu.io.csrRaddr
  exu.io.csrRdata := csr.io.rdata
  csr.io.wen   := wbu.io.csrWen
  csr.io.waddr := wbu.io.csrWaddr
  csr.io.wdata := wbu.io.csrWdata
  csr.io.trap  := wbu.io.csrTrap
  csr.io.mret  := wbu.io.csrMret

  // ---------------- ICache ----------------
  icache.io.cpu    <> ifu.io.cache
  icache.io.refill <> arbiter.io.icache

  // ---------------- DCache ----------------
  dcache.io.cpu    <> lsu.io.cache
  dcache.io.refill <> arbiter.io.dcache

  // ---------------- AXI4 读通道（仲裁器，ID 恒为 0） ----------------
  io.master.araddr        := arbiter.io.master.araddr
  io.master.arid          := 0.U
  io.master.arlen         := arbiter.io.master.arlen
  io.master.arsize        := arbiter.io.master.arsize
  io.master.arburst       := arbiter.io.master.arburst
  io.master.arvalid       := arbiter.io.master.arvalid
  arbiter.io.master.arready := io.master.arready
  arbiter.io.master.rdata   := io.master.rdata
  arbiter.io.master.rresp   := io.master.rresp
  arbiter.io.master.rlast   := io.master.rlast
  arbiter.io.master.rid     := io.master.rid
  arbiter.io.master.rvalid  := io.master.rvalid
  io.master.rready        := arbiter.io.master.rready

  // ---------------- AXI4 写通道（DCache 写直通，ID 恒为 0） ----------------
  io.master.awaddr        := dcache.io.write.awaddr
  io.master.awid          := 0.U
  io.master.awlen         := dcache.io.write.awlen
  io.master.awsize        := dcache.io.write.awsize
  io.master.awburst       := dcache.io.write.awburst
  io.master.awvalid       := dcache.io.write.awvalid
  dcache.io.write.awready := io.master.awready
  io.master.wdata         := dcache.io.write.wdata
  io.master.wstrb         := dcache.io.write.wstrb
  io.master.wlast         := dcache.io.write.wlast
  io.master.wvalid        := dcache.io.write.wvalid
  dcache.io.write.wready  := io.master.wready
  dcache.io.write.bresp   := io.master.bresp
  dcache.io.write.bvalid  := io.master.bvalid
  dcache.io.write.bid     := io.master.bid
  io.master.bready        := dcache.io.write.bready

  // ---------------- WBU 中断 ----------------
  wbu.io.interrupt := io.interrupt

  // ---------------- 关键输出 ----------------
  io.pc    := ifu.io.pc
  io.valid := wbu.io.valid
}

/**
 * 对外顶层（drop-in 替代 npc 手写 riscv32e_core）：
 *   - RawModule，显式 clk / rst（同步高有效复位）端口；
 *   - 端口名与 npc 例化完全一致（io_interrupt / io_master_* / pc / valid）。
 */
class riscv32e_core(p: CoreParams) extends RawModule {
  val clk          = IO(Input(Clock()))
  val rst          = IO(Input(Bool())) // 同步复位，高有效
  val io_interrupt = IO(Input(Bool()))
  val io_master    = IO(new Axi4MasterIO(p))
  val pc           = IO(Output(UInt(p.ADDR_WIDTH.W)))
  val valid        = IO(Output(Bool())) // 完成一条指令（单周期脉冲）

  val core = withClockAndReset(clk, rst) { Module(new Rv32eCore(p)) }
  core.io.interrupt := io_interrupt
  io_master         <> core.io.master
  pc                := core.io.pc
  valid             := core.io.valid
}
