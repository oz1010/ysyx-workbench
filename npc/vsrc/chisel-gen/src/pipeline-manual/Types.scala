package pipeline_manual

import chisel3._
import chisel3.util._
import scala.language.reflectiveCalls
import config.AutoConfig._
import config.ManuConfig._
import pipeline_manual.Axi4MasterDefaults.apply

// 指令编码
object InstCode {
  val width = 15

  // 控制标识位定义，bit[3,0]存放操作码（若有），其他位位标识位
  val F_V    = (1 << 4).U(width.W)  // 有效指令标识
  val F_UPC  = (1 << 5).U(width.W)  // 是否使用PC标识
  val F_UIMM = (1 << 6).U(width.W)  // 是否使用立即数标识
  val F_GWEN = (1 << 7).U(width.W)  // GPR寄存器堆写使能标识
  val F_ALU  = (1 << 8).U(width.W)  // 运算操作标识
  val F_MEM  = (1 << 9).U(width.W)  // 访存操作标识
  val F_CSR  = (1 << 10).U(width.W) // CSR操作标识
  val F_WB   = (1 << 11).U(width.W) // 回写操作标识
  val F_JP   = (1 << 12).U(width.W) // 跳转操作标识
  val F_BR   = (1 << 13).U(width.W) // 分支操作标识
  val F_SYS  = (1 << 14).U(width.W) // 系统操作标识

  // 无效指令编码
  def INVALID = 0.U(width.W)

  // 各指令通过特征位组合
  def LUI     = (F_V | F_UIMM | F_GWEN)
  def AUIPC   = (F_V | F_UPC | F_UIMM | F_GWEN)
  def JAL     = (F_V | F_JP | F_GWEN | F_WB | JpOp.JAL)
  def JALR    = (F_V | F_JP | F_UIMM | F_GWEN | F_WB | JpOp.JALR)
  def BEQ     = (F_V | F_BR | BrOp.BEQ)
  def BNE     = (F_V | F_BR | BrOp.BNE)
  def BLT     = (F_V | F_BR | BrOp.BLT)
  def BGE     = (F_V | F_BR | BrOp.BGE)
  def BLTU    = (F_V | F_BR | BrOp.BLTU)
  def BGEU    = (F_V | F_BR | BrOp.BGEU)
  def LB      = (F_V | F_MEM | F_UIMM | F_GWEN | F_WB | MemOp.LB)
  def LH      = (F_V | F_MEM | F_UIMM | F_GWEN | F_WB | MemOp.LH)
  def LW      = (F_V | F_MEM | F_UIMM | F_GWEN | F_WB | MemOp.LW)
  def LBU     = (F_V | F_MEM | F_UIMM | F_GWEN | F_WB | MemOp.LBU)
  def LHU     = (F_V | F_MEM | F_UIMM | F_GWEN | F_WB | MemOp.LHU)
  def SB      = (F_V | F_MEM | F_UIMM | MemOp.SB)
  def SH      = (F_V | F_MEM | F_UIMM | MemOp.SH)
  def SW      = (F_V | F_MEM | F_UIMM | MemOp.SW)
  def ADDI    = (F_V | F_ALU | F_UIMM | F_GWEN | AluOp.ADD)
  def SLTI    = (F_V | F_ALU | F_UIMM | F_GWEN | AluOp.SLT)
  def SLTIU   = (F_V | F_ALU | F_UIMM | F_GWEN | AluOp.SLTU)
  def XORI    = (F_V | F_ALU | F_UIMM | F_GWEN | AluOp.XOR)
  def ORI     = (F_V | F_ALU | F_UIMM | F_GWEN | AluOp.OR)
  def ANDI    = (F_V | F_ALU | F_UIMM | F_GWEN | AluOp.AND)
  def SLLI    = (F_V | F_ALU | F_UIMM | F_GWEN | AluOp.SLL)
  def SRLI    = (F_V | F_ALU | F_UIMM | F_GWEN | AluOp.SRL)
  def SRAI    = (F_V | F_ALU | F_UIMM | F_GWEN | AluOp.SRA)
  def ADD     = (F_V | F_ALU | F_GWEN | AluOp.ADD)
  def SUB     = (F_V | F_ALU | F_GWEN | AluOp.SUB)
  def SLL     = (F_V | F_ALU | F_GWEN | AluOp.SLL)
  def SLT     = (F_V | F_ALU | F_GWEN | AluOp.SLT)
  def SLTU    = (F_V | F_ALU | F_GWEN | AluOp.SLTU)
  def XOR     = (F_V | F_ALU | F_GWEN | AluOp.XOR)
  def SRL     = (F_V | F_ALU | F_GWEN | AluOp.SRL)
  def SRA     = (F_V | F_ALU | F_GWEN | AluOp.SRA)
  def OR      = (F_V | F_ALU | F_GWEN | AluOp.OR)
  def AND     = (F_V | F_ALU | F_GWEN | AluOp.AND)
  def FENCE_I = (F_V | F_SYS | SysOp.FENCE_I)
  def ECALL   = (F_V | F_SYS | SysOp.ECALL)
  def EBREAK  = (F_V | F_SYS | SysOp.EBREAK)
  def CSRRW   = (F_V | F_CSR | F_GWEN | F_WB | CsrOp.RW)
  def CSRRS   = (F_V | F_CSR | F_GWEN | F_WB | CsrOp.RS)
  def MRET    = (F_V | F_SYS | SysOp.MRET)

