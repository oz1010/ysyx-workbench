package pipeline_chisel

import chisel3._
import chisel3.util._

/**
 * EXU：ALU、前递（EX/MEM、MEM/WB）、分支解析与静态预测修正、
 *      CSR 读（返回旧值）、异常检测（含访存/跳转地址非对齐）。
 */
class Exu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val idex      = Input(new IdExBundle(p))
    val idexValid = Input(Bool())
    // 前递来源
    val memStage  = Input(new ExMemBundle(p))
    val memValid  = Input(Bool())
    val wbStage   = Input(new MemWbBundle(p))
    val wbValid   = Input(Bool())
    val wbData    = Input(UInt(p.XLEN.W)) // WBU 最终写回数据（含 load 数据）
    // CSR 读口（读旧值）
    val csrRaddr  = Output(UInt(12.W))
    val csrRdata  = Input(UInt(p.XLEN.W))
    // 输出到 EX/MEM
    val out       = Output(new ExMemBundle(p))
    // 预测失败 / 跳转修正重定向
    val redirect  = Output(new Redirect(p))
  })

  val in = io.idex
  val v  = io.idexValid

  // ---------------- 前递 ----------------
  // EX/MEM 级前递需用"真实写回值"：CSR 指令写回 csrRdata、JAL/JALR 写回 pc+4
  val memFwdData = MuxLookup(io.memStage.ctrl.wbSel, io.memStage.aluResult)(Seq(
    1.U -> io.memStage.aluResult,       // load：相邻相关由 load-use stall 拦截
    2.U -> io.memStage.csrRdata,        // CSR
    3.U -> (io.memStage.pc + 4.U)       // JAL/JALR
  ))
  def fwd(regAddr: UInt, regVal: UInt): UInt = Mux(
    io.memValid && io.memStage.ctrl.rdWen && io.memStage.rdAddr =/= 0.U &&
      io.memStage.rdAddr === regAddr, memFwdData,
    Mux(io.wbValid && io.wbStage.ctrl.rdWen && io.wbStage.rdAddr =/= 0.U &&
      io.wbStage.rdAddr === regAddr, io.wbData, regVal))
  // 注：load 相邻相关由 IDU 的 load-use stall 保证不会用到错误前递；
  //     间隔一条的 load 相关由 MEM/WB 前递（此时 load 数据已就绪）。
  val rs1f = fwd(in.rs1Addr, in.rs1Val)
  val rs2f = fwd(in.rs2Addr, in.rs2Val)

  // ---------------- ALU ----------------
  val isLui = in.inst(6, 0) === "b0110111".U
  val opA = Mux(in.ctrl.usePc, in.pc, Mux(isLui, 0.U, rs1f))
  val opB = Mux(in.ctrl.useImm, in.imm, rs2f)
  val shamt = opB(4, 0)
  val aluResult = MuxLookup(in.ctrl.aluOp, opA + opB)(Seq(
    0.U -> (opA + opB),
    1.U -> (opA - opB),
    2.U -> (opA & opB),
    3.U -> (opA | opB),
    4.U -> (opA ^ opB),
    5.U -> (opA << shamt),
    6.U -> (opA >> shamt),
    7.U -> (opA.asSInt >> shamt).asUInt,
    8.U -> (opA.asSInt < opB.asSInt).asUInt,
    9.U -> (opA < opB)
  ))

  // ---------------- 分支解析 ----------------
  val eq  = rs1f === rs2f
  val lt  = rs1f.asSInt < rs2f.asSInt
  val ltu = rs1f < rs2f
  val taken = MuxLookup(in.ctrl.memOp, false.B)(Seq( // memOp 复用 funct3
    0.U -> eq,  1.U -> !eq,
    4.U -> lt,  5.U -> !lt,
    6.U -> ltu, 7.U -> !ltu
  ))

  val brTarget  = in.pc + in.imm
  val jalrTarget = (rs1f + in.imm) & (~1.U(p.XLEN.W)).asUInt

  // 预测修正：分支实际走向与预测不符；JALR 预测 not-taken 恒需修正
  val mispredict = (in.ctrl.isBranch && (taken =/= in.predTaken)) || in.ctrl.isJalr
  val redirTgt = Mux(in.ctrl.isJalr, jalrTarget,
                 Mux(taken, brTarget, in.pc + 4.U))

  // ---------------- 异常检测 ----------------
  // 取指目标非对齐（JAL/分支 taken/JALR）
  val fetchTgt = Mux(in.ctrl.isJalr, jalrTarget, brTarget)
  val fetchMis = (in.ctrl.isJal || in.ctrl.isJalr ||
                  (in.ctrl.isBranch && taken)) && fetchTgt(1, 0) =/= 0.U
  // load/store 地址非对齐（访存对齐要求已由 LSU 假定）
  val ldMis = in.ctrl.load && (
    (in.ctrl.memOp === 1.U && aluResult(0) =/= 0.U) ||
    (in.ctrl.memOp === 2.U && aluResult(1, 0) =/= 0.U))
  val stMis = in.ctrl.store && (
    (in.ctrl.memOp === 1.U && aluResult(0) =/= 0.U) ||
    (in.ctrl.memOp === 2.U && aluResult(1, 0) =/= 0.U))

  val excValid = v && (in.ctrl.illegal || in.ctrl.ecall || in.ctrl.ebreak ||
                         fetchMis || ldMis || stMis)
  val excCause = PriorityMux(Seq(
    in.ctrl.illegal -> 2.U,
    in.ctrl.ecall   -> 11.U,
    in.ctrl.ebreak  -> 3.U,
    fetchMis        -> 0.U,
    ldMis           -> 4.U,
    stMis           -> 6.U
  ))

  // ---------------- CSR 读 ----------------
  io.csrRaddr := in.inst(31, 20)
  val csrWdata = Mux(in.ctrl.csrImm, Cat(0.U(27.W), in.inst(19, 15)), rs1f)

  // ---------------- 输出 EX/MEM ----------------
  io.out.pc        := in.pc
  io.out.aluResult := aluResult
  io.out.storeData := rs2f
  io.out.rdAddr    := in.rdAddr
  io.out.ctrl      := in.ctrl
  io.out.csrAddr   := in.inst(31, 20)
  io.out.csrWdata  := csrWdata
  io.out.csrRdata  := io.csrRdata
  io.out.excValid  := excValid
  io.out.excCause  := excCause

  // ---------------- 重定向（异常时不重定向，交由 WBU 走 mtvec） ----------------
  io.redirect.valid  := v && !excValid && mispredict
  io.redirect.target := redirTgt
}
