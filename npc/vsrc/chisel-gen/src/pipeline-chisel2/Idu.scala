package pipeline_chisel2

import chisel3._
import chisel3.util._

/**
 * IDU：译码 + 寄存器堆读 + ID/EX 级间寄存器。
 * 上游 IF/ID、下游 ID/EX 均为 valid/ready 握手；
 * 写回口由 WBU 驱动（x0 恒 0）。load-use 冒险等后续在内部实现。
 * 框架：端口与连接已定义，内部实现留空。
 */
class Idu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val in      = Flipped(Decoupled(new IfIdBundle(p))) // IF/ID 级间
    val out     = Decoupled(new IdExBundle(p))          // ID/EX 级间
    val rfWen   = Input(Bool())                         // WBU 写回使能
    val rfRd    = Input(UInt(p.REG_ADDR_WIDTH.W))       // WBU 写回寄存器号
    val rfData  = Input(UInt(p.XLEN.W))                 // WBU 写回数据
  })

  // TODO: 译码、立即数生成、寄存器堆（16 端口 x0~x15）、load-use 冒险处理
  io.in.ready  := false.B
  io.out.valid := false.B
  io.out.bits  := DontCare
}
