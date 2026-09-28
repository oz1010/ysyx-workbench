import chisel3._
import chisel3.util._

class MicroOp extends Bundle {          // 流水级间传递的统一微操作
  val valid = Bool()
  val rs1   = UInt(5.W)                 // 源操作数地址
  val rs2   = UInt(5.W)
  val rd    = UInt(5.W)                 // 目的寄存器（x0 表示不写）
  val imm   = UInt(32.W)
  val op    = UInt(4.W)                 // 操作码
  val isLoad = Bool()
}

class RegWrite extends Bundle {         // 写回/旁路信息
  val valid = Bool()
  val rd    = UInt(5.W)
  val data  = UInt(32.W)
}

class RegFile extends Module {
  val io = IO(new Bundle {
    val rs1 = Input(UInt(5.W))
    val rs2 = Input(UInt(5.W))
    val rdata1 = Output(UInt(32.W))
    val rdata2 = Output(UInt(32.W))
    val w = Flipped(Valid(new RegWrite))  // 来自 WBU
  })
  val regs = RegInit(VecInit(Seq.fill(32)(0.U(32.W))))
  // 读（组合）；写在下个时钟沿生效
  io.rdata1 := Mux(io.rs1 === 0.U, 0.U, regs(io.rs1))
  io.rdata2 := Mux(io.rs2 === 0.U, 0.U, regs(io.rs2))
  when (io.w.valid && io.w.bits.rd =/= 0.U) {
    regs(io.w.bits.rd) := io.w.bits.data
  }
}

class IDU extends Module {
  val io = IO(new Bundle {
    val in    = Flipped(Valid(new MicroOp))   // 来自 IF/ID
    val out   = Valid(new MicroOp)            // 送往 ID/EX（带已解析的操作数）
    val op1   = Output(UInt(32.W))            // 已做旁路选择的操作数
    val op2   = Output(UInt(32.W))
    val rfRdata1 = Input(UInt(32.W))          // RF 读口
    val rfRdata2 = Input(UInt(32.W))
    val fwdEx  = Input(Valid(new RegWrite))   // EXU 旁路
    val fwdLsu = Input(Valid(new RegWrite))   // LSU 旁路
    val fwdWb  = Input(Valid(new RegWrite))   // WBU 旁路
    val inExIsLoad = Input(Bool())
    val inExRd = Input(UInt(5.W))
    val stall  = Output(Bool())               // 通知 IF/ID 停顿
  })

  // ---------- 1. 统一旁路选择：EX > LSU > WB > RF ----------
  def select(rs: UInt, rfData: UInt): UInt = {
    MuxCase(rfData, Seq(
      (io.fwdEx.valid  && io.fwdEx.bits.rd  === rs && rs =/= 0.U) -> io.fwdEx.bits.data,
      (io.fwdLsu.valid && io.fwdLsu.bits.rd === rs && rs =/= 0.U) -> io.fwdLsu.bits.data,
      (io.fwdWb.valid  && io.fwdWb.bits.rd  === rs && rs =/= 0.U) -> io.fwdWb.bits.data
    ))
  }
  io.op1 := select(io.in.bits.rs1, io.rfRdata1)
  io.op2 := select(io.in.bits.rs2, io.rfRdata2)

  // ---------- 2. load-use 冒险检测 ----------
  // 上一条是 load 且在 EX，且写口与本条源寄存器冲突 → 停顿
  val loadUse = io.in.valid && io.inExIsLoad &&
                (io.inExRd =/= 0.U) &&
                (io.inExRd === io.in.bits.rs1 || io.inExRd === io.in.bits.rs2)
  io.stall := loadUse

  // ---------- 3. 输出 ----------
  io.out.valid := io.in.valid && !loadUse
  io.out.bits  := io.in.bits
}

class EXU extends Module {
  val io = IO(new Bundle {
    val in   = Flipped(Valid(new MicroOp))
    val op1  = Input(UInt(32.W))
    val op2  = Input(UInt(32.W))
    val out  = Valid(new MicroOp)
    val result = Output(UInt(32.W))          // 供旁路
    val memAddr = Output(UInt(32.W))
  })
  io.out := io.in
  io.result := MuxLookup(io.in.bits.op, io.op1 + io.op2)(Seq(
    1.U -> (io.op1 - io.op2),
    2.U -> (io.op1 & io.op2),
    3.U -> (io.op1 | io.op2)
    // ... ALU 运算
  ))
  io.memAddr := io.op1 + io.in.bits.imm     // load/store 地址
}

