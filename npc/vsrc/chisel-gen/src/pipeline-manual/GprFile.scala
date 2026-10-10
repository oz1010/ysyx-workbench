package pipeline_manual

import chisel3._
import chisel3.util._

/** GPR 文件：mstatus(mtvec/mepc/mcause/mvendorid/marchid) 仅实现 M
  * 模式最常用的位：mstatus.MIE(bit3)、mstatus.MPIE(bit7)。
  */
class GprFile(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val read1 = Flipped(new RegReadIO(p.GPR_ADDR_W, p.XLEN))
    val read2 = Flipped(new RegReadIO(p.GPR_ADDR_W, p.XLEN))
    val write = Flipped(new RegWriteIO(p.GPR_ADDR_W, p.XLEN))
  })

  /*
  寄存器别名，register alias, ch2.3
  zero = x[0];
  ra = x[1];
  sp = x[2];
  gp = x[3];
  tp = x[4];
  t0 = x[5];
  t1 = x[6];
  t2 = x[7];
  s0 = x[8];
  fp = x[8];
  s1 = x[9];
  a[0:5];
   */
  // ---------------- 寄存器堆（RV32E：16 x 32，x0 恒 0） ----------------
  val x = RegInit(VecInit(Seq.fill(p.GPR_COUNT)(0.U(p.XLEN.W))))

  // 读写逻辑
  when(io.write.en && io.write.addr =/= 0.U) {
    x(io.write.addr) := io.write.data
  }
  io.read1.data := Mux(io.read1.addr === 0.U, 0.U, x(io.read1.addr))
  io.read2.data := Mux(io.read2.addr === 0.U, 0.U, x(io.read2.addr))
}