  def apply(): UInt = UInt(width.W)

  def decode(inst: UInt): UInt = {
    val code            = Lookup(
      inst,
      INVALID,
      Seq(
        BitPat("b???????_?????_?????_???_?????_01101_11") -> LUI,
        BitPat("b???????_?????_?????_???_?????_00101_11") -> AUIPC,
        BitPat("b???????_?????_?????_???_?????_11011_11") -> JAL,
        BitPat("b???????_?????_?????_000_?????_11001_11") -> JALR,
        BitPat("b???????_?????_?????_000_?????_11000_11") -> BEQ,
        BitPat("b???????_?????_?????_001_?????_11000_11") -> BNE,
        BitPat("b???????_?????_?????_100_?????_11000_11") -> BLT,
        BitPat("b???????_?????_?????_101_?????_11000_11") -> BGE,
        BitPat("b???????_?????_?????_110_?????_11000_11") -> BLTU,
        BitPat("b???????_?????_?????_111_?????_11000_11") -> BGEU,
        BitPat("b???????_?????_?????_000_?????_00000_11") -> LB,
        BitPat("b???????_?????_?????_001_?????_00000_11") -> LH,
        BitPat("b???????_?????_?????_010_?????_00000_11") -> LW,
        BitPat("b???????_?????_?????_100_?????_00000_11") -> LBU,
        BitPat("b???????_?????_?????_101_?????_00000_11") -> LHU,
        BitPat("b???????_?????_?????_000_?????_01000_11") -> SB,
        BitPat("b???????_?????_?????_001_?????_01000_11") -> SH,
        BitPat("b???????_?????_?????_010_?????_01000_11") -> SW,
        BitPat("b???????_?????_?????_000_?????_00100_11") -> ADDI,
        BitPat("b???????_?????_?????_010_?????_00100_11") -> SLTI,
        BitPat("b???????_?????_?????_011_?????_00100_11") -> SLTIU,
        BitPat("b???????_?????_?????_100_?????_00100_11") -> XORI,
        BitPat("b???????_?????_?????_110_?????_00100_11") -> ORI,
        BitPat("b???????_?????_?????_111_?????_00100_11") -> ANDI,
        BitPat("b0000000_?????_?????_001_?????_00100_11") -> SLLI,
        BitPat("b0000000_?????_?????_101_?????_00100_11") -> SRLI,
        BitPat("b0100000_?????_?????_101_?????_00100_11") -> SRAI,
        BitPat("b0000000_?????_?????_000_?????_01100_11") -> ADD,
        BitPat("b0100000_?????_?????_000_?????_01100_11") -> SUB,
        BitPat("b0000000_?????_?????_001_?????_01100_11") -> SLL,
        BitPat("b0000000_?????_?????_010_?????_01100_11") -> SLT,
        BitPat("b0000000_?????_?????_011_?????_01100_11") -> SLTU,
        BitPat("b0000000_?????_?????_100_?????_01100_11") -> XOR,
        BitPat("b0000000_?????_?????_101_?????_01100_11") -> SRL,
        BitPat("b0100000_?????_?????_101_?????_01100_11") -> SRA,
        BitPat("b0000000_?????_?????_110_?????_01100_11") -> OR,
        BitPat("b0000000_?????_?????_111_?????_01100_11") -> AND,
        BitPat("b???????_?????_?????_001_?????_00011_11") -> FENCE_I,
        BitPat("b0000000_00000_?????_000_?????_11100_11") -> ECALL,
        BitPat("b0000000_00001_?????_000_?????_11100_11") -> EBREAK,
        BitPat("b???????_?????_?????_001_?????_11100_11") -> CSRRW,
        BitPat("b???????_?????_?????_010_?????_11100_11") -> CSRRS,
        // Privileged Instructions ref. RISC-V开放架构设计之道-V1.0.0 p101
        BitPat("b0011000_00010_?????_000_?????_11100_11") -> MRET
      )
    )
    // 宽松译码fence_i ecall ebreak mret后，必须做保留字段0的检查
    val fence_i_illegal =
      (code === FENCE_I) && (inst(19, 15).orR || inst(11, 7).orR || inst(
        31,
        20
      ).orR)
    val ecall_illegal   =
      (code === ECALL) && (inst(19, 15).orR || inst(11, 7).orR)
    val ebreak_illegal  =
      (code === EBREAK) && (inst(19, 15).orR || inst(11, 7).orR)
    val mret_illegal    = (code === MRET) && (inst(19, 15).orR || inst(11, 7).orR)

    Mux(
      fence_i_illegal ||
        ecall_illegal ||
        ebreak_illegal ||
        mret_illegal,
      INVALID,
      code
    )
  }
}

