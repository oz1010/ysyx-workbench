package pipeline_manual

import chisel3._
import chisel3.util._

/** IFU：取指 + 静态分支预测。
  *
  * 静态预测策略：
  *   - 条件分支（B-type）：向后跳（imm 为负）预测 taken，向前跳预测 not-taken
  *   - JAL：恒预测 taken（目标由立即数算出）
  *   - JALR：无法静态得知目标，预测 not-taken（在 EX 级修正）
  */

class Ifu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val cache      = new CacheIO(p)
    val out        = Decoupled(new IfBundle(p))
    val exRedirect = Input(new Redirect(p)) // 预测失败/跳转修正（EX 级）
    val wbRedirect = Input(new Redirect(p)) // 陷阱/MRET（WBU 级，优先级最高）
  })

  val ready   = RegInit(false.B) // 模块就绪标识
  val reqPend = RegInit(false.B) // 已发出请求、等待 ICache 返回

  // 真正的硬件pc应该直接内置默认值p.RESET_PC
  val pc = Reg(UInt(p.ADDR_WIDTH.W))
  if (p.RESET_PC_EN) {
    when(reset.asBool) {
      pc := p.RESET_PC.U
    }
  } else {
    val resetPcGetter = Module(new ResetPcGetter(p.ADDR_WIDTH))
    resetPcGetter.io.clk := clock
    resetPcGetter.io.rst := reset.asBool
    when(reset.asBool) {
      pc := resetPcGetter.io.reset_pc
    }
  }
  ready := true.B

  // icache 请求
  io.cache.req.valid   := ready && !reqPend // 只要流水线没卡死，持续取指
  io.cache.req.addr    := pc
  io.cache.req.wdata   := 0.U
  io.cache.req.wstrb   := 0.U
  io.cache.req.isWrite := false.B
  reqPend              := Mux(
    io.cache.req.valid && io.cache.req.ready,
    true.B,
    Mux(io.out.fire, false.B, reqPend)
  )

  // 接收指令并做静态预测
  val inst   = io.cache.resp.data
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
  io.out.valid           := io.cache.resp.valid && !io.wbRedirect.valid && !io.exRedirect.valid
  io.out.bits.pc         := pc
  io.out.bits.inst       := io.cache.resp.data
  io.out.bits.predTaken  := predT
  io.out.bits.predTarget := predTgt
}
