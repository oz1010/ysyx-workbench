package pipeline_chisel2

import chisel3._
import chisel3.util._

/** 重定向（冲刷流水线并修改取指 PC） */
class Redirect(p: CoreParams) extends Bundle {
  val valid  = Bool()
  val target = UInt(p.ADDR_WIDTH.W)
}

/* ================= AXI4 接口 ================= */

/** AXI4 读通道（主设备视角） */
class AxiReadMasterIO(p: CoreParams) extends Bundle {
  // 读地址通道
  val araddr  = Output(UInt(p.ADDR_WIDTH.W))
  val arid    = Output(UInt(p.AXI_ID_WIDTH.W))
  val arlen   = Output(UInt(8.W))
  val arsize  = Output(UInt(3.W))
  val arburst = Output(UInt(2.W))
  val arvalid = Output(Bool())
  val arready = Input(Bool())
  // 读数据通道
  val rdata   = Input(UInt(p.DATA_WIDTH.W))
  val rresp   = Input(UInt(p.RRESP_WIDTH.W))
  val rlast   = Input(Bool())
  val rid     = Input(UInt(p.AXI_ID_WIDTH.W))
  val rvalid  = Input(Bool())
  val rready  = Output(Bool())
}

/** AXI4 写通道（主设备视角） */
class AxiWriteMasterIO(p: CoreParams) extends Bundle {
  // 写地址通道
  val awaddr  = Output(UInt(p.ADDR_WIDTH.W))
  val awid    = Output(UInt(p.AXI_ID_WIDTH.W))
  val awlen   = Output(UInt(8.W))
  val awsize  = Output(UInt(3.W))
  val awburst = Output(UInt(2.W))
  val awvalid = Output(Bool())
  val awready = Input(Bool())
  // 写数据通道
  val wdata   = Output(UInt(p.DATA_WIDTH.W))
  val wstrb   = Output(UInt((p.DATA_WIDTH / 8).W))
  val wlast   = Output(Bool())
  val wvalid  = Output(Bool())
  val wready  = Input(Bool())
  // 写响应通道
  val bresp   = Input(UInt(p.BRESP_WIDTH.W))
  val bvalid  = Input(Bool())
  val bid     = Input(UInt(p.AXI_ID_WIDTH.W))
  val bready  = Output(Bool())
}

/** AXI4 完整主设备接口（对外 io_master） */
class Axi4MasterIO(p: CoreParams) extends Bundle {
  val awaddr  = Output(UInt(p.ADDR_WIDTH.W))
  val awid    = Output(UInt(p.AXI_ID_WIDTH.W))
  val awlen   = Output(UInt(8.W))
  val awsize  = Output(UInt(3.W))
  val awburst = Output(UInt(2.W))
  val awvalid = Output(Bool())
  val awready = Input(Bool())
  val wdata   = Output(UInt(p.DATA_WIDTH.W))
  val wstrb   = Output(UInt((p.DATA_WIDTH / 8).W))
  val wlast   = Output(Bool())
  val wvalid  = Output(Bool())
  val wready  = Input(Bool())
  val bresp   = Input(UInt(p.BRESP_WIDTH.W))
  val bvalid  = Input(Bool())
  val bid     = Input(UInt(p.AXI_ID_WIDTH.W))
  val bready  = Output(Bool())
  val araddr  = Output(UInt(p.ADDR_WIDTH.W))
  val arid    = Output(UInt(p.AXI_ID_WIDTH.W))
  val arlen   = Output(UInt(8.W))
  val arsize  = Output(UInt(3.W))
  val arburst = Output(UInt(2.W))
  val arvalid = Output(Bool())
  val arready = Input(Bool())
  val rdata   = Input(UInt(p.DATA_WIDTH.W))
  val rresp   = Input(UInt(p.RRESP_WIDTH.W))
  val rlast   = Input(Bool())
  val rid     = Input(UInt(p.AXI_ID_WIDTH.W))
  val rvalid  = Input(Bool())
  val rready  = Output(Bool())
}

/* ================= Cache 接口 ================= */

/** Cache 与 CPU 侧接口（CPU 主设备视角，req 握手 valid/ready） */
class CacheCpuIO(p: CoreParams) extends Bundle {
  val req = new Bundle {
    val valid   = Output(Bool())
    val ready   = Input(Bool())
    val addr    = Output(UInt(p.ADDR_WIDTH.W))
    val wdata   = Output(UInt(p.DATA_WIDTH.W))
    val wstrb   = Output(UInt((p.DATA_WIDTH / 8).W))
    val isWrite = Output(Bool())
  }
  val resp = new Bundle {
    val valid = Input(Bool())
    val data  = Input(UInt(p.DATA_WIDTH.W))
  }
}