// 异常码
object ExptCode {
  val width         = 32.W
  val INST_ILLEGAL  = 2.U(width)
  val INST_ECALL    = 11.U(width)
  val INST_EBREAK   = 3.U(width)
  val FETCH_MISS    = 0.U(width)
  val FETCH_ACCESS  = 1.U(width)
  val LOAD_MISS     = 4.U(width)
  val LOAD_ACCESS   = 5.U(width)
  val STORE_MISS    = 6.U(width)
  val STORE_ACCESS  = 7.U(width)

  def apply(): UInt = UInt(width)
}

// 计算操作码，0 add 1 sub 2 and 3 or 4 xor 5 sll 6 srl 7 sra 8 slt 9 sltu
object AluOp {
  val width = 4
  val ADD   = 0.U(width.W)
  val SUB   = 1.U(width.W)
  val AND   = 2.U(width.W)
  val OR    = 3.U(width.W)
  val XOR   = 4.U(width.W)
  val SLL   = 5.U(width.W)
  val SRL   = 6.U(width.W)
  val SRA   = 7.U(width.W)
  val SLT   = 8.U(width.W)
  val SLTU  = 9.U(width.W)

  def apply(): UInt = UInt(width.W)
}
// 访存操作码
object MemOp {
  val width      = 4
  val FLAG_WRITE = (0b1000).U(width.W) // 写入标记
  val FLAG_UNSIG = (0b0100).U(width.W) // 无符号标记
  val FLAG_1B    = (0b0000).U(width.W) // 1字节标记
  val FLAG_2B    = (0b0001).U(width.W) // 2字节标记
  val FLAG_4B    = (0b0010).U(width.W) // 4字节标记
  def LB         = (FLAG_1B)
  def LH         = (FLAG_2B)
  def LW         = (FLAG_4B)
  def LBU        = (FLAG_1B | FLAG_UNSIG)
  def LHU        = (FLAG_2B | FLAG_UNSIG)
  def SB         = (FLAG_1B | FLAG_WRITE)
  def SH         = (FLAG_2B | FLAG_WRITE)
  def SW         = (FLAG_4B | FLAG_WRITE)

