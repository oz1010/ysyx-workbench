import chisel3._
import chisel3.util._

class AXI4IO extends Bundle {
  // 读地址通道 AR
  val arid    = Output(UInt(4.W))
  val araddr  = Output(UInt(32.W))
  val arlen   = Output(UInt(8.W))    // 突发长度-1
  val arsize  = Output(UInt(3.W))    // 字节数 log2
  val arburst = Output(UInt(2.W))    // 01=INCR
  val arvalid = Output(Bool())
  val arready = Input(Bool())
  // 读数据通道 R
  val rid     = Input(UInt(4.W))
  val rdata   = Input(UInt(32.W))
  val rresp   = Input(UInt(2.W))
  val rlast   = Input(Bool())
  val rvalid  = Input(Bool())
  val rready  = Output(Bool())
  // 写地址通道 AW
  val awid    = Output(UInt(4.W))
  val awaddr  = Output(UInt(32.W))
  val awlen   = Output(UInt(8.W))
  val awsize  = Output(UInt(3.W))
  val awburst = Output(UInt(2.W))
  val awvalid = Output(Bool())
  val awready = Input(Bool())
  // 写数据通道 W
  val wdata   = Output(UInt(32.W))
  val wstrb   = Output(UInt(4.W))
  val wlast   = Output(Bool())
  val wvalid  = Output(Bool())
  val wready  = Input(Bool())
  // 写响应通道 B
  val bid     = Input(UInt(4.W))
  val bresp   = Input(UInt(2.W))
  val bvalid  = Input(Bool())
  val bready  = Output(Bool())
}

class AXI4MasterIO extends Bundle {
  val arid    = Output(UInt(4.W))
  val araddr  = Output(UInt(32.W))
  val arlen   = Output(UInt(8.W))
  val arsize  = Output(UInt(3.W))
  val arburst = Output(UInt(2.W))
  val arvalid = Output(Bool())
  val arready = Input(Bool())
  val rid     = Input(UInt(4.W))
  val rdata   = Input(UInt(32.W))
  val rresp   = Input(UInt(2.W))
  val rlast   = Input(Bool())
  val rvalid  = Input(Bool())
  val rready  = Output(Bool())
  // 写通道（IF 不使用）
  val awid    = Output(UInt(4.W))
  val awaddr  = Output(UInt(32.W))
  val awlen   = Output(UInt(8.W))
  val awsize  = Output(UInt(3.W))
  val awburst = Output(UInt(2.W))
  val awvalid = Output(Bool())
  val awready = Input(Bool())
  val wdata   = Output(UInt(32.W))
  val wstrb   = Output(UInt(4.W))
  val wlast   = Output(Bool())
  val wvalid  = Output(Bool())
  val wready  = Input(Bool())
  val bid     = Input(UInt(4.W))
  val bresp   = Input(UInt(2.W))
  val bvalid  = Input(Bool())
  val bready  = Output(Bool())
}

class AXIArbiter extends Module {
  val io = IO(new Bundle {
    val ifu = Flipped(new AXI4MasterIO)   // 取指主机
    val lsu = Flipped(new AXI4MasterIO)   // 访存主机
    val mem = new AXI4IO                  // 共享的内存设备
  })

  // ============ 读通道仲裁 ============

  // 锁定状态：记录当前占线主机
  // 这些寄存器必须先于仲裁器连接完成初始化；否则 Scala 的 val 初始化顺序
  // 会让 arb.io.out.ready := !locked 在构造期间访问到 null。
  val locked = RegInit(false.B)
  val owner  = RegInit(0.U(1.W))    // 0=IF, 1=LSU
  val burst  = RegInit(0.U(8.W))    // 剩余 beat 数

  // 仲裁请求：有 AR 请求即参与仲裁
  val reqIf = io.ifu.arvalid
  val reqLs = io.lsu.arvalid

  // 轮询仲裁器
  val arb = Module(new RRArbiter(Bool(), 2))
  arb.io.in(0).valid := reqIf
  arb.io.in(0).bits  := false.B
  arb.io.in(1).valid := reqLs
  arb.io.in(1).bits  := false.B
  arb.io.out.ready   := !locked   // 总线空闲时才发新授权

  // 授权结果（组合逻辑）
  val grant = arb.io.chosen            // 本拍获得仲裁的主机
  val grantValid = arb.io.out.valid && arb.io.out.ready

  when (grantValid) {
    owner := grant
  }

  // AR 通道选择
  val selIf = Mux(locked, owner === 0.U, grant === 0.U)
  io.mem.arid    := Mux(selIf, 0.U, 1.U)
  io.mem.araddr  := Mux(selIf, io.ifu.araddr,  io.lsu.araddr)
  io.mem.arlen   := Mux(selIf, io.ifu.arlen,   io.lsu.arlen)
  io.mem.arsize  := Mux(selIf, io.ifu.arsize,  io.lsu.arsize)
  io.mem.arburst := Mux(selIf, io.ifu.arburst, io.lsu.arburst)
  io.mem.arvalid := Mux(selIf, io.ifu.arvalid, io.lsu.arvalid)

  io.ifu.arready := io.mem.arready && selIf && !locked
  io.lsu.arready := io.mem.arready && !selIf && !locked

  // AR 握手成功：锁总线，记录突发长度
  when (io.mem.arvalid && io.mem.arready) {
    locked := true.B
    burst  := io.mem.arlen
  }

  // R 通道：按 rid 回送
  io.ifu.rid    := io.mem.rid
  io.ifu.rdata  := io.mem.rdata
  io.ifu.rresp  := io.mem.rresp
  io.ifu.rlast  := io.mem.rlast
  io.ifu.rvalid := io.mem.rvalid && (io.mem.rid === 0.U)

  io.lsu.rid    := io.mem.rid
  io.lsu.rdata  := io.mem.rdata
  io.lsu.rresp  := io.mem.rresp
  io.lsu.rlast  := io.mem.rlast
  io.lsu.rvalid := io.mem.rvalid && (io.mem.rid === 1.U)

  io.mem.rready := Mux(io.mem.rid === 0.U, io.ifu.rready, io.lsu.rready)

  // 最后一个 beat 收完：释放总线
  when (io.mem.rvalid && io.mem.rready && io.mem.rlast) {
    locked := false.B
  }

  // ============ 写通道直通（仅 LSU） ============
  io.mem.awid    := io.lsu.awid
  io.mem.awaddr  := io.lsu.awaddr
  io.mem.awlen   := io.lsu.awlen
  io.mem.awsize  := io.lsu.awsize
  io.mem.awburst := io.lsu.awburst
  io.mem.awvalid := io.lsu.awvalid
  io.lsu.awready := io.mem.awready

  io.mem.wdata  := io.lsu.wdata
  io.mem.wstrb  := io.lsu.wstrb
  io.mem.wlast  := io.lsu.wlast
  io.mem.wvalid := io.lsu.wvalid
  io.lsu.wready := io.mem.wready

  io.lsu.bid    := io.mem.bid
  io.lsu.bresp  := io.mem.bresp
  io.lsu.bvalid := io.mem.bvalid
  io.mem.bready := io.lsu.bready

  // IF 的写通道无连接，tie-off
  io.ifu.awready := false.B
  io.ifu.wready  := false.B
  io.ifu.bid     := 0.U
  io.ifu.bresp   := 0.U
  io.ifu.bvalid  := false.B
}
