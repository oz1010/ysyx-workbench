package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._

/** IFU：取指 + 静态分支预测。
  *
  * 静态预测策略：
  *   - 条件分支（B-type）：向后跳（imm 为负）预测 taken，向前跳预测 not-taken
  *   - JAL：恒预测 taken（目标由立即数算出）
  *   - JALR：无法静态得知目标，预测 not-taken（在 EX 级修正）
  */

class Ifu() extends Module {
  val io = IO(new Bundle {
    val reset_pc   = Input(UInt(CONFIG_ADDR_WIDTH.W))
    val cache      = new CacheIO()
    val out        = Decoupled(new IfBundle())
    val exRedirect = Input(new Redirect()) // 预测失败/跳转修正（EX 级）
    val wbRedirect = Input(new Redirect()) // 陷阱/MRET（WBU 级，优先级最高）
  })

  val ready   = RegInit(false.B) // 模块就绪标识
  val reqPend = RegInit(false.B) // 已发出请求、等待 ICache 返回
  val expt    = Reg(new Expt)
  ExptDefaults(expt);

  // 复位重置pc值
  val pc = Reg(UInt(CONFIG_ADDR_WIDTH.W))
  when(reset.asBool) {
    pc := io.reset_pc
  }
  ready := true.B

  // icache 请求
  io.cache.req.valid := ready && !reqPend // 只要流水线没卡死，持续取指
  io.cache.req.addr  := pc
  io.cache.req.op    := MemOp.FLAG_4B
  io.cache.req.wdata := 0.U
  io.cache.rsp.ready := true.B
  reqPend            := MuxCase(
    reqPend,
    Seq(
      (io.cache.req.valid && io.cache.req.ready) -> true.B,
      (io.out.fire)                              -> false.B
    )
  )

  // 接收指令并做静态预测
  val inst   = io.cache.rsp.data
  val opcode = inst(6, 0)
  val isBr   = opcode === "b1100011".U
  val isJal  = opcode === "b1101111".U
  val bImm   =
    Cat(inst(31), inst(7), inst(30, 25), inst(11, 8), 0.U(1.W)) // 13bit
  val jImm =
    Cat(inst(31), inst(19, 12), inst(20), inst(30, 21), 0.U(1.W)) // 21bit
  val bOff    = Cat(Fill(19, bImm(12)), bImm) // 扩展为32位符号数
  val jOff    = Cat(Fill(11, jImm(20)), jImm) // 扩展为32位符号数
  // 预测：向后分支/JAL taken；预测目标
  val predT   = (isBr && bImm(12) === 1.U) || isJal
  val predTgt = Mux(isJal, pc + jOff, pc + bOff)

  // PC 更新逻辑（优先级：WB重定向 > EX重定向 > 正常步进）
  val snpc = pc + 4.U
  when(io.wbRedirect.valid) {
    pc := io.wbRedirect.target
  }.elsewhen(io.exRedirect.valid) {
    pc := io.exRedirect.target
  }.elsewhen(io.out.fire) {
    pc := Mux(predT, predTgt, snpc)
  }

  // 流水线处理
  io.out.valid           := io.cache.rsp.fire && !io.wbRedirect.valid && !io.exRedirect.valid
  io.out.bits.pc         := pc
  io.out.bits.inst       := io.cache.rsp.data
  io.out.bits.predTaken  := predT
  io.out.bits.predTarget := predTgt
  io.out.bits.expt       := expt
}
