package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._
import pipeline_manual.Axi4MasterDefaults.apply

/** 指令测试码 */
object InstCodeTest {
  // 以下数值仅为示例。
  val INVALID = 0.U(8.W)
  val LUI     = 1.U(8.W)
}

// 异常码
object ExceptCode {
  val width        = 32.W
  val INST_ILLEGAL = 2.U(width)
  val INST_ECALL   = 11.U(width)
  val INST_EBREAK  = 3.U(width)
  val FETCH_MISS   = 0.U(width)
  val LOAD_MISS    = 4.U(width)
  val STORE_MISS   = 6.U(width)

  def apply(): UInt = UInt(width)
}

// 计算操作码，0 add 1 sub 2 and 3 or 4 xor 5 sll 6 srl 7 sra 8 slt 9 sltu
object AluOp {
  val width = 4.W
  val ADD   = 0.U(width)
  val SUB   = 1.U(width)
  val AND   = 2.U(width)
  val OR    = 3.U(width)
  val XOR   = 4.U(width)
  val SLL   = 5.U(width)
  val SRL   = 6.U(width)
  val SRA   = 7.U(width)
  val SLT   = 8.U(width)
  val SLTU  = 9.U(width)

  def apply(): UInt = UInt(width)
}

// 存储操作码，funct3：lb/lh/lw/lbu/lhu、sb/sh/sw
object OldMemOp {
  val width = 3.W
  val LB    = 0.U(width)
  val LH    = 1.U(width)
  val LW    = 2.U(width)
  val LBU   = 4.U(width)
  val LHU   = 5.U(width)
  val SB    = 0.U(width)
  val SH    = 1.U(width)
  val SW    = 2.U(width)

  def apply(): UInt = UInt(width)
}

// 回写动作码，0:ALU 1:Load 2:CSR 3:PC+4
object WbSel {
  val width = 2.W
  val ALU   = 0.U(width)
  val LOAD  = 1.U(width)
  val CSR   = 2.U(width)
  val PC_4  = 3.U(width)

  def apply(): UInt = UInt(width)
}

// 回写操作码，0:ALU 1:Load 2:CSR 3:PC+4
object WbOp {
  val width = 2.W
  val ALU   = 0.U(width)
  val LOAD  = 1.U(width)
  val CSR   = 2.U(width)
  val PC_4  = 3.U(width)

  def apply(): UInt = UInt(width)
}

// 控制寄存器操作码，0 无 1 RW 2 RS 3 RC
object CsrOp {
  val width = 2.W
  val NONE  = 0.U(width)
  val RW    = 1.U(width)
  val RS    = 2.U(width)
  val RC    = 3.U(width)

  def apply(): UInt = UInt(width)
}

// axi4编号
object Axi4ID extends ChiselEnum {
  val IFU, IDU, EXU, LSU, WBU, ICACHE, DCACHE = Value
}

// 新访存操作码
object MemOp {
  val width      = 4.W
  val FLAG_WRITE = 0b1000.U(width) // 写入标记
  val FLAG_UNSIG = 0b0100.U(width) // 无符号标记
  val FLAG_1B    = 0b0000.U(width) // 1字节标记
  val FLAG_2B    = 0b0001.U(width) // 2字节标记
  val FLAG_4B    = 0b0010.U(width) // 4字节标记
  val LB         = (FLAG_1B)
  val LH         = (FLAG_2B)
  val LW         = (FLAG_4B)
  val LBU        = (FLAG_1B | FLAG_UNSIG)
  val LHU        = (FLAG_2B | FLAG_UNSIG)
  val SB         = (FLAG_1B | FLAG_WRITE)
  val SH         = (FLAG_2B | FLAG_WRITE)
  val SW         = (FLAG_4B | FLAG_WRITE)
  val NONE       = 0b1111.U(width) // 无效标记

  def apply(): UInt = UInt(width)
}

