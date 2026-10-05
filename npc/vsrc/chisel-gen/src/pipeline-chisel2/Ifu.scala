package pipeline_chisel2

import chisel3._
import chisel3.util._

/**
 * IFU：取指 + 静态分支预测 + IF/ID 级间寄存器。
 * 通过 io.out（Decoupled，valid/ready）与 IDU 握手；
 * 取指经 ICache（io.cache，req 通道 valid/ready 握手）。
 * 框架：端口与连接已定义，内部实现留空。
 */
class Ifu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val cache      = new CacheCpuIO(p)            // → ICache CPU 侧
    val out        = Decoupled(new IfIdBundle(p)) // IF/ID 级间（valid/ready 握手）
    val exRedirect = Input(new Redirect(p))       // 预测失败/跳转修正（EX 级）
    val wbRedirect = Input(new Redirect(p))       // 陷阱/MRET（WBU 级，优先级最高）
    val pc         = Output(UInt(p.ADDR_WIDTH.W)) // 当前取指 PC（关键输出）
  })

  // TODO: 取指请求、静态分支预测、IF/ID 寄存器与冲刷
  io.cache.req.valid   := false.B
  io.cache.req.addr    := 0.U
  io.cache.req.wdata   := 0.U
  io.cache.req.wstrb   := 0.U
  io.cache.req.isWrite := false.B
  io.out.valid         := false.B
  io.out.bits          := DontCare
  io.pc                := p.RESET_VEC.U(p.ADDR_WIDTH.W)
}
