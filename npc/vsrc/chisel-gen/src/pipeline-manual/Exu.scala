package pipeline_manual

import chisel3._
import chisel3.util._
import scala.language.reflectiveCalls
import config.AutoConfig._
import config.ManuConfig._

/** EXU：ALU、分支解析与静态预测修正、CSR 读（返回旧值）、异常检测及 MEM/WB 数据前递。 */
class Exu() extends Module {
  val io = IO(new Bundle {
    val in        = Flipped(Decoupled(new IdBundle()))
    val out       = Decoupled(new ExBundle())
    // 前递数据
    val lsStage   = Input(new ExBundle())
    val lsValid   = Input(Bool())
    val wbStage   = Input(new LsBundle())
    val wbValid   = Input(Bool())
    val wbData    = Input(UInt(CONFIG_ADDR_WIDTH.W)) // WBU 最终写回数据（含 load 数据）
    val loadStall = Input(Bool())                    // MEM load 的结果尚未进入 WB
    // CSR读口（读旧值）
    val csrRead   = new RegReadIO(CSR_ADDR_W, CONFIG_ADDR_WIDTH)
    // 预测失败 / 跳转修正重定向
    val redirect  = Output(new Redirect())           // 预测修正/跳转（→ IFU）
  })

  val in   = io.in.bits
  val v    = io.in.valid
  val expt = Wire(new Expt)
  ExptDefaults(expt);

  // ---------------- 前递 ----------------
  // EX/MEM 级前递需用"真实写回值"：CSR 指令写回 csrRdata、JAL/JALR 写回 pc+4
  val lsFwData                               = MuxLookup(io.lsStage.ctrl.wbOp, io.lsStage.aluResult)(
    Seq(
      WbOp.CSR  -> io.lsStage.csrRdata,  // CSR
      WbOp.PC_4 -> (io.lsStage.pc + 4.U) // JAL/JALR
    )
  )
  val lsCanForward                           = io.lsValid && io.lsStage.ctrl.isRdWen &&
    !io.lsStage.ctrl.isLoad && !io.lsStage.expt.en && io.lsStage.rdAddr =/= 0.U
  val wbCanForward                           = io.wbValid && io.wbStage.ctrl.isRdWen &&
    !io.wbStage.expt.en && io.wbStage.rdAddr =/= 0.U
  def fwd(regAddr: UInt, regVal: UInt): UInt = Mux(
    regAddr === 0.U,
    0.U,
    MuxCase(
      regVal,
      Seq(
        (lsCanForward && io.lsStage.rdAddr === regAddr) -> lsFwData,
        (wbCanForward && io.wbStage.rdAddr === regAddr) -> io.wbData
      )
    )
  )

  // EX 被反压时保存已经看到的前递值，避免生产者离开 WB 后退回 ID 的旧操作数。
  val operandsHeld = RegInit(false.B)
  val heldRs1      = Reg(UInt(CONFIG_DATA_WIDTH.W))
  val heldRs2      = Reg(UInt(CONFIG_DATA_WIDTH.W))
  val rs1f         = fwd(in.rs1Addr, Mux(operandsHeld, heldRs1, in.rs1Val))
  val rs2f         = fwd(in.rs2Addr, Mux(operandsHeld, heldRs2, in.rs2Val))
  when(io.in.valid && !io.in.ready) {
    operandsHeld := true.B
    heldRs1      := rs1f
    heldRs2      := rs2f
  }.otherwise {
    operandsHeld := false.B
  }

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
  // 条件分支修正走向，JALR 等待 rs1 后修正；JAL 已在 IF 预测，不应误报。
  val mispredict =
    (in.ctrl.isBrOp && (brTaken =/= in.predTaken)) || in.ctrl.isJalr
  val redirTgt   = MuxCase(
    in.pc + 4.U,
    Seq(
      in.ctrl.isJalr             -> jalrTarget,
      (in.ctrl.isJal || brTaken) -> brTarget
    )
  )

