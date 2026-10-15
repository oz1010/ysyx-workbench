package pipeline_manual

import chisel3._
import chisel3.util._

/** 通用流水线级间寄存器 (Pipeline Register)
  *   - 支持 Valid-Ready 握手协议、Stall（暂停/保持）以及 Flush（冲刷/清零）
  *   - 状态更新逻辑 (优先级：Flush > Stall > 正常握手流转)
  *
  * @param gen
  *   数据负载的类型 (Bundle 或 UInt 等)
  * @param in
  *   上游输入
  * @param out
  *   下游输出
  * @param flush
  *   高电平有效：冲刷清零
  * @param stall
  *   高电平有效：保持当前寄存器内容不动
  */
class PipelineReg[T <: Data](gen: T) extends Module {
  val io = IO(new Bundle {
    val in    = Flipped(Decoupled(gen))
    val out   = Decoupled(gen)
    val flush = Input(Bool())
    val stall = Input(Bool())
  })

  val data_reg  = Reg(gen)
  val valid_reg = RegInit(false.B)

  when(io.flush) {
    valid_reg := false.B
  }.elsewhen(!io.stall) {
    valid_reg := io.in.valid
    when(io.in.valid) {
      data_reg := io.in.bits
    }
  }

  io.in.ready  := !io.stall && (io.out.ready || !valid_reg)
  io.out.valid := valid_reg && !io.flush
  io.out.bits  := data_reg
}
