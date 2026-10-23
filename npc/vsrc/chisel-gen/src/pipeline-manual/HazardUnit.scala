package pipeline_manual

import chisel3._
import chisel3.util._
import scala.language.reflectiveCalls
import config.AutoConfig._
import config.ManuConfig._

class HazardUnit() extends Module {
  val io = IO(new Bundle {
    // EX 级等待使用的源寄存器
    val exRs1   = Input(UInt(GPR_ADDR_W.W))
    val exRs2   = Input(UInt(GPR_ADDR_W.W))
    val exValid = Input(Bool())

    // MEM 级尚未进入 WB 的 load，不能前递其地址作为结果
    val lsRd     = Input(UInt(GPR_ADDR_W.W))
    val lsIsLoad = Input(Bool())
    val lsValid  = Input(Bool())

    val stallEx = Output(Bool()) // 保持 EX 指令，由 ready 反压上游
  })

  io.stallEx := io.exValid && io.lsValid && io.lsIsLoad && io.lsRd =/= 0.U && (
    io.lsRd === io.exRs1 || io.lsRd === io.exRs2
  )
}
