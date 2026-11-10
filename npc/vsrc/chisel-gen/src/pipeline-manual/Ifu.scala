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
  *
  * 取指协议：单笔在途请求（reqPend），ICache 的 rsp 为单拍脉冲，必须当拍接收。
  * 响应可能晚于重定向到达（错误路径取指），因此：
  *   - 重定向放弃在途请求并武装 discard，其迟到响应被整体丢弃，不得带着重定向后的
  *     pc 下发（否则错误路径指令会顶替重定向目标进入流水线）；
  *   - 重定向当拍出现的响应同属错误路径，一并丢弃；
  *   - 下游未就绪时响应缓存在单拍缓冲中，之后原样下发，不丢指令也不死锁。
  */

class Ifu() extends Module {
  val io = IO(new Bundle {
    val reset_pc   = Input(UInt(CONFIG_ADDR_WIDTH.W))
    val cache      = new CacheIO()
    val out        = Decoupled(new IfBundle())
    val exRedirect = Input(new Redirect()) // 预测失败/跳转修正（EX 级）
    val wbRedirect = Input(new Redirect()) // 陷阱/MRET（WBU 级，优先级最高）
  })

  val reqPend  = RegInit(false.B) // 已发出请求、等待 ICache 返回
  val discard  = RegInit(false.B) // 在途请求已被重定向放弃，其迟到响应待丢弃
  val reqPc    = Reg(UInt(CONFIG_ADDR_WIDTH.W)) // 请求接受时的 PC，不随重定向改变
  val bufValid = RegInit(false.B) // 响应已接收但下游未就绪，缓存在 buf 中
  val buf      = Reg(new IfBundle)
  val expt     = Wire(new Expt)
  ExptDefaults(expt)
  expt.en    := io.cache.rsp.error
  expt.cause := ExptCode.FETCH_ACCESS
  expt.tval  := reqPc

  // 复位重置pc值
  val pc = Reg(UInt(CONFIG_ADDR_WIDTH.W))

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
  val responsePc = Mux(reqPend, reqPc, pc)
  val predTgt = Mux(isJal, responsePc + jOff, responsePc + bOff)

  val redirect = io.wbRedirect.valid || io.exRedirect.valid
  val reqFire  = io.cache.req.fire
  val rspValid = io.cache.rsp.valid
  // 重定向当拍或 discard 期间出现的响应，都归属重定向前发出的错误路径取指
  val dropRsp  = rspValid && (discard || redirect)

  // 本拍对外呈现的取指结果：优先下发缓冲，其次当拍响应，PC 随请求保存。
  val rspBundle = Wire(new IfBundle())
  rspBundle.pc         := responsePc
  rspBundle.inst       := inst
  rspBundle.predTaken  := predT
  rspBundle.predTarget := predTgt
  rspBundle.expt       := expt
  val presented = Mux(bufValid, buf, rspBundle)

  // icache 请求：单笔在途；缓冲未清空或有重定向的当拍不发新请求
  io.cache.req.valid := !reset.asBool && !reqPend && !bufValid && !redirect
  io.cache.req.addr  := pc
  io.cache.req.op    := MemOp.FLAG_4B
  io.cache.req.wdata := 0.U
  io.cache.rsp.ready := true.B

  io.out.valid           := (bufValid || (rspValid && !dropRsp)) && !redirect
  io.out.bits.pc         := presented.pc
  io.out.bits.inst       := presented.inst
  io.out.bits.predTaken  := presented.predTaken
  io.out.bits.predTarget := presented.predTarget
  io.out.bits.expt       := presented.expt

  // ---------------- 时序更新 ----------------
  // discard：放弃在途请求的重定向将其武装，该请求的迟到响应当拍解除
  when(rspValid) {
    discard := false.B
  }.elsewhen(redirect && reqPend) {
    discard := true.B
  }

  // 重定向不能取消总线上已接受的请求：先排空旧响应，再发送目标地址。
  when(reqFire) {
    reqPend := true.B
    reqPc   := pc
  }
  when(rspValid) {
    reqPend := false.B
  }

  // bufValid：重定向冲刷缓冲；响应被丢弃或当拍转发则不缓存；缓冲下发后清除
  when(redirect) {
    bufValid := false.B
  }.elsewhen(rspValid && dropRsp) {
    bufValid := false.B
  }.elsewhen(rspValid) {
    bufValid := !io.out.ready
    when(!io.out.ready) {
      buf := rspBundle
    }
  }.elsewhen(bufValid && io.out.fire) {
    bufValid := false.B
  }

  // PC 更新逻辑（优先级：复位 > WB重定向 > EX重定向 > 正常步进）
  when(reset.asBool) {
    pc := io.reset_pc
  }.elsewhen(io.wbRedirect.valid) {
    pc := io.wbRedirect.target
  }.elsewhen(io.exRedirect.valid) {
    pc := io.exRedirect.target
  }.elsewhen(io.out.fire) {
    pc := Mux(presented.predTaken, presented.predTarget, presented.pc + 4.U)
  }
}
