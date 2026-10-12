package pipeline_manual

import chisel3._
import chisel3.util._

/** WBU（WB 级）：写回 + CSR 提交 + 陷阱/中断/MRET 处理。
  *   - 异常：指令自带的异常（illegal/ecall/ebreak/非对齐）在提交时进 mtvec
  *   - 中断：io.interrupt 且 mstatus.MIE=1，在指令边界接收（mepc=当前提交 PC）
  *   - MRET：跳回 mepc，恢复 mstatus.MIE
  */
class Wbu(p: CoreParams) extends Module {
  val io    = IO(new Bundle {
    val interrupt = Input(Bool())           // TODO 暂时忽略中断的影响
    val in        = Flipped(Decoupled(new LsBundle(p)))
    val out       = Decoupled(new WbBundle(p))
    val csrWrite  = new RegWriteIO(p.CSR_ADDR_W, p.XLEN)
    val csrTrap   = new TrapIO(p)
    val redirect  = Output(new Redirect(p)) // 陷阱/MRET（→ IFU）
    val gprWrite  = new RegWriteIO(p.GPR_ADDR_W, p.XLEN)
  })
  // TODO 临时不写逻辑
  io.in.ready := false.B
  val wbReg = Reg(new WbBundle(p))
  wbReg.pc           := io.in.bits.pc
  io.out.valid       := false.B
  io.out.bits        := wbReg
  io.csrWrite.en     := false.B
  io.csrWrite.addr   := 0.U
  io.csrWrite.data   := 0.U
  io.csrTrap.en      := false.B
  io.csrTrap.epc     := 0.U
  io.csrTrap.cause   := 0.U
  io.csrTrap.tval    := 0.U
  io.redirect.valid  := false.B
  io.redirect.target := 0.U
  // TODO 增加调试信息
  // io.gprWrite.en := false.B
  // io.gprWrite.addr := 0.U
  // io.gprWrite.data := 0.U

  val testGprEn   = RegInit(false.B)
  val testGprAddr = RegInit(0.U(p.GPR_ADDR_W.W))
  val testGprData = RegInit(0.U(p.XLEN.W))
  testGprEn        := !testGprEn
  testGprAddr      := testGprAddr + 1.U
  testGprData      := testGprData + testGprAddr
  io.gprWrite.en   := testGprEn
  io.gprWrite.addr := testGprAddr
  io.gprWrite.data := testGprData
}