  // ---------------- 异常检测 ----------------
  // 取指目标非对齐（JAL/分支 taken/JALR）
  val fetchTgt = Mux(in.ctrl.isJalr, jalrTarget, brTarget)
  val fetchMis =
    (in.ctrl.isJal || in.ctrl.isJalr || brTaken) && fetchTgt(1, 0) =/= 0.U
  // load/store 地址非对齐（访存对齐要求已由 LSU 假定）
  val ldMis    =
    in.ctrl.isLoad && (((in.ctrl.memOp === MemOp.LH || in.ctrl.memOp === MemOp.LHU) &&
      aluResult(0) =/= 0.U) || (in.ctrl.memOp === MemOp.LW && aluResult(
      1,
      0
    ) =/= 0.U))
  val stMis    =
    in.ctrl.isStore && ((in.ctrl.memOp === MemOp.SH && aluResult(0) =/= 0.U) ||
      (in.ctrl.memOp === MemOp.SW && aluResult(1, 0) =/= 0.U))

  expt.en    :=
    v && (in.ctrl.isIllegal || in.ctrl.isEcall || in.ctrl.isEbreak || fetchMis || ldMis || stMis)
  expt.cause := PriorityMux(
    Seq(
      in.ctrl.isIllegal -> ExptCode.INST_ILLEGAL,
      in.ctrl.isEcall   -> ExptCode.INST_ECALL,
      in.ctrl.isEbreak  -> ExptCode.INST_EBREAK,
      fetchMis          -> ExptCode.FETCH_MISS,
      ldMis             -> ExptCode.LOAD_MISS,
      stMis             -> ExptCode.STORE_MISS
    )
  )

  // 与 cause 使用相同优先级；上游异常在输出处连同 tval 一起优先透传。
  expt.tval := MuxCase(
    0.U,
    Seq(
      in.ctrl.isIllegal -> in.inst,
      in.ctrl.isEcall   -> 0.U,
      in.ctrl.isEbreak  -> in.pc,
      fetchMis          -> fetchTgt,
      (ldMis || stMis)  -> aluResult
    )
  )

  // ---------------- CSR读写 ----------------
  io.csrRead.en   := true.B
  io.csrRead.addr := in.inst(31, 20)
  val csrWdata = Mux(in.ctrl.isCsrImm, Cat(0.U(27.W), in.inst(19, 15)), rs1f)

  // ---------------- 流水线处理 ----------------
  // load-use 时保持 EX 指令，等 load 进入 WB 后使用真实写回数据。
  io.in.ready           := io.out.ready && !io.loadStall
  io.out.valid          := io.in.valid && !io.loadStall
  io.out.bits.pc        := in.pc
  io.out.bits.dnpc      := redirTgt
  io.out.bits.aluResult := aluResult
  io.out.bits.storeData := rs2f
  io.out.bits.rdAddr    := in.rdAddr
  io.out.bits.ctrl      := in.ctrl
  io.out.bits.csrAddr   := in.inst(31, 20)
  io.out.bits.csrWdata  := csrWdata
  io.out.bits.csrRdata  := io.csrRead.data
  io.out.bits.expt      := Mux(io.in.bits.expt.en, io.in.bits.expt, expt)

  // ---------------- 重定向（异常时不重定向，交由 WBU 走 mtvec） ----------------
  // EX 接受指令时同步锁存事件和目标，下一拍仅冲刷前端，保留 EX/MEM 中的自身。
  // valid 每拍更新，反压或 load-use 等待时不发请求；寄存器隔断 flush 的组合反馈。
  val redirectFire = io.in.fire && !in.expt.en && !expt.en && mispredict
  val redirect     = RegInit(0.U.asTypeOf(new Redirect()))
  redirect.valid := redirectFire
  when(redirectFire) {
    redirect.target := redirTgt
  }
  io.redirect    := redirect
}
