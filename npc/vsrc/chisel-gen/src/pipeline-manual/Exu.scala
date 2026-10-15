package pipeline_manual

import chisel3._
import chisel3.util._

/** EXU：ALU、分支解析与静态预测修正、 CSR 读（返回旧值）、异常检测（含访存/跳转地址非对齐）。
  *   - 暂时不实现：前递（EX/MEM、MEM/WB）
  */
class Exu(p: CoreParams) extends Module {
  val io = IO(new Bundle {
    val in       = Flipped(Decoupled(new IdBundle(p)))
    val out      = Decoupled(new ExBundle(p))
    // 前递数据
    val lsStage  = Input(new ExBundle(p))
    val lsValid  = Input(Bool())
    val wbStage  = Input(new LsBundle(p))
    val wbValid  = Input(Bool())
    val wbData   = Input(UInt(p.XLEN.W))   // WBU 最终写回数据（含 load 数据）
    // CSR读口（读旧值）
    val csrRead  = new RegReadIO(p.CSR_ADDR_W, p.XLEN)
    // 预测失败 / 跳转修正重定向
    val redirect = Output(new Redirect(p)) // 预测修正/跳转（→ IFU）
  })

  val in = io.in.bits
  val v  = io.in.valid

  // ---------------- 前递 ----------------
  // EX/MEM 级前递需用"真实写回值"：CSR 指令写回 csrRdata、JAL/JALR 写回 pc+4
  val lsFwData                               = MuxLookup(io.lsStage.ctrl.wbSel, io.lsStage.aluResult)(
    Seq(
      WbSel.LOAD -> io.lsStage.aluResult, // load：相邻相关由 load-use stall 拦截
      WbSel.CSR  -> io.lsStage.csrRdata,  // CSR
      WbSel.PC_4 -> (io.lsStage.pc + 4.U) // JAL/JALR
    )
  )
  def fwd(regAddr: UInt, regVal: UInt): UInt = Mux(
    io.lsValid && io.lsStage.ctrl.rdWen && io.lsStage.rdAddr =/= 0.U && io.lsStage.rdAddr === regAddr,
    lsFwData,
    Mux(
      io.wbValid && io.wbStage.ctrl.rdWen && io.wbStage.rdAddr =/= 0.U && io.wbStage.rdAddr === regAddr,
      io.wbData,
      regVal
    )
  )

  // 注：load 相邻相关由 IDU 的 load-use stall 保证不会用到错误前递；
  //     间隔一条的 load 相关由 MEM/WB 前递（此时 load 数据已就绪）。
  // TODO 暂时不实现前递
  // val rs1f = fwd(in.rs1Addr, in.rs1Val)
  // val rs2f = fwd(in.rs2Addr, in.rs2Val)
  val rs1f = in.rs1Val
  val rs2f = in.rs2Val

  // ---------------- ALU ----------------
  val isLui     = in.inst(6, 0) === "b0110111".U
  val opA       = Mux(in.ctrl.usePc, in.pc, Mux(isLui, 0.U, rs1f))
  val opB       = Mux(in.ctrl.useImm, in.imm, rs2f)
  val shamt     = opB(4, 0)
  val aluResult = MuxLookup(in.ctrl.aluOp, opA + opB)(
    Seq(
      AluOp.ADD  -> (opA + opB),
      AluOp.SUB  -> (opA - opB),
      AluOp.AND  -> (opA & opB),
      AluOp.OR   -> (opA | opB),
      AluOp.XOR  -> (opA ^ opB),
      AluOp.SLL  -> (opA << shamt),
      AluOp.SRL  -> (opA >> shamt),
      AluOp.SRA  -> (opA.asSInt >> shamt).asUInt,
      AluOp.SLT  -> (opA.asSInt < opB.asSInt).asUInt,
      AluOp.SLTU -> (opA < opB)
    )
  )