class LSU extends Module {
  val io = IO(new Bundle {
    val in    = Flipped(Valid(new MicroOp))
    val addr  = Input(UInt(32.W))
    val storeData = Input(UInt(32.W))
    val loadData  = Output(UInt(32.W))
    val out   = Valid(new MicroOp)
    // 接 AXI 读通道（复用之前的仲裁器）
    val araddr  = Output(UInt(32.W))
    val arvalid = Output(Bool())
    val rdata   = Input(UInt(32.W))
    val rvalid  = Input(Bool())
  })
  // 简化：假定 AXI 读延迟一拍（rvalid 同拍或下拍返回）
  io.araddr  := io.addr
  io.arvalid := io.in.valid && io.in.bits.isLoad
  io.loadData := io.rdata
  io.out := io.in
}

class WBU extends Module {
  val io = IO(new Bundle {
    val in     = Flipped(Valid(new MicroOp))
    val aluRes = Input(UInt(32.W))
    val loadData = Input(UInt(32.W))
    val wb     = Valid(new RegWrite)        // 回 IDU 旁路 + 写 RF
  })
  io.wb.valid := io.in.valid && (io.in.bits.rd =/= 0.U)
  io.wb.bits.valid := io.wb.valid
  io.wb.bits.rd   := io.in.bits.rd
  io.wb.bits.data := Mux(io.in.bits.isLoad, io.loadData, io.aluRes)
}

class PipeTop extends Module {
  val io = IO(new Bundle {
    val ifuIn  = Flipped(Valid(new MicroOp))   // 取指输出
    val wbPeek = Valid(new RegWrite)           // 观测口
  })

  val idu = Module(new IDU)
  val exu = Module(new EXU)
  val lsu = Module(new LSU)
  val wbu = Module(new WBU)
  val rf  = Module(new RegFile)

  // ---- 流水寄存器 ----
  val idEx  = RegInit(0.U.asTypeOf(Valid(new MicroOp)))
  val exMem = RegInit(0.U.asTypeOf(Valid(new MicroOp)))
  val memWb = RegInit(0.U.asTypeOf(Valid(new MicroOp)))

  val exResult  = Reg(UInt(32.W))
  val exAddr    = Reg(UInt(32.W))
  val memLoad   = Reg(UInt(32.W))

  // ---- ID 级 ----
  idu.io.in.valid := io.ifuIn.valid
  idu.io.in.bits := io.ifuIn.bits
  idu.io.rfRdata1 := rf.io.rdata1
  idu.io.rfRdata2 := rf.io.rdata2
  rf.io.rs1 := idu.io.in.bits.rs1
  rf.io.rs2 := idu.io.in.bits.rs2

  // load-use 检测需要的"上一条是否在 EX 且为 load"
  idu.io.inExIsLoad := idEx.valid && idEx.bits.isLoad
  idu.io.inExRd     := idEx.bits.rd

  // ---- 各级旁路汇入 IDU（统一处理） ----
  idu.io.fwdEx.valid  := idEx.valid   && idEx.bits.rd =/= 0.U
  idu.io.fwdEx.bits.valid := idu.io.fwdEx.valid
  idu.io.fwdEx.bits.rd   := idEx.bits.rd
  idu.io.fwdEx.bits.data := exResult

  idu.io.fwdLsu.valid  := exMem.valid && exMem.bits.isLoad && exMem.bits.rd =/= 0.U
  idu.io.fwdLsu.bits.valid := idu.io.fwdLsu.valid
  idu.io.fwdLsu.bits.rd   := exMem.bits.rd
  idu.io.fwdLsu.bits.data := memLoad

  val wbWire = wbu.io.wb
  idu.io.fwdWb := wbWire                            // WBU 旁路

  // ---- 流水推进（含停顿） ----
  val stall = idu.io.stall
  idEx.valid  := idu.io.out.valid && !stall || stall && idEx.valid && false.B // 简化
  idEx.bits   := idu.io.out.bits
  when (stall) { idEx.valid := false.B }            // 插入气泡

  exu.io.in.valid := idEx.valid
  exu.io.in.bits := idEx.bits
  exu.io.op1 := idu.io.op1                          // 操作数随流水级寄存
  exu.io.op2 := idu.io.op2
  exResult   := exu.io.result
  exAddr     := exu.io.memAddr

  exMem := exu.io.out
  lsu.io.in.valid := exMem.valid
  lsu.io.in.bits := exMem.bits
  lsu.io.addr := exAddr
  lsu.io.storeData := 0.U
  lsu.io.rvalid := false.B
  lsu.io.rdata := 0.U
  memLoad   := lsu.io.loadData

  memWb := lsu.io.out
  wbu.io.in.valid := memWb.valid
  wbu.io.in.bits := memWb.bits
  wbu.io.aluRes   := exResult
  wbu.io.loadData := memLoad

  rf.io.w.valid := wbu.io.wb.valid
  rf.io.w.bits := wbu.io.wb.bits
  io.wbPeek.valid := wbu.io.wb.valid
  io.wbPeek.bits := wbu.io.wb.bits
}
