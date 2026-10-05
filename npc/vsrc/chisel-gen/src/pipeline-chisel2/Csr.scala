package pipeline_chisel2

import chisel3._
import chisel3.util._

/**
 * CSR 文件：只实现 M 模式最常见的 6 个寄存器
 *   mstatus / mtvec / mepc / mcause / mvendorid / marchid
 * 仅实现 M 模式最常用的位：mstatus.MIE(bit3)、mstatus.MPIE(bit7)。
 */
class CsrFile(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    // 读口（EX 级组合读，返回旧值）
    val raddr  = Input(UInt(12.W))
    val rdata  = Output(UInt(p.XLEN.W))
    // 写口（WBU 提交时写）
    val wen    = Input(Bool())
    val waddr  = Input(UInt(12.W))
    val wdata  = Input(UInt(p.XLEN.W))
    // 陷阱进入
    val trap   = Input(new TrapReq(p))
    // MRET 返回
    val mret   = Input(Bool())
    // 状态输出
    val mie    = Output(Bool())       // mstatus.MIE
    val mtvec  = Output(UInt(p.XLEN.W))
    val mepc   = Output(UInt(p.XLEN.W))
  })

  val mstatusMie  = RegInit(false.B)
  val mstatusMpie = RegInit(true.B)
  val mtvec       = RegInit(0.U(p.XLEN.W))
  val mepc        = RegInit(0.U(p.XLEN.W))
  val mcause      = RegInit(0.U(p.XLEN.W))

  io.mie   := mstatusMie
  io.mtvec := Cat(mtvec(p.XLEN - 1, 2), 0.U(2.W)) // direct 模式
  io.mepc  := mepc

  // 读：未实现的地址返回 0；mvendorid/marchid 只读
  io.rdata := MuxLookup(io.raddr, 0.U)(Seq(
    p.CSR_MSTATUS.U   -> Cat(0.U(24.W), mstatusMpie, 0.U(3.W), mstatusMie, 0.U(3.W)), // mstatus
    p.CSR_MTVEC.U     -> mtvec,                                                      // mtvec
    p.CSR_MEPC.U      -> mepc,                                                       // mepc
    p.CSR_MCAUSE.U    -> mcause,                                                     // mcause
    p.CSR_MVENDORID.U -> p.MVENDORID.U(p.XLEN.W),                                    // mvendorid
    p.CSR_MARCHID.U   -> p.MARCHID.U(p.XLEN.W)                                       // marchid
  ))

  // 写（仅 WBU 提交的有效写；只读地址忽略）
  when(io.wen) {
    switch(io.waddr) {
      is(p.CSR_MSTATUS.U) { mstatusMie := io.wdata(3); mstatusMpie := io.wdata(7) }
      is(p.CSR_MTVEC.U)   { mtvec := io.wdata }
      is(p.CSR_MEPC.U)    { mepc := io.wdata }
      is(p.CSR_MCAUSE.U)  { mcause := io.wdata }
    }
  }

  // MRET：先恢复（若同周期又进陷阱，陷阱优先覆盖）
  when(io.mret) {
    mstatusMie  := mstatusMpie
    mstatusMpie := true.B
  }
  // 陷阱进入
  when(io.trap.valid) {
    mstatusMpie := mstatusMie
    mstatusMie  := false.B
    mepc        := io.trap.epc
    mcause      := io.trap.cause
  }
}