// CSR地址
object CSRAddr {
  val width     = 12.W
  // 编号从1开始
  val MSTATUS   = 0x300.U(width) // mstatus寄存器 - 存放处理器的状态
  val MTVEC     = 0x305.U(width) // mtvec寄存器 - 存放trap-handler基地址
  val MEPC      = 0x341.U(width) // mepc寄存器 - 存放触发异常的PC
  val MCAUSE    = 0x342.U(width) // mcause寄存器 - 存放触发异常的原因
  val MTVAL     = 0x343.U(width) // mtval寄存器 - 存放触发异常的辅助值
  val MVENDORID = 0xf11.U(width) // Vendor ID, ysyx的ASCII码, 即0x79737978
  val MARCHID   =
    0xf12.U(width) // Architecture ID, 学号数字部分（23060295）的十进制表示，即0x15FDF47
}

// 指令编码
object Code {
  val width = 18

  // 1. 控制标识位定义
  val F_INV     = (1 << 4)  // 无效指令标识
  val F_JAL     = (1 << 5)  // JAL 标识
  val F_JALR    = (1 << 6)  // JALR 标识
  val F_BRANCH  = (1 << 7)  // 分支指令标识
  val F_LOAD    = (1 << 8)  // Load 标识
  val F_STORE   = (1 << 9)  // Store 标识
  val F_FENCE   = (1 << 10) // FENCE 标识
  val F_ECALL   = (1 << 11) // ECALL 标识
  val F_EBREAK  = (1 << 12) // EBREAK 标识
  val F_MRET    = (1 << 13) // MRET 标识
  val F_USE_PC  = (1 << 14) // 是否使用 PC
  val F_USE_IMM = (1 << 15) // 是否使用立即数
  val F_RD_WEN  = (1 << 16) // 寄存器堆写使能
  val F_CSR_IMM = (1 << 17) // CSR 立即数标识

  // 2. 无效指令编码
  val INVALID = (F_INV | 0).U(width.W)