  def apply(): UInt = UInt(width.W)
}
// 控制寄存器操作码，0 无 1 RW 2 RS 3 RC
object CsrOp {
  val width = 2
  val RW    = 0.U(width.W)
  val RS    = 1.U(width.W)
  val RC    = 2.U(width.W)

  def apply(): UInt = UInt(width.W)
}
// 回写操作码，0:ALU 1:Load 2:CSR 3:PC+4
object WbOp  {
  val width = 2
  val ALU   = 0.U(width.W)
  val LOAD  = 1.U(width.W)
  val CSR   = 2.U(width.W)
  val PC_4  = 3.U(width.W)

  def apply(): UInt = UInt(width.W)
}
// 跳转操作码
object JpOp  {
  val width = 1
  val JAL   = 0.U(width.W)
  val JALR  = 1.U(width.W)

  def apply(): UInt = UInt(width.W)
}
// 分支操作码
object BrOp  {
  val width = 3
  val BEQ   = 0.U(width.W)
  val BNE   = 1.U(width.W)
  val BLT   = 2.U(width.W)
  val BGE   = 3.U(width.W)
  val BLTU  = 4.U(width.W)
  val BGEU  = 5.U(width.W)

  def apply(): UInt = UInt(width.W)
}
// 系统操作码
object SysOp {
  val width   = 2
  val FENCE_I = 0.U(width.W)
  val ECALL   = 1.U(width.W)
  val EBREAK  = 2.U(width.W)
  val MRET    = 3.U(width.W)

  def apply(): UInt = UInt(width.W)
}

// axi4编号
object Axi4ID extends ChiselEnum {
  val IFU, IDU, EXU, LSU, WBU, ICACHE, DCACHE = Value
}

// CSR地址
object CSRAddr {
  val width     = 12.W
  val MSTATUS   = 0x300.U(width) // mstatus寄存器 - 存放处理器的状态
  val MTVEC     = 0x305.U(width) // mtvec寄存器 - 存放trap-handler基地址
  val MEPC      = 0x341.U(width) // mepc寄存器 - 存放触发异常的PC
  val MCAUSE    = 0x342.U(width) // mcause寄存器 - 存放触发异常的原因
  val MTVAL     = 0x343.U(width) // mtval寄存器 - 存放触发异常的辅助值
  val MVENDORID = 0xf11.U(width) // Vendor ID, ysyx的ASCII码, 即0x79737978
  val MARCHID   =
    0xf12.U(width) // Architecture ID, 学号数字部分（23060295）的十进制表示，即0x15FDF47
}

/** 仅实现 M 模式：MPP 固定为 M，MIE/MPIE 随陷阱和返回更新。 */
object CsrStatus {
  private val mask = BigInt("ffffe7ff", 16)
  def normalize(status: UInt): UInt = (status & mask.U(32.W)) | "h1800".U
  def enter(status: UInt): UInt =
    normalize((status & "hffffff77".U(32.W)) | (status(3).asUInt << 7))
  def leave(status: UInt): UInt =
    normalize((status & "hffffff77".U(32.W)) | (status(7).asUInt << 3) | "h80".U)
}

/** 重定向数据（冲刷流水线并修改取指 PC） */
class Redirect() extends Bundle {
  val valid  = Bool()
  val target = UInt(CONFIG_ADDR_WIDTH.W)
}

/** AXI4通道数据 Master视角
  *
  * burst类型，0--FIXED 1--INCR 2--WRAP
  */
