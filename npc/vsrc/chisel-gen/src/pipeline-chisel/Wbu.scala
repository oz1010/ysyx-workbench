package rv32e

import chisel3._
import chisel3.util._

/**
 * WBU（WB 级）：写回 + CSR 提交 + 陷阱/中断/MRET 处理。
 *  - 异常：指令自带的异常（illegal/ecall/ebreak/非对齐）在提交时进 mtvec
 *  - 中断：io.interrupt 且 mstatus.MIE=1，在指令边界接收（mepc=当前提交 PC）
 *  - MRET：跳回 mepc，恢复 mstatus.MIE
 */
class Wbu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val memwb      = Input(new MemWbBundle(p))
    val memwbValid = Input(Bool())
    val interrupt  = Input(Bool())
    val redirect   = Output(new Redirect(p)) // 陷阱/MRET 重定向（冲刷全部 younger 级）
    // 寄存器堆写口
    val rfWen   = Output(Bool())
    val rfRd    = Output(UInt(4.W))
    val rfData  = Output(UInt(p.XLEN.W))
    // CSR 读口（透传给 EX）
    val csrRaddr = Input(UInt(12.W))
    val csrRdata = Output(UInt(p.XLEN.W))
    // 状态输出
    val mie   = Output(Bool())
    // 指令完成：每条退休指令拉高一个周期（单周期脉冲）
    val valid = Output(Bool())
  })

  val csr = Module(new CsrFile(p))
  csr.io.raddr := io.csrRaddr
  io.csrRdata  := csr.io.rdata
  io.mie       := csr.io.mie

  val in = io.memwb
  val v  = io.memwbValid

  // ---------------- 写回数据选择 ----------------
  val wbData = MuxLookup(in.ctrl.wbSel, in.aluResult)(Seq(
    0.U -> in.aluResult,
    1.U -> in.loadData,
    2.U -> in.csrRdata,
    3.U -> (in.pc + 4.U)
  ))

  // ---------------- 陷阱仲裁 ----------------
  val exc     = v && in.excValid
  val intTake = v && io.interrupt && csr.io.mie && !exc
  val trap    = exc || intTake
  val cause   = Mux(exc, in.excCause, p.INT_CAUSE.U(p.XLEN.W))
  val mret    = v && in.ctrl.mret && !trap

  io.redirect.valid  := trap || mret
  io.redirect.target := Mux(trap, csr.io.mtvec, csr.io.mepc)

  // CSR 更新（同周期冲突时：MRET < 陷阱 < CSR 写，WBU 单点仲裁）
  csr.io.trapValid := trap
  csr.io.trapCause := cause
  csr.io.trapEpc   := in.pc
  csr.io.mret      := mret
  csr.io.wen       := v && !trap && in.ctrl.csrOp =/= 0.U
  csr.io.waddr     := in.csrAddr
  csr.io.wdata := MuxLookup(in.ctrl.csrOp, in.csrWdata)(Seq(
    1.U -> in.csrWdata,                       // RW：直接写
    2.U -> (in.csrRdata | in.csrWdata),       // RS：置位
    3.U -> (in.csrRdata & ~in.csrWdata)       // RC：清位
  ))

  // ---------------- 寄存器堆写口 ----------------
  io.rfWen  := v && !trap && in.ctrl.rdWen && in.rdAddr =/= 0.U
  io.rfRd   := in.rdAddr
  io.rfData := wbData

  // ---------------- 指令完成脉冲 ----------------
  // MEM/WB 中同一条指令会驻留多个周期，仅在 memwbValid 上升沿拉高一拍，
  // 保证每条退休指令（含陷入/中断/MRET）恰好产生一次完成脉冲
  val vPrev = RegNext(v, false.B)
  io.valid := v && !vPrev
}
