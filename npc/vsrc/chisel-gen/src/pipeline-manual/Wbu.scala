package pipeline_manual

import chisel3._
import chisel3.util._
import scala.language.reflectiveCalls
import config.AutoConfig._
import config.ManuConfig._

/** WBU：同步异常不退休；中断在当前指令完成后接收，mepc 保存下一 PC。
  * io.interrupt 是平台已限定的机器外部中断电平，由 mstatus.MIE 全局屏蔽。
  */
class Wbu() extends Module {
  val io = IO(new Bundle {
    val in        = Flipped(Decoupled(new LsBundle()))
    val out       = Decoupled(new WbBundle())
    val csrWrite  = new RegWriteIO(CSR_ADDR_W, CONFIG_ADDR_WIDTH)
    val csrTrap   = new TrapIO()
    val redirect  = Output(new Redirect())
    val blockMem  = Output(Bool()) // 接受陷阱/MRET 当拍即禁止年轻访存
    val gprWrite  = new RegWriteIO(GPR_ADDR_W, CONFIG_ADDR_WIDTH)
    val interrupt = Input(Bool())
    val csrStatus = Input(UInt(CONFIG_ADDR_WIDTH.W))
    val csrMepc   = Input(UInt(CONFIG_ADDR_WIDTH.W))
    val csrMtvec  = Input(UInt(CONFIG_ADDR_WIDTH.W))
  })

  val in = io.in.bits
  val v = io.in.valid && !reset.asBool
  val commit = v && io.out.ready

  val wbData = MuxLookup(in.ctrl.wbOp, in.aluResult)(
    Seq(
      WbOp.ALU  -> in.aluResult,
      WbOp.LOAD -> in.loadData,
      WbOp.CSR  -> in.csrRdata,
      WbOp.PC_4 -> (in.pc + 4.U)
    )
  )
  val csrData = MuxLookup(in.ctrl.csrOp, in.csrWdata)(
    Seq(
      CsrOp.RW -> in.csrWdata,
      CsrOp.RS -> (in.csrRdata | in.csrWdata),
      CsrOp.RC -> (in.csrRdata & ~in.csrWdata)
    )
  )

  val csrWriteData = MuxCase(csrData, Seq(
    (in.csrAddr === CSRAddr.MSTATUS) -> CsrStatus.normalize(csrData),
    (in.csrAddr === CSRAddr.MEPC) -> Cat(csrData(31, 2), 0.U(2.W)),
    (in.csrAddr === CSRAddr.MTVEC) ->
      Cat(csrData(31, 2), 0.U(1.W), csrData(1, 0) === 1.U)
  ))

  // 中断看到本条 CSR 写之后的状态/向量，避免启用、屏蔽及改向量错拍。
  val exptEn = v && in.expt.en
  val csrWen = in.ctrl.isCsrOp && !exptEn
  val status = Mux(csrWen && in.csrAddr === CSRAddr.MSTATUS,
    csrWriteData, io.csrStatus)
  val mtvec = Mux(csrWen && in.csrAddr === CSRAddr.MTVEC, csrWriteData, io.csrMtvec)
  val mret = v && in.ctrl.isMret && !exptEn
  val intTake = v && io.interrupt && status(3) && !exptEn && !mret
  val trap = exptEn || intTake
  val trapBase = Cat(mtvec(31, 2), 0.U(2.W))
  // MODE=1 时仅中断使用向量；不支持的 MODE 按 Direct 处理。
  val trapTarget = trapBase + Mux(intTake && mtvec(1, 0) === 1.U, 44.U, 0.U)
  val returnTarget = Cat(io.csrMepc(31, 2), 0.U(2.W))
  // 提交轨迹和重定向共用最终架构下一 PC，不各自重算陷阱目标。
  val nextPc = Mux(trap, trapTarget, Mux(mret, returnTarget, in.dnpc))
  val redirectFire = commit && (trap || mret)
  val redirect = RegInit(0.U.asTypeOf(new Redirect()))
  redirect.valid := redirectFire
  when(redirectFire) {
    redirect.target := nextPc
  }
  io.redirect := redirect
  io.blockMem := redirectFire

  io.csrTrap.en     := commit && trap
  io.csrTrap.cause  := Mux(exptEn, in.expt.cause, INT_CAUSE.U(CONFIG_ADDR_WIDTH.W))
  io.csrTrap.epc    := Mux(exptEn, in.pc, in.dnpc)
  io.csrTrap.tval   := Mux(exptEn, in.expt.tval, 0.U)
  io.csrTrap.status := CsrStatus.enter(status)

  // 普通写先完成，再进入中断。MRET 复用公开 CSR 写口镜像 mstatus 更新。
  io.csrWrite.wen   := commit && !exptEn && (in.ctrl.isCsrOp || mret)
  io.csrWrite.waddr := Mux(mret, CSRAddr.MSTATUS, in.csrAddr)
  io.csrWrite.wdata := Mux(mret, CsrStatus.leave(io.csrStatus), csrWriteData)
  io.gprWrite.wen   := commit && !exptEn && in.ctrl.isRdWen && in.rdAddr =/= 0.U
  io.gprWrite.waddr := in.rdAddr
  io.gprWrite.wdata := wbData

  io.in.ready      := io.out.ready && !reset.asBool
  io.out.valid     := v
  io.out.bits.pc   := in.pc
  io.out.bits.dnpc := nextPc
}
