package pipeline_chisel2

import chisel3._
import chisel3.util._

/**
 * EXU：ALU 运算 + 分支/跳转修正 + CSR 读 + EX/MEM 级间寄存器。
 * 上游 ID/EX、下游 EX/MEM 均为 valid/ready 握手；
 * 预测失败或跳转在本级产生重定向（冲刷 younger 指令）。
 * 框架：端口与连接已定义，内部实现留空。
 */
class Exu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val in       = Flipped(Decoupled(new IdExBundle(p))) // ID/EX 级间
    val out      = Decoupled(new ExMemBundle(p))         // EX/MEM 级间
    val redirect = Output(new Redirect(p))               // 预测修正/跳转（→ IFU）
    val csrRaddr = Output(UInt(12.W))                    // CSR 读地址（→ CSR）
    val csrRdata = Input(UInt(p.XLEN.W))                 // CSR 读数据（旧值）
  })

  // TODO: 操作数前递、ALU、分支判定、CSR 读数据旁路
  io.in.ready       := false.B
  io.out.valid      := false.B
  io.out.bits       := DontCare
  io.redirect.valid := false.B
  io.redirect.target := 0.U
  io.csrRaddr       := 0.U
}
