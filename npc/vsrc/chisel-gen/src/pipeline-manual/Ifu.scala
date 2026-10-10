package pipeline_manual

import chisel3._
import chisel3.util._

/** IFU：取指 + 静态分支预测 + IF/ID 寄存器。 静态预测策略：
  *   - 条件分支（B-type）：向后跳（imm 为负）预测 taken，向前跳预测 not-taken
  *   - JAL：恒预测 taken（目标由立即数算出）
  *   - JALR：无法静态得知目标，预测 not-taken（在 EX 级修正）
  */

class Ifu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val cache = new CacheIO(p)
    val out = Decoupled(new IfBundle(p))
    val exRedirect = Input(new Redirect(p)) // 预测失败/跳转修正（EX 级）
    val wbRedirect = Input(new Redirect(p)) // 陷阱/MRET（WBU 级，优先级最高）
  })

  val resetPcGetter = Module(new ResetPcGetter(p.ADDR_WIDTH))

  val pc = RegInit(
    resetPcGetter.io.reset_pc
  ) // 改为调用verilog的function func_get_reset_pc获取
  val reqPend = RegInit(false.B) // 已发出请求、等待 ICache 返回
  val reqPc = Reg(UInt(p.ADDR_WIDTH.W))
  val fValid = RegInit(false.B)
  val fBits = Reg(new IfBundle(p))

  // ---------------- 请求 ICache ----------------
  // 取回缓冲（fValid）非空时不发新请求：防止下游停顿期间响应覆盖
  // 尚未消费的指令（丢指令）。sResp 仅脉冲一拍且无条件回 sIdle，丢弃安全。
  io.cache.req.valid := !reqPend && !fValid
  io.cache.req.addr := pc
  io.cache.req.wdata := 0.U
  io.cache.req.wstrb := 0.U
  io.cache.req.isWrite := false.B
  when(io.cache.req.valid && io.cache.req.ready) {
    reqPend := true.B
    reqPc := pc
  }

  // ---------------- 接收指令并做静态预测 ----------------
  val inst = io.cache.resp.data
  val opcode = inst(6, 0)
  val isBr = opcode === "b1100011".U
  val isJal = opcode === "b1101111".U

  val bImm =
    Cat(inst(31), inst(7), inst(30, 25), inst(11, 8), 0.U(1.W)) // 13bit
  val jImm =
    Cat(inst(31), inst(19, 12), inst(20), inst(30, 21), 0.U(1.W)) // 21bit
  val bOff = Cat(Fill(19, bImm(12)), bImm) // 扩展为32位符号数
  val jOff = Cat(Fill(11, jImm(20)), jImm) // 扩展为32位符号数
  // 预测：向后分支/JAL taken；预测目标
  val predT = (isBr && bImm(12) === 1.U) || isJal
  val predTgt = Mux(isJal, reqPc + jOff, reqPc + bOff)
  when(io.cache.resp.valid && reqPend) {
    reqPend := false.B
    fValid := true.B
    fBits.pc := reqPc
    fBits.inst := inst
    fBits.predTaken := predT
    fBits.predTarget := predTgt
    pc := Mux(predT, predTgt, reqPc + 4.U) // 顺序或预测路径继续取指
  }

  // ---------------- ifu数据输出 ----------------
  val ifValid = RegInit(false.B)
  val ifBits = Reg(new IfBundle(p))
  val move = fValid && (!ifValid || io.out.ready)
  when(io.out.ready) { ifValid := false.B }
  when(move) {
    ifBits := fBits
    ifValid := true.B
    fValid := false.B
  }

  // ---------------- 冲刷（WBU 陷阱 > EX 修正） ----------------
  when(io.wbRedirect.valid) {
    ifValid := false.B
    fValid := false.B
    reqPend := false.B
    pc := io.wbRedirect.target
  }.elsewhen(io.exRedirect.valid) {
    ifValid := false.B
    fValid := false.B
    reqPend := false.B
    pc := io.exRedirect.target
  }

  io.out.valid := ifValid
  io.out.bits := ifBits
}
