package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._

/** EXU：ALU、分支解析与静态预测修正、 CSR 读（返回旧值）、异常检测（含访存/跳转地址非对齐）。
  *   - 暂时不实现：前递（EX/MEM、MEM/WB）
  */
class Exu() extends Module {
  val io = IO(new Bundle {
    val in       = Flipped(Decoupled(new IdBundle()))
    val out      = Decoupled(new ExBundle())
    // 前递数据
    val lsStage  = Input(new ExBundle())
    val lsValid  = Input(Bool())
    val wbStage  = Input(new LsBundle())
    val wbValid  = Input(Bool())
    val wbData   = Input(UInt(CONFIG_ADDR_WIDTH.W)) // WBU 最终写回数据（含 load 数据）
    // CSR读口（读旧值）
    val csrRead  = new RegReadIO(CSR_ADDR_W, CONFIG_ADDR_WIDTH)
    // 预测失败 / 跳转修正重定向
    val redirect = Output(new Redirect())           // 预测修正/跳转（→ IFU）
  })

  val in = io.in.bits
  val v  = io.in.valid

  // ---------------- 前递 ----------------
  // EX/MEM 级前递需用"真实写回值"：CSR 指令写回 csrRdata、JAL/JALR 写回 pc+4
  val lsFwData                               = MuxLookup(io.lsStage.ctrl.wbOp, io.lsStage.aluResult)(
    Seq(
      WbOp.LOAD -> io.lsStage.aluResult, // load：相邻相关由 load-use stall 拦截
      WbOp.CSR  -> io.lsStage.csrRdata,  // CSR
      WbOp.PC_4 -> (io.lsStage.pc + 4.U) // JAL/JALR
    )
  )
  def fwd(regAddr: UInt, regVal: UInt): UInt = MuxCase(
    regVal,
    Seq(
      (io.lsValid && io.lsStage.ctrl.isRdWen && io.lsStage.rdAddr =/= 0.U && io.lsStage.rdAddr === regAddr) -> lsFwData,
      (io.wbValid && io.wbStage.ctrl.isRdWen && io.wbStage.rdAddr =/= 0.U && io.wbStage.rdAddr === regAddr) -> io.wbData
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
  val opA       = Mux(in.ctrl.isUsePc, in.pc, Mux(isLui, 0.U, rs1f))
  val opB       = Mux(in.ctrl.isUseImm, in.imm, rs2f)
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
  val brTaken    = in.ctrl.isBrOp && MuxLookup(in.ctrl.brOp, false.B)(
    Seq(
      BrOp.BEQ  -> eq,
      BrOp.BNE  -> !eq,
      BrOp.BLT  -> lt,
      BrOp.BGE  -> !lt,
      BrOp.BLTU -> ltu,
      BrOp.BGEU -> !ltu
    )
  )
  val brTarget   = in.pc + in.imm
  val jalrTarget = (rs1f + in.imm) & (~1.U(CONFIG_ADDR_WIDTH.W)).asUInt
  // 预测修正：分支实际走向与预测不符；JALR需要读取rs1而无法预测；
  val mispredict =
    (brTaken =/= in.predTaken) || in.ctrl.isJalr
  val redirTgt   = MuxCase(
    in.pc + 4.U,
    Seq(
      in.ctrl.isJalr -> jalrTarget,
      brTaken        -> brTarget
    )
  )

  // ---------------- 异常检测 ----------------
  // 取指目标非对齐（JAL/分支 taken/JALR）
  val fetchTgt = Mux(in.ctrl.isJalr, jalrTarget, brTarget)
  val fetchMis =
    (in.ctrl.isJal || in.ctrl.isJalr || brTaken) && fetchTgt(1, 0) =/= 0.U
  // load/store 地址非对齐（访存对齐要求已由 LSU 假定）
  val ldMis    =
    in.ctrl.isLoad && ((in.ctrl.memOp === MemOp.LH && aluResult(
      0
    ) =/= 0.U) || (in.ctrl.memOp === MemOp.LW && aluResult(1, 0) =/= 0.U))
  val stMis    =
    in.ctrl.isStore && ((in.ctrl.memOp === MemOp.SH && aluResult(
      0
    ) =/= 0.U) || (in.ctrl.memOp === MemOp.SW && aluResult(1, 0) =/= 0.U))

  val excValid =
    v && (in.ctrl.isIllegal || in.ctrl.isEcall || in.ctrl.isEbreak || fetchMis || ldMis || stMis)
  val excCause = PriorityMux(
    Seq(
      in.ctrl.isIllegal -> ExceptCode.INST_ILLEGAL,
      in.ctrl.isEcall   -> ExceptCode.INST_ECALL,
      in.ctrl.isEbreak  -> ExceptCode.INST_EBREAK,
      fetchMis          -> ExceptCode.FETCH_MISS,
      ldMis             -> ExceptCode.LOAD_MISS,
      stMis             -> ExceptCode.STORE_MISS
    )
  )

  // ---------------- CSR读写 ----------------
  io.csrRead.en   := true.B
  io.csrRead.addr := in.inst(31, 20)
  val csrWdata = Mux(in.ctrl.isCsrImm, Cat(0.U(27.W), in.inst(19, 15)), rs1f)

  // ---------------- 流水线处理 ----------------
  // 不阻塞流水线，单周期处理单元
  io.in.ready           := io.out.ready
  io.out.valid          := io.in.valid
  io.out.bits.pc        := in.pc
  io.out.bits.dnpc      := redirTgt
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
