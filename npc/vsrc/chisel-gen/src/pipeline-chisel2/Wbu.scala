package pipeline_chisel2

import chisel3._
import chisel3.util._

/**
 * WBU：指令提交 + 寄存器堆写回 + CSR 写/陷阱 + MRET + 中断采样。
 * 上游 MEM/WB 为 valid/ready 握手；提交成功 io.valid 输出单周期脉冲。
 * 陷阱/MRET/中断在本级裁决并重定向取指（优先级最高）。
 * 框架：端口与连接已定义，内部实现留空。
 */
class Wbu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val in        = Flipped(Decoupled(new MemWbBundle(p))) // MEM/WB 级间
    val redirect  = Output(new Redirect(p))                // 陷阱/MRET（→ IFU）
    val rfWen     = Output(Bool())                         // 寄存器堆写使能（→ IDU）
    val rfRd      = Output(UInt(p.REG_ADDR_WIDTH.W))       // 写回寄存器号
    val rfData    = Output(UInt(p.XLEN.W))                 // 写回数据
    val csrWen    = Output(Bool())                         // CSR 写使能
    val csrWaddr  = Output(UInt(12.W))                     // CSR 写地址
    val csrWdata  = Output(UInt(p.XLEN.W))                 // CSR 写数据
    val csrTrap   = Output(new TrapReq(p))                 // 陷阱请求（→ CSR）
    val csrMret   = Output(Bool())                         // MRET（→ CSR）
    val interrupt = Input(Bool())                          // 外部中断（io.interrupt）
    val valid     = Output(Bool())                         // 完成一条指令（关键输出）
  })

  // TODO: 提交裁决（异常/中断/mret）、写回数据选择（ALU/Load/CSR/PC+4）
  io.in.ready        := false.B
  io.redirect.valid  := false.B
  io.redirect.target := 0.U
  io.rfWen           := false.B
  io.rfRd            := 0.U
  io.rfData          := 0.U
  io.csrWen          := false.B
  io.csrWaddr        := 0.U
  io.csrWdata        := 0.U
  io.csrTrap.valid   := false.B
  io.csrTrap.cause   := 0.U
  io.csrTrap.epc     := 0.U
  io.csrMret         := false.B
  io.valid           := false.B
}
