package pipeline_manual

import chisel3._
import chisel3.util._

/** WBU（WB 级）：写回 + CSR 提交 + 陷阱/中断/MRET 处理。
  *   - 异常：指令自带的异常（illegal/ecall/ebreak/非对齐）在提交时进 mtvec
  *   - 中断：io.interrupt 且 mstatus.MIE=1，在指令边界接收（mepc=当前提交 PC）
  *   - MRET：跳回 mepc，恢复 mstatus.MIE
  */
class Wbu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val in        = Flipped(Decoupled(new LsBundle(p)))
    val out       = Decoupled(new WbBundle(p))
    val csrWrite  = new RegWriteIO(p.CSR_ADDR_W, p.XLEN)
    val csrTrap   = new TrapIO(p)
    val redirect  = Output(new Redirect(p)) // 陷阱/MRET（→ IFU）
    val gprWrite  = new RegWriteIO(p.GPR_ADDR_W, p.XLEN)
    val interrupt = Input(Bool())           // TODO 暂时忽略中断的影响
    // TODO 暂时忽略csr值输入
    val csrMie    = Input(Bool())
    val csrMepc   = Input(UInt(p.XLEN.W))
    val csrMtvec  = Input(UInt(p.XLEN.W))
  })

  val in = io.in.bits
  val v  = io.in.valid

  // ---------------- 写回数据选择 ----------------
  val wbData = MuxLookup(in.ctrl.wbSel, in.aluResult)(
    Seq(
      WbSel.ALU  -> in.aluResult,
      WbSel.LOAD -> in.loadData,
      WbSel.CSR  -> in.csrRdata,
      WbSel.PC_4 -> (in.pc + 4.U)
    )
  )

  // ---------------- 陷阱仲裁 ----------------
  val exc     = v && in.excValid
  val intTake = v && io.interrupt && io.csrMie && !exc
  val trap    = exc || intTake
  val cause   = Mux(exc, in.excCause, p.INT_CAUSE.U(p.XLEN.W))
  val mret    = v && in.ctrl.mret && !trap

  io.redirect.valid  := trap || mret
  io.redirect.target := Mux(trap, io.csrMtvec, io.csrMepc)

  // CSR 更新（同周期冲突时：MRET < 陷阱 < CSR 写，WBU 单点仲裁）
  io.csrTrap.en    := trap
  io.csrTrap.cause := cause
  io.csrTrap.epc   := in.pc
  io.csrTrap.tval  := 0.U // TODO 具体值应和cause相关
  // TODO 更新csr mret寄存器的值
  io.csrWrite.en   := v && !trap && in.ctrl.csrOp =/= CsrOp.NONE
  io.csrWrite.addr := in.csrAddr
  io.csrWrite.data := MuxLookup(in.ctrl.csrOp, in.csrWdata)(
    Seq(
      CsrOp.RW -> in.csrWdata,                 // RW: 直接写
      CsrOp.RS -> (in.csrRdata | in.csrWdata), // RS: 置位
      CsrOp.RC -> (in.csrRdata & ~in.csrWdata) // RC：清位
    )
  )

  // ---------------- 寄存器堆写口 ----------------
  io.gprWrite.en   := v && !trap && in.ctrl.rdWen && in.rdAddr =/= 0.U
  io.gprWrite.addr := in.rdAddr
  io.gprWrite.data := wbData

  // ---------------- 指令完成脉冲 ----------------
  // LS/WB 中同一条指令会驻留多个周期，仅在 lsValid 上升沿拉高一拍，
  // 保证每条退休指令（含陷入/中断/MRET）恰好产生一次完成脉冲
  io.in.ready := true.B
  val wbReg = Reg(new WbBundle(p))
  wbReg.pc := io.in.bits.pc
  val vPrev = RegNext(v, false.B)
  io.out.valid := v && !vPrev
  io.out.bits  := wbReg
}