class Axi4IO() extends Bundle {
  // 读地址通道
  val arvalid = Output(Bool())
  val arready = Input(Bool())
  val araddr  = Output(UInt(CONFIG_ADDR_WIDTH.W))
  val arid    = Output(UInt(4.W))
  val arlen   = Output(UInt(8.W)) // burst数量，2^n字节
  val arsize  = Output(UInt(3.W)) // 单个burst数据大小，2^n字节
  val arburst = Output(UInt(2.W))
  // 读数据通道
  val rvalid  = Input(Bool())
  val rready  = Output(Bool())
  val rdata   = Input(UInt(CONFIG_DATA_WIDTH.W))
  val rresp   = Input(UInt(2.W))
  val rlast   = Input(Bool())
  val rid     = Input(UInt(4.W))
  // 写地址通道
  val awvalid = Output(Bool())
  val awready = Input(Bool())
  val awaddr  = Output(UInt(CONFIG_ADDR_WIDTH.W))
  val awid    = Output(UInt(4.W))
  val awlen   = Output(UInt(8.W)) // burst数量，2^n字节
  val awsize  = Output(UInt(3.W)) // 单个burst数据大小，2^n字节
  val awburst = Output(UInt(2.W))
  // 写数据通道
  val wvalid  = Output(Bool())
  val wready  = Input(Bool())
  val wdata   = Output(UInt(CONFIG_DATA_WIDTH.W))
  val wstrb   = Output(UInt((CONFIG_DATA_WIDTH / 8).W))
  val wlast   = Output(Bool())
  // 写响应通道
  val bvalid  = Input(Bool())
  val bready  = Output(Bool())
  val bresp   = Input(UInt(2.W))
  val bid     = Input(UInt(4.W))

  // 读地址通道握手判定
  def arFire: Bool = arvalid && arready
  // 读数据通道握手判定
  def rFire: Bool  = rvalid && rready
  // 写地址通道握手判定
  def awFire: Bool = awvalid && awready
  // 写数据通道握手判定
  def wFire: Bool  = wvalid && wready
  // 写响应通道握手判定
  def bFire: Bool  = bvalid && bready
}
// axi4-master默认赋值函数
object Axi4MasterDefaults {
  def apply(io: Axi4IO): Unit = {
    io.arvalid := false.B
    io.araddr  := 0.U
    io.arid    := 0.U
    io.arlen   := 0.U
    io.arsize  := 0.U
    io.arburst := 0.U
    io.rready  := false.B

    io.awvalid := false.B
    io.awaddr  := 0.U
    io.awid    := 0.U
    io.awlen   := 0.U
    io.awsize  := 0.U
    io.awburst := 0.U
    io.wvalid  := false.B
    io.wdata   := 0.U
    io.wstrb   := 0.U
    io.wlast   := false.B
    io.bready  := false.B
  }
}
// axi4-slave默认赋值函数
object Axi4SlaveDefaults {
  def apply(io: Axi4IO): Unit = {
    io.arready := false.B
    io.rvalid  := false.B
    io.rdata   := 0.U
    io.rresp   := 0.U
    io.rlast   := false.B
    io.rid     := 0.U

    io.awready := false.B
    io.wready  := false.B
    io.bvalid  := false.B
    io.bresp   := 0.U
    io.bid     := 0.U
  }
}

class CacheReqIO extends Bundle {
  val valid = Output(Bool())
  val ready = Input(Bool())
  val addr  = Output(UInt(CONFIG_ADDR_WIDTH.W))
  val op    = Output(UInt(MemOp.width.W))
  val wdata = Output(UInt(CONFIG_DATA_WIDTH.W))

  def fire: Bool = valid && ready
}

object CacheStat {
  val NONE = 0.U(2.W)
  val HIT  = 1.U(2.W)
  val MISS = 2.U(2.W)
}

/** Cache数据，master视角 */
class CacheIO extends Bundle {
  val req = new CacheReqIO()
  val rsp = new Bundle {
    val valid = Input(Bool())
    val ready = Output(Bool())
    val data  = Input(UInt(CONFIG_DATA_WIDTH.W))
    val error = Input(Bool())

    def fire: Bool = valid && ready
  }
}
object CacheIOMasterDefaults {
  def apply(io: CacheIO): Unit = {
    io.req.valid := false.B
    io.req.addr  := 0.U
    io.req.op    := 0.U
    io.req.wdata := 0.U
    io.rsp.ready := false.B
  }
}
object CacheIOSlaveDefaults {
  def apply(io: CacheIO): Unit = {
    io.req.ready := false.B
    io.rsp.valid := false.B
    io.rsp.data  := 0.U
    io.rsp.error := false.B
  }
}

/* ================= 流水线级间寄存器 ================= */

