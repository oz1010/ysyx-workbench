package pipeline_manual

import chisel3._
import chisel3.util._

class HazardUnit(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    // 来自 ID 级的信息（用于检测 Load-Use）
    val idRs1   = Input(UInt(4.W))
    val idRs2   = Input(UInt(4.W))
    val idValid = Input(Bool())

    // 来自 EX 级的信息（判断上一条指令是否是 Load）
    val exRd     = Input(UInt(4.W))
    val exIsLoad = Input(Bool()) // 假设 ctrl 中有指示是否为 Load 的标志
    val exValid  = Input(Bool())

    // 重定向输入
    val exRedirect = Input(Bool())
    val wbRedirect = Input(Bool())

    // 输出控制信号
    val stallIfId = Output(Bool()) // 暂停 IF/ID 寄存器和 PC
    val flushAll  = Output(Bool()) // 全局冲刷流水线
  })

  // 1. Load-Use 冒险检测逻辑
  // 条件：EX 级是 Load 指令，且其 rd 与 ID 级的 rs1 或 rs2 冲突（且非 x0 寄存器）
  val loadUseHazard = io.exValid && io.exIsLoad && (
    ((io.exRd === io.idRs1) && (io.idRs1 =/= 0.U)) ||
      ((io.exRd === io.idRs2) && (io.idRs2 =/= 0.U))
  )

  // 2. 输出赋值
  io.stallIfId := loadUseHazard
  io.flushAll  := io.exRedirect || io.wbRedirect
}