  // 3. 各指令通过特征位组合
  val LUI     = (F_USE_IMM | F_RD_WEN | 0).U(width.W)
  val AUIPC   = (F_USE_PC | F_USE_IMM | F_RD_WEN | 0).U(width.W)
  val JAL     = (F_JAL | F_RD_WEN | 0).U(width.W)
  val JALR    = (F_JALR | F_USE_IMM | F_RD_WEN | 0).U(width.W)
  val BEQ     = (F_BRANCH | 0).U(width.W)
  val BNE     = (F_BRANCH | 1).U(width.W)
  val BLT     = (F_BRANCH | 2).U(width.W)
  val BGE     = (F_BRANCH | 3).U(width.W)
  val BLTU    = (F_BRANCH | 4).U(width.W)
  val BGEU    = (F_BRANCH | 5).U(width.W)
  val LB      = (F_LOAD | F_USE_IMM | F_RD_WEN | 0).U(width.W)
  val LH      = (F_LOAD | F_USE_IMM | F_RD_WEN | 1).U(width.W)
  val LW      = (F_LOAD | F_USE_IMM | F_RD_WEN | 2).U(width.W)
  val LBU     = (F_LOAD | F_USE_IMM | F_RD_WEN | 3).U(width.W)
  val LHU     = (F_LOAD | F_USE_IMM | F_RD_WEN | 4).U(width.W)
  val SB      = (F_STORE | F_USE_IMM | 0).U(width.W)
  val SH      = (F_STORE | F_USE_IMM | 1).U(width.W)
  val SW      = (F_STORE | F_USE_IMM | 2).U(width.W)
  val ADDI    = (F_USE_IMM | F_RD_WEN | 1).U(width.W)
  val SLTI    = (F_USE_IMM | F_RD_WEN | 2).U(width.W)
  val SLTIU   = (F_USE_IMM | F_RD_WEN | 3).U(width.W)
  val XORI    = (F_USE_IMM | F_RD_WEN | 4).U(width.W)
  val ORI     = (F_USE_IMM | F_RD_WEN | 5).U(width.W)
  val ANDI    = (F_USE_IMM | F_RD_WEN | 6).U(width.W)
  val SLLI    = (F_USE_IMM | F_RD_WEN | 7).U(width.W)
  val SRLI    = (F_USE_IMM | F_RD_WEN | 8).U(width.W)
  val SRAI    = (F_USE_IMM | F_RD_WEN | 9).U(width.W)
  val ADD     = (F_RD_WEN | 0).U(width.W)
  val SUB     = (F_RD_WEN | 1).U(width.W)
  val SLL     = (F_RD_WEN | 2).U(width.W)
  val SLT     = (F_RD_WEN | 3).U(width.W)
  val SLTU    = (F_RD_WEN | 4).U(width.W)
  val XOR     = (F_RD_WEN | 5).U(width.W)
  val SRL     = (F_RD_WEN | 6).U(width.W)
  val SRA     = (F_RD_WEN | 7).U(width.W)
  val OR      = (F_RD_WEN | 8).U(width.W)
  val AND     = (F_RD_WEN | 9).U(width.W)
  val FENCE_I = (F_FENCE | 0).U(width.W)
  val ECALL   = (F_ECALL | 0).U(width.W)
  val EBREAK  = (F_EBREAK | 0).U(width.W)
  val CSRRW   = (F_RD_WEN | 10).U(width.W)
  val CSRRS   = (F_RD_WEN | 11).U(width.W)
  val MRET    = (F_MRET | 0).U(width.W)

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

/** 重定向数据（冲刷流水线并修改取指 PC） */
class Redirect(p: CoreParams) extends Bundle {
  val valid  = Bool()
  val target = UInt(CONFIG_ADDR_WIDTH.W)
}

/** AXI4通道数据 Master视角
  *
  * burst类型，0--FIXED 1--INCR 2--WRAP
  */
class Axi4IO()                 extends Bundle {
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
class OldAxi4IO(p: CoreParams) extends Bundle {
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
object OldAxi4MasterDefaults {
  def apply(io: OldAxi4IO): Unit = {
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
object OldAxi4SlaveDefaults {
  def apply(io: OldAxi4IO): Unit = {
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

/** Cache数据，master视角 */
class OldCacheIO(p: CoreParams) extends Bundle {
  val req = new Bundle {
    val valid   = Output(Bool())
    val ready   = Input(Bool())
    val addr    = Output(UInt(CONFIG_ADDR_WIDTH.W))
    val wdata   = Output(UInt(CONFIG_DATA_WIDTH.W))
    val wstrb   = Output(UInt((CONFIG_DATA_WIDTH / 8).W))
    val iswrite = Output(Bool())
  }
  val rsp = new Bundle {
    val valid = Input(Bool())
    val data  = Input(UInt(CONFIG_DATA_WIDTH.W))
  }
}
class CacheIO                   extends Bundle {
  val req = new Bundle {
    val valid = Output(Bool())
    val ready = Input(Bool())
    val addr  = Output(UInt(CONFIG_ADDR_WIDTH.W))
    val op    = Output(UInt(MemOp.width))
    val wdata = Output(UInt(CONFIG_DATA_WIDTH.W))

    def fire: Bool = valid && ready
  }
  val rsp = new Bundle {
    val valid = Input(Bool())
    val ready = Output(Bool())
    val data  = Input(UInt(CONFIG_DATA_WIDTH.W))

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
  }
}

/** Cache refill（读行）数据，master视角 */
class CacheRefillIO(p: CoreParams) extends Bundle {
  val req = new Bundle {
    val valid = Output(Bool())
    val addr  = Output(UInt(CONFIG_ADDR_WIDTH.W)) // 行基地址
  }
  val gnt = Input(Bool()) // 仲裁器接受本次行读请求
  val rsp = new Bundle {
    val valid = Input(Bool())
    val data  = Input(UInt(CONFIG_DATA_WIDTH.W))
    val last  = Input(Bool())
  }
}

// /** 仲裁器侧的 refill 从机视角（req 输入，gnt/rsp 输出） */
// class RefillSlaveIO(p: CoreParams) extends Bundle {
//   val req = new Bundle {
//     val valid = Input(Bool())
//     val addr  = Input(UInt(CONFIG_ADDR_WIDTH.W))
//   }
//   val gnt  = Output(Bool())
//   val rsp = new Bundle {
//     val valid = Output(Bool())
//     val data  = Output(UInt(CONFIG_DATA_WIDTH.W))
//     val last  = Output(Bool())
//   }
// }

// /** Store Buffer 条目 */
// class StoreReq(p: CoreParams) extends Bundle {
//   val addr = UInt(CONFIG_ADDR_WIDTH.W)
//   val data = UInt(CONFIG_DATA_WIDTH.W)
//   val strb = UInt((CONFIG_DATA_WIDTH / 8).W)
// }

/* ================= 流水线级间寄存器 ================= */

/** 控制信号（ID 级译码产生，随流水线传递） */
class OldCtrl extends Bundle {
  val aluOp = UInt(
    4.W
  ) // 0 add 1 sub 2 and 3 or 4 xor 5 sll 6 srl 7 sra 8 slt 9 sltu
  val usePc    = Bool()    // 操作数 A 选择 PC（AUIPC）
  val useImm   = Bool()    // 操作数 B 选择立即数
  val isBranch = Bool()
  val isJal    = Bool()
  val isJalr   = Bool()
  val load     = Bool()
  val store    = Bool()
  val memOp    = UInt(3.W) // funct3：lb/lh/lw/lbu/lhu、sb/sh/sw
  val wbSel    = UInt(2.W) // 0:ALU 1:Load 2:CSR 3:PC+4
  val rdWen    = Bool()
  val csrOp    = UInt(2.W) // 0 无 1 RW 2 RS 3 RC
  val csrImm   = Bool()    // CSR 立即数形式
  val fence    = Bool()    // 作为 NOP
  val ecall    = Bool()
  val ebreak   = Bool()
  val mret     = Bool()
  val illegal  = Bool()
}
class Ctrl    extends Bundle {
  val code  = Code()
  val aluOp = AluOp()
  val memOp = MemOp()
  val wbOp  = WbOp()
  val csrOp = CsrOp()

  // 布尔函数直接判断对应标识位是否存在（按位与结果不为 0）
  def isInvalid: Bool = (code & Code.F_INV.U) =/= 0.U
  def isJal: Bool     = (code & Code.F_JAL.U) =/= 0.U
  def isJalr: Bool    = (code & Code.F_JALR.U) =/= 0.U
  def isBranch: Bool  = (code & Code.F_BRANCH.U) =/= 0.U
  def isLoad: Bool    = (code & Code.F_LOAD.U) =/= 0.U
  def isStore: Bool   = (code & Code.F_STORE.U) =/= 0.U
  def isFence: Bool   = (code & Code.F_FENCE.U) =/= 0.U
  def isEcall: Bool   = (code & Code.F_ECALL.U) =/= 0.U
  def isEbreak: Bool  = (code & Code.F_EBREAK.U) =/= 0.U
  def isMret: Bool    = (code & Code.F_MRET.U) =/= 0.U
  def isUsePc: Bool   = (code & Code.F_USE_PC.U) =/= 0.U
  def isUseImm: Bool  = (code & Code.F_USE_IMM.U) =/= 0.U
  def isRdWen: Bool   = (code & Code.F_RD_WEN.U) =/= 0.U
  def isCsrImm: Bool  = (code & Code.F_CSR_IMM.U) =/= 0.U
}

/** IF数据 */
class IfBundle(p: CoreParams) extends Bundle {
  val pc         = UInt(CONFIG_ADDR_WIDTH.W)
  val inst       = UInt(CONFIG_ADDR_WIDTH.W)
  val predTaken  = Bool()                    // 静态分支预测：是否预测跳转
  val predTarget = UInt(CONFIG_ADDR_WIDTH.W) // 预测目标
}

/** ID数据 */
class IdBundle(p: CoreParams) extends Bundle {
  val pc         = UInt(CONFIG_ADDR_WIDTH.W)
  val inst       = UInt(CONFIG_ADDR_WIDTH.W)
  val rs1Val     = UInt(CONFIG_ADDR_WIDTH.W)
  val rs2Val     = UInt(CONFIG_ADDR_WIDTH.W)
  val imm        = UInt(CONFIG_ADDR_WIDTH.W)
  val rs1Addr    = UInt(4.W) // RV32E：4bit 寄存器号
  val rs2Addr    = UInt(4.W)
  val rdAddr     = UInt(4.W)
  val oldctrl    = new OldCtrl
  val ctrl       = new Ctrl
  val predTaken  = Bool()
  val predTarget = UInt(CONFIG_ADDR_WIDTH.W)
}

/** EX数据 */
class ExBundle(p: CoreParams) extends Bundle {
  val pc        = UInt(CONFIG_ADDR_WIDTH.W)
  val dnpc      = UInt(CONFIG_ADDR_WIDTH.W)
  val aluResult = UInt(CONFIG_ADDR_WIDTH.W)
  val storeData = UInt(CONFIG_ADDR_WIDTH.W)
  val rdAddr    = UInt(4.W)
  val oldctrl   = new OldCtrl
  val ctrl      = new Ctrl
  val csrAddr   = UInt(p.CSR_ADDR_W.W)
  val csrWdata  = UInt(CONFIG_ADDR_WIDTH.W)
  val csrRdata  = UInt(CONFIG_ADDR_WIDTH.W)
  val excValid  = Bool()
  val excCause  = UInt(CONFIG_ADDR_WIDTH.W)
}

/** LS数据 */
class LsBundle(p: CoreParams) extends Bundle {
  val pc        = UInt(CONFIG_ADDR_WIDTH.W)
  val dnpc      = UInt(CONFIG_ADDR_WIDTH.W)
  val aluResult = UInt(CONFIG_ADDR_WIDTH.W)
  val loadData  = UInt(CONFIG_ADDR_WIDTH.W)
  val rdAddr    = UInt(4.W)
  val oldctrl   = new OldCtrl
  val ctrl      = new Ctrl
  val csrAddr   = UInt(p.CSR_ADDR_W.W)
  val csrWdata  = UInt(CONFIG_ADDR_WIDTH.W)
  val csrRdata  = UInt(CONFIG_ADDR_WIDTH.W)
  val excValid  = Bool()
  val excCause  = UInt(CONFIG_ADDR_WIDTH.W)
}

/** WB数据 */
class WbBundle(p: CoreParams) extends Bundle {
  val pc   = UInt(CONFIG_ADDR_WIDTH.W)
  val dnpc = UInt(CONFIG_ADDR_WIDTH.W)
}

/** 寄存器读写取接口，master视角，支持GPR CSR */
class OldRegReadIO(ADDR_WIDTH: Int, DATA_WIDTH: Int)  extends Bundle {
  val en   = Output(Bool())
  val addr = Output(UInt(ADDR_WIDTH.W))
  val data = Input(UInt(DATA_WIDTH.W))
}
class OldRegWriteIO(ADDR_WIDTH: Int, DATA_WIDTH: Int) extends Bundle {
  val en   = Output(Bool())
  val addr = Output(UInt(ADDR_WIDTH.W))
  val data = Output(UInt(DATA_WIDTH.W))
}
class RegWriteIO(ADDR_WIDTH: Int, DATA_WIDTH: Int)    extends Bundle {
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

/** 陷阱接口，master视角 */
class OldTrapIO(p: CoreParams) extends Bundle {
  val en    = Output(Bool())
  val epc   = Output(UInt(CONFIG_ADDR_WIDTH.W))
  val cause = Output(UInt(CONFIG_ADDR_WIDTH.W))
  val tval  = Output(UInt(CONFIG_ADDR_WIDTH.W))
}
class TrapIO()                 extends Bundle {
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