/** 控制信号（ID 级译码产生，随流水线传递） */
class Ctrl extends Bundle {
  val code  = InstCode()
  val aluOp = AluOp()
  val memOp = MemOp()
  val wbOp  = WbOp()
  val csrOp = CsrOp()
  val jpOp  = JpOp()
  val brOp  = BrOp()
  val sysOp = SysOp()

  // 布尔函数直接判断对应标识位是否存在（按位与结果不为 0）
  def isValid: Bool   = (code & InstCode.F_V) =/= 0.U
  def isIllegal: Bool = !isValid
  def isLoad: Bool    = isMemOp && isWbOp
  def isStore: Bool   = isMemOp && !isWbOp
  def isUsePc: Bool   = (code & InstCode.F_UPC) =/= 0.U
  def isUseImm: Bool  = (code & InstCode.F_UIMM) =/= 0.U
  def isRdWen: Bool   = (code & InstCode.F_GWEN) =/= 0.U
  def isAluOp: Bool   = (code & InstCode.F_ALU) =/= 0.U
  def isMemOp: Bool   = (code & InstCode.F_MEM) =/= 0.U
  def isWbOp: Bool    = (code & InstCode.F_WB) =/= 0.U
  def isCsrOp: Bool   = (code & InstCode.F_CSR) =/= 0.U
  def isJpOp: Bool    = (code & InstCode.F_JP) =/= 0.U
  def isBrOp: Bool    = (code & InstCode.F_BR) =/= 0.U
  def isSysOp: Bool   = (code & InstCode.F_SYS) =/= 0.U
  def isJalr: Bool    = isJpOp && jpOp === JpOp.JALR
  def isJal: Bool     = isJpOp && jpOp === JpOp.JAL
  def isEcall: Bool   = isSysOp && sysOp === SysOp.ECALL
  def isEbreak: Bool  = isSysOp && sysOp === SysOp.EBREAK
  def isMret: Bool    = isSysOp && sysOp === SysOp.MRET
  def isFenceI: Bool  = isSysOp && sysOp === SysOp.FENCE_I
  def isCsrImm: Bool  = false.B // 暂时没有实现 CSRRWI CSRRSI CSRRCI
}

object Ctrl {
  def decode(inst: UInt): Ctrl = {
    val ctrl = Wire(new Ctrl)
    val code = InstCode.decode(inst)
    ctrl.code  := code
    // 低位只保存所属类别的操作码；写回类型由特征位独立生成。
    ctrl.aluOp := Mux(ctrl.isAluOp, code(AluOp.width - 1, 0), AluOp.ADD)
    ctrl.memOp := code(MemOp.width - 1, 0)
    ctrl.wbOp  := MuxCase(
      WbOp.ALU,
      Seq(
        ctrl.isLoad  -> WbOp.LOAD,
        ctrl.isCsrOp -> WbOp.CSR,
        ctrl.isJpOp  -> WbOp.PC_4
      )
    )
    ctrl.csrOp := code(CsrOp.width - 1, 0)
    ctrl.jpOp  := code(JpOp.width - 1, 0)
    ctrl.brOp  := code(BrOp.width - 1, 0)
    ctrl.sysOp := code(SysOp.width - 1, 0)

    ctrl
  }
}

/** 异常接口，主要应用于流水线 */
class Expt() extends Bundle {
  val en    = Bool()
  // val epc   = UInt(CONFIG_ADDR_WIDTH.W) // 不需要传递，流水线有值
  val cause = UInt(CONFIG_ADDR_WIDTH.W)
  val tval  = UInt(CONFIG_ADDR_WIDTH.W)
}
object ExptDefaults {
  def apply(io: Expt): Unit = {
    io.en    := false.B
    io.cause := 0.U
    io.tval  := 0.U
  }
}

/** IF数据 */
class IfBundle() extends Bundle {
  val pc         = UInt(CONFIG_ADDR_WIDTH.W)
  val inst       = UInt(CONFIG_ADDR_WIDTH.W)
  val predTaken  = Bool()                    // 静态分支预测：是否预测跳转
  val predTarget = UInt(CONFIG_ADDR_WIDTH.W) // 预测目标
  val expt       = new Expt
}