  // ---------------- 分支解析 ----------------
  val eq         = rs1f === rs2f
  val lt         = rs1f.asSInt < rs2f.asSInt
  val ltu        = rs1f < rs2f
  val taken      = MuxLookup(in.ctrl.memOp, false.B)(
    Seq( // memOp 复用 funct3
      0.U -> eq,
      1.U -> !eq,
      4.U -> lt,
      5.U -> !lt,
      6.U -> ltu,
      7.U -> !ltu
    )
  )
  val brTarget   = in.pc + in.imm
  val jalrTarget = (rs1f + in.imm) & (~1.U(p.XLEN.W)).asUInt
  // 预测修正：分支实际走向与预测不符；JALR 预测 not-taken 恒需修正
  val mispredict =
    (in.ctrl.isBranch && (taken =/= in.predTaken)) || in.ctrl.isJalr
  val redirTgt   =
    Mux(in.ctrl.isJalr, jalrTarget, Mux(taken, brTarget, in.pc + 4.U))

  // ---------------- 异常检测 ----------------
  // 取指目标非对齐（JAL/分支 taken/JALR）
  val fetchTgt = Mux(in.ctrl.isJalr, jalrTarget, brTarget)
  val fetchMis =
    (in.ctrl.isJal || in.ctrl.isJalr || (in.ctrl.isBranch && taken)) && fetchTgt(
      1,
      0
    ) =/= 0.U
  // load/store 地址非对齐（访存对齐要求已由 LSU 假定）
  val ldMis    = in.ctrl.load && ((in.ctrl.memOp === MemOp.LH && aluResult(
    0
  ) =/= 0.U) || (in.ctrl.memOp === MemOp.LW && aluResult(1, 0) =/= 0.U))
  val stMis    = in.ctrl.store && ((in.ctrl.memOp === MemOp.SH && aluResult(
    0
  ) =/= 0.U) || (in.ctrl.memOp === MemOp.SW && aluResult(1, 0) =/= 0.U))

  val excValid =
    v && (in.ctrl.illegal || in.ctrl.ecall || in.ctrl.ebreak || fetchMis || ldMis || stMis)
  val excCause = PriorityMux(
    Seq(
      in.ctrl.illegal -> ExceptCode.INST_ILLEGAL,
      in.ctrl.ecall   -> ExceptCode.INST_ECALL,
      in.ctrl.ebreak  -> ExceptCode.INST_EBREAK,
      fetchMis        -> ExceptCode.FETCH_MISS,
      ldMis           -> ExceptCode.LOAD_MISS,
      stMis           -> ExceptCode.STORE_MISS
    )
  )

  // ---------------- CSR 读 ----------------
  io.csrRead.en   := true.B
  io.csrRead.addr := in.inst(31, 20)
  val csrWdata = Mux(in.ctrl.csrImm, Cat(0.U(27.W), in.inst(19, 15)), rs1f)

  // ---------------- 流水线处理 ----------------
  // 不阻塞流水线，单周期处理单元
  io.in.ready           := io.out.ready
  io.out.valid          := io.in.valid
  io.out.bits.pc        := in.pc
  io.out.bits.aluResult := aluResult
  io.out.bits.storeData := rs2f
  io.out.bits.rdAddr    := in.rdAddr
  io.out.bits.ctrl      := in.ctrl
  io.out.bits.csrAddr   := in.inst(31, 20)
  io.out.bits.csrWdata  := csrWdata
  io.out.bits.csrRdata  := io.csrRead.data
  io.out.bits.excValid  := excValid
  io.out.bits.excCause  := excCause

  // ---------------- 重定向（异常时不重定向，交由 WBU 走 mtvec） ----------------
  // TODO 这里因为成环而改用寄存器来处理
  val trapEn = RegInit(false.B)
  trapEn             := Mux((v && !excValid && mispredict), true.B, false.B)
  io.redirect.valid  := trapEn
  io.redirect.target := redirTgt
}