/** Cache 行填充接口（Cache 主设备视角：req 发出行基地址，gnt/resp 返回） */
class RefillIO(p: CoreParams) extends Bundle {
  val req = new Bundle {
    val valid = Output(Bool())
    val addr  = Output(UInt(p.ADDR_WIDTH.W)) // 行基地址
  }
  val gnt  = Input(Bool()) // 仲裁器接受本次行读请求
  val resp = new Bundle {
    val valid = Input(Bool())
    val data  = Input(UInt(p.DATA_WIDTH.W))
    val last  = Input(Bool())
  }
}

/* ================= 流水线级间寄存器（valid/ready 握手） ================= */

/** IF/ID 级间载荷 */
class IfIdBundle(p: CoreParams) extends Bundle {
  val pc         = UInt(p.ADDR_WIDTH.W)
  val inst       = UInt(p.INST_WIDTH.W)
  val predTaken  = Bool()               // 静态分支预测：是否预测跳转
  val predTarget = UInt(p.ADDR_WIDTH.W) // 预测目标
}

/** 控制信号（ID 级译码产生，随流水线传递） */
class Ctrl extends Bundle {
  val aluOp    = UInt(4.W)  // 0 add 1 sub 2 and 3 or 4 xor 5 sll 6 srl 7 sra 8 slt 9 sltu
  val usePc    = Bool()     // 操作数 A 选择 PC（AUIPC）
  val useImm   = Bool()     // 操作数 B 选择立即数
  val isBranch = Bool()
  val isJal    = Bool()
  val isJalr   = Bool()
  val load     = Bool()
  val store    = Bool()
  val memOp    = UInt(3.W)  // funct3：lb/lh/lw/lbu/lhu、sb/sh/sw
  val wbSel    = UInt(2.W)  // 0:ALU 1:Load 2:CSR 3:PC+4
  val rdWen    = Bool()
  val csrOp    = UInt(2.W)  // 0 无 1 RW 2 RS 3 RC
  val csrImm   = Bool()     // CSR 立即数形式
  val fence    = Bool()     // 作为 NOP
  val ecall    = Bool()
  val ebreak   = Bool()
  val mret     = Bool()
  val illegal  = Bool()
}

/** ID/EX 级间载荷 */
class IdExBundle(p: CoreParams) extends Bundle {
  val pc         = UInt(p.ADDR_WIDTH.W)
  val inst       = UInt(p.INST_WIDTH.W)
  val rs1Val     = UInt(p.XLEN.W)
  val rs2Val     = UInt(p.XLEN.W)
  val imm        = UInt(p.XLEN.W)
  val rs1Addr    = UInt(p.REG_ADDR_WIDTH.W) // RV32E：4bit 寄存器号
  val rs2Addr    = UInt(p.REG_ADDR_WIDTH.W)
  val rdAddr     = UInt(p.REG_ADDR_WIDTH.W)
  val ctrl       = new Ctrl
  val predTaken  = Bool()
  val predTarget = UInt(p.ADDR_WIDTH.W)
}

/** EX/MEM 级间载荷 */
class ExMemBundle(p: CoreParams) extends Bundle {
  val pc        = UInt(p.ADDR_WIDTH.W)
  val aluResult = UInt(p.XLEN.W)
  val storeData = UInt(p.XLEN.W)
  val rdAddr    = UInt(p.REG_ADDR_WIDTH.W)
  val ctrl      = new Ctrl
  val csrAddr   = UInt(12.W)
  val csrWdata  = UInt(p.XLEN.W)
  val csrRdata  = UInt(p.XLEN.W)
  val excValid  = Bool()
  val excCause  = UInt(p.XLEN.W)
}

/** MEM/WB 级间载荷 */
class MemWbBundle(p: CoreParams) extends Bundle {
  val pc        = UInt(p.ADDR_WIDTH.W)
  val aluResult = UInt(p.XLEN.W)
  val loadData  = UInt(p.XLEN.W)
  val rdAddr    = UInt(p.REG_ADDR_WIDTH.W)
  val ctrl      = new Ctrl
  val csrAddr   = UInt(12.W)
  val csrWdata  = UInt(p.XLEN.W)
  val csrRdata  = UInt(p.XLEN.W)
  val excValid  = Bool()
  val excCause  = UInt(p.XLEN.W)
}

/** 陷阱请求（WBU → CSR） */
class TrapReq(p: CoreParams) extends Bundle {
  val valid = Bool()
  val cause = UInt(p.XLEN.W)
  val epc   = UInt(p.ADDR_WIDTH.W)
}
