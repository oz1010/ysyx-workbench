package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._

/** WBU（WB 级）：写回 + CSR 提交 + 陷阱/中断/MRET 处理。
  *   - 异常：指令自带的异常（illegal/ecall/ebreak/非对齐）在提交时进 mtvec
  *   - 中断：io.interrupt 且 mstatus.MIE=1，在指令边界接收（mepc=当前提交 PC）
  *   - MRET：跳回 mepc，恢复 mstatus.MIE
  */
class Wbu() extends Module {
  val io = IO(new Bundle {
    val in        = Flipped(Decoupled(new LsBundle()))
    val out       = Decoupled(new WbBundle())
    val csrWrite  = new RegWriteIO(CSR_ADDR_W, CONFIG_ADDR_WIDTH)
    val csrTrap   = new TrapIO()
    val redirect  = Output(new Redirect()) // 陷阱/MRET（→ IFU）
    val gprWrite  = new RegWriteIO(GPR_ADDR_W, CONFIG_ADDR_WIDTH)
    val interrupt = Input(Bool())          // TODO 暂时忽略中断的影响
    // TODO 暂时忽略csr值输入
    val csrMie    = Input(Bool())
    val csrMepc   = Input(UInt(CONFIG_ADDR_WIDTH.W))
    val csrMtvec  = Input(UInt(CONFIG_ADDR_WIDTH.W))
  })

  val in = io.in.bits
  val v  = io.in.valid

  // ---------------- 写回数据选择 ----------------
  val wbData = MuxLookup(in.ctrl.wbOp, in.aluResult)(
    Seq(
      WbOp.ALU  -> in.aluResult,
      WbOp.LOAD -> in.loadData,
      WbOp.CSR  -> in.csrRdata,
      WbOp.PC_4 -> (in.pc + 4.U)
    )
  )

  // ---------------- 陷阱仲裁 ----------------
  val exptEn  = v && in.expt.en
  val intTake = v && io.interrupt && io.csrMie && !exptEn
  val trap    = exptEn || intTake
  val cause   = Mux(exptEn, in.expt.cause, INT_CAUSE.U(CONFIG_ADDR_WIDTH.W))
  val mret    = v && in.ctrl.isMret && !trap
  val trapEn  = RegInit(false.B)
  trapEn             := Mux((trap || mret), true.B, false.B)
  io.redirect.valid  := trapEn
  io.redirect.target := Mux(trap, io.csrMtvec, io.csrMepc)

  // CSR 更新（同周期冲突时：MRET < 陷阱 < CSR 写，WBU 单点仲裁）
  io.csrTrap.en     := trap
  io.csrTrap.cause  := cause
  io.csrTrap.epc    := in.pc
  io.csrTrap.tval   := 0.U // TODO 具体值应和cause相关
  io.csrTrap.status := 0.U // 暂时不需要修改状态值
  io.csrWrite.wen   := v && !trap && in.ctrl.isCsrOp
  io.csrWrite.waddr := in.csrAddr
  io.csrWrite.wdata := MuxLookup(in.ctrl.csrOp, in.csrWdata)(
    Seq(
      CsrOp.RW -> in.csrWdata,                 // RW: 直接写
      CsrOp.RS -> (in.csrRdata | in.csrWdata), // RS: 置位
      CsrOp.RC -> (in.csrRdata & ~in.csrWdata) // RC：清位
    )
  )

  // ---------------- 寄存器堆写口 ----------------
  io.gprWrite.wen   := v && !trap && in.ctrl.isRdWen && in.rdAddr =/= 0.U
  io.gprWrite.waddr := in.rdAddr
  io.gprWrite.wdata := wbData

  // 流水线处理
  io.in.ready      := true.B
  io.out.valid     := v
  io.out.bits.pc   := io.in.bits.pc
  // TODO 先透传dnpc
  // io.out.bits.dnpc := Mux(
  //   trap,
  //   io.csrMtvec,
  //   Mux(mret, io.csrMepc, io.in.bits.dnpc)
  // )
  io.out.bits.dnpc := io.in.bits.dnpc
}
