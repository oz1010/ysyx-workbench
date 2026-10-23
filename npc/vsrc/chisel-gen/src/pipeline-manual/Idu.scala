package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._

/** IDU：译码。
  *   - RV32I(RV32E) 基础指令集，SYSTEM 支持 ECALL/EBREAK/MRET/CSR 指令。
  */
class Idu() extends Module {
  val io = IO(new Bundle {
    val in         = Flipped(Decoupled(new IfBundle()))
    val out        = Decoupled(new IdBundle())
    val gprRead1   = new RegReadIO(GPR_ADDR_W, CONFIG_ADDR_WIDTH)
    val gprRead2   = new RegReadIO(GPR_ADDR_W, CONFIG_ADDR_WIDTH)
    val gprWrite   = Flipped(new RegWriteIO(GPR_ADDR_W, CONFIG_ADDR_WIDTH))
    val loadStall  = Input(Bool()) // load-use RAW 冒险，请求 stall
    val exRedirect = Input(new Redirect())
    val wbRedirect = Input(new Redirect())
  })

  // ---------------- 译码 ----------------
  val inst   = io.in.bits.inst
  val opcode = inst(6, 0)
  val funct3 = inst(14, 12)
  val funct7 = inst(31, 25)
  val ctrl   = Ctrl.decode(inst)

  // ---------------- 立即数 ----------------
  val immI   = Cat(Fill(20, inst(31)), inst(31, 20))
  val immS   = Cat(Fill(20, inst(31)), inst(31, 25), inst(11, 7))
  val immB   = Cat(
    Fill(19, inst(31)),
    inst(31),
    inst(7),
    inst(30, 25),
    inst(11, 8),
    0.U(1.W)
  )
  val immU   = Cat(inst(31, 12), 0.U(12.W))
  val immJ   = Cat(
    Fill(11, inst(31)),
    inst(31),
    inst(19, 12),
    inst(20),
    inst(30, 21),
    0.U(1.W)
  )
  val imm    = MuxLookup(opcode, immI)(
    Seq(
      "b1100011".U -> immB, // B
      "b0110111".U -> immU, // U
      "b0010111".U -> immU, // U
      "b1101111".U -> immJ, // J
      "b0100011".U -> immS  // S
    )
  )
  val immSel = Mux(
    opcode === "b0010011".U && funct3 === 3.U,
    Cat(0.U(20.W), inst(31, 20)), // SLTIU：零扩展
    imm
  )

  // ---------------- 读寄存器 ----------------
  val rs1Addr = inst(18, 15)
  val rs2Addr = inst(23, 20)
  val rdAddr  = inst(10, 7)
  io.gprRead1.en   := true.B
  io.gprRead1.addr := rs1Addr
  io.gprRead2.en   := true.B
  io.gprRead2.addr := rs2Addr
  // 旁路：本周期 WBU 正在写同一寄存器时直接取写回值（覆盖距离-3 RAW）
  val rs1Val = Mux(
    rs1Addr === 0.U,
    0.U,
    Mux(
      io.gprWrite.wen && io.gprWrite.waddr === rs1Addr,
      io.gprWrite.wdata,
      io.gprRead1.data
    )
  )
  val rs2Val = Mux(
    rs2Addr === 0.U,
    0.U,
    Mux(
      io.gprWrite.wen && io.gprWrite.waddr === rs2Addr,
      io.gprWrite.wdata,
      io.gprRead2.data
    )
  )

  // ---------------- 流水线处理 ----------------
  val stalled = io.loadStall
  io.in.ready            := io.out.ready && !stalled
  io.out.valid           := io.in.valid && !stalled
  io.out.bits.pc         := io.in.bits.pc
  io.out.bits.inst       := io.in.bits.inst
  io.out.bits.rs1Val     := rs1Val
  io.out.bits.rs2Val     := rs2Val
  io.out.bits.imm        := immSel
  io.out.bits.rs1Addr    := rs1Addr
  io.out.bits.rs2Addr    := rs2Addr
  io.out.bits.rdAddr     := rdAddr
  io.out.bits.ctrl       := ctrl
  io.out.bits.predTaken  := io.in.bits.predTaken
  io.out.bits.predTarget := io.in.bits.predTarget
}