/** ID数据 */
class IdBundle() extends Bundle {
  val pc         = UInt(CONFIG_ADDR_WIDTH.W)
  val inst       = UInt(CONFIG_ADDR_WIDTH.W)
  val rs1Val     = UInt(CONFIG_ADDR_WIDTH.W)
  val rs2Val     = UInt(CONFIG_ADDR_WIDTH.W)
  val imm        = UInt(CONFIG_ADDR_WIDTH.W)
  val rs1Addr    = UInt(4.W) // RV32E：4bit 寄存器号
  val rs2Addr    = UInt(4.W)
  val rdAddr     = UInt(4.W)
  val ctrl       = new Ctrl
  val predTaken  = Bool()
  val predTarget = UInt(CONFIG_ADDR_WIDTH.W)
  val expt       = new Expt
}

/** EX数据 */
class ExBundle() extends Bundle {
  val pc        = UInt(CONFIG_ADDR_WIDTH.W)
  val dnpc      = UInt(CONFIG_ADDR_WIDTH.W)
  val aluResult = UInt(CONFIG_ADDR_WIDTH.W)
  val storeData = UInt(CONFIG_ADDR_WIDTH.W)
  val rdAddr    = UInt(4.W)
  val ctrl      = new Ctrl
  val csrAddr   = UInt(CSR_ADDR_W.W)
  val csrWdata  = UInt(CONFIG_ADDR_WIDTH.W)
  val csrRdata  = UInt(CONFIG_ADDR_WIDTH.W)
  val expt      = new Expt
}

/** LS数据 */
class LsBundle() extends Bundle {
  val pc        = UInt(CONFIG_ADDR_WIDTH.W)
  val dnpc      = UInt(CONFIG_ADDR_WIDTH.W)
  val aluResult = UInt(CONFIG_ADDR_WIDTH.W)
  val loadData  = UInt(CONFIG_ADDR_WIDTH.W)
  val rdAddr    = UInt(4.W)
  val ctrl      = new Ctrl
  val csrAddr   = UInt(CSR_ADDR_W.W)
  val csrWdata  = UInt(CONFIG_ADDR_WIDTH.W)
  val csrRdata  = UInt(CONFIG_ADDR_WIDTH.W)
  val expt      = new Expt
}

/** WB数据 */
class WbBundle() extends Bundle {
  val pc   = UInt(CONFIG_ADDR_WIDTH.W)
  val dnpc = UInt(CONFIG_ADDR_WIDTH.W)
}

/** 寄存器读写取接口，master视角，支持GPR CSR */
class RegReadIO(ADDR_WIDTH: Int, DATA_WIDTH: Int)  extends Bundle {
  val en   = Output(Bool())
  val addr = Output(UInt(ADDR_WIDTH.W))
  val data = Input(UInt(DATA_WIDTH.W))
}
class RegWriteIO(ADDR_WIDTH: Int, DATA_WIDTH: Int) extends Bundle {
  val wen   = Output(Bool())
  val waddr = Output(UInt(ADDR_WIDTH.W))
  val wdata = Output(UInt(DATA_WIDTH.W))
}
object RegWriteIODefaults {
  def apply(io: RegWriteIO): Unit = {
    io.wen   := false.B
    io.waddr := 0.U
    io.wdata := 0.U
  }
}

/** 陷阱接口，支持异常（同步）和中断（异步），master视角 */
class TrapIO() extends Bundle {
  val en     = Output(Bool())
  val epc    = Output(UInt(CONFIG_ADDR_WIDTH.W))
  val cause  = Output(UInt(CONFIG_ADDR_WIDTH.W))
  val tval   = Output(UInt(CONFIG_ADDR_WIDTH.W))
  val status = Output(UInt(CONFIG_ADDR_WIDTH.W))
}
// 陷阱接口，支持异常（同步）和中断（异步）
object TrapIODefaults {
  def apply(io: TrapIO): Unit = {
    io.en     := false.B
    io.epc    := 0.U
    io.cause  := 0.U
    io.tval   := 0.U
    io.status := 0.U
  }
}
