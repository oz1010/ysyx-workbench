package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import scala.language.reflectiveCalls

private class BaseCacheArray(W: Int, N: Int, M: Int)
    extends ExtModule(
      Map(
        "ADDR_WIDTH" -> CONFIG_ADDR_WIDTH,
        "DATA_WIDTH" -> CONFIG_DATA_WIDTH,
        "W"          -> W,
        "N"          -> N,
        "M"          -> M
      )
    ) {
  override def desiredName: String = "cache"

  val io = FlatIO(new Bundle {
    val clock      = Input(Clock())
    val reset      = Input(Bool())
    val addr       = Input(UInt(CONFIG_ADDR_WIDTH.W))
    val update_en  = Input(Bool())
    val reset_en   = Input(Bool())
    val write_en   = Input(Bool())
    val write_data = Input(UInt(CONFIG_DATA_WIDTH.W))
    val read_en    = Output(Bool())
    val read_data  = Output(UInt(CONFIG_DATA_WIDTH.W))
  })
}

/** 单笔请求 CacheIO/AXI 桥，写透传、不写分配，写命中时无效对应行。 writeEn=false 时写请求返回空响应，不访问缓存或 AXI
  * 写通道。 cache.v 及其依赖由现有 Verilog filelist 提供。
  */
class BaseCache(
  cacheEn: Boolean = true,
  writeEn: Boolean = true,
  W: Int = 2, // ways
  N: Int = 2, // indexBits
  M: Int = 3  // offsetBits
) extends Module {
  val io = IO(new Bundle {
    val cpu       = Flipped(new CacheIO())
    val master    = new Axi4IO()
    val flush     = Input(Bool())
    val cacheStat = Output(UInt(2.W))
  })

  if (cacheEn) {
    require(W > 0 && N >= 0 && M > 2)
    require(N + M < 31)
  }

  val Seq(idle, lookup, readAddr, readData, writeReq, writeResp, response) =
    Enum(7)
  val state                                                                = RegInit(idle)
  val addr                                                                 = RegInit(0.U(CONFIG_ADDR_WIDTH.W))
  val op                                                                   = RegInit(0.U(MemOp.width.W))
  val wdata                                                                = RegInit(0.U(CONFIG_DATA_WIDTH.W))
  val rspData                                                              = RegInit(0.U(CONFIG_DATA_WIDTH.W))
  val rspError                                                             = RegInit(false.B)
  val rspCacheStat                                                         = RegInit(CacheStat.NONE)
  val flushPending                                                         = RegInit(false.B)

  when(io.flush) {
    flushPending := true.B
  }.elsewhen(state === idle) {
    flushPending := false.B
  }

  val hit          = WireDefault(false.B)
  val hitData      = WireDefault(0.U(CONFIG_DATA_WIDTH.W))
  val refill       = WireDefault(false.B)
  val refillAddr   = WireDefault(addr)
  val refillLast   = WireDefault(true.B)
  val refillTarget = WireDefault(true.B)

  CacheIOSlaveDefaults(io.cpu)
  Axi4MasterDefaults(io.master)

  io.cpu.req.ready := state === idle && !reset.asBool && !io.flush && !flushPending
  io.cpu.rsp.valid := state === response
  io.cpu.rsp.data  := rspData
  io.cpu.rsp.error := rspError
  io.cacheStat     := rspCacheStat

  io.master.arvalid := state === readAddr
  // 地址在整个事务期间保持，兼容按地址选择从设备的互连。
  io.master.araddr  := Mux(refill, refillAddr, addr)
  io.master.arsize  := Mux(refill, 2.U, Cat(0.U(1.W), op(1, 0)))
  io.master.arburst := 1.U
  io.master.rready  := state === readData

  if (cacheEn) {
    val cache       = Module(new BaseCacheArray(W, N, M))
    val filling     = RegInit(false.B)
    val fillOffset  = RegInit(0.U(M.W))
    val refillError = RegInit(false.B)
    val lineBase    =
      Cat(addr(CONFIG_ADDR_WIDTH - 1, M), 0.U(M.W))
    val lastOffset  = ((BigInt(1) << M) - 4).U(M.W)
    val fillDone    = filling && io.master.rFire && refillLast

    // MMIO 不缓存；与现有 cache 一致，仅缓存这些存储区域。
    def inRegion(base: UInt, size: UInt): Bool =
      addr >= base && (addr - base) < size

    val cacheable =
      inRegion(CONFIG_MROM_BASE, CONFIG_MROM_SIZE) ||
        inRegion(CONFIG_FLASH_BASE, CONFIG_FLASH_SIZE) ||
        inRegion(CONFIG_PSRAM_BASE, CONFIG_PSRAM_SIZE) ||
        inRegion(CONFIG_SDRAM_BASE, CONFIG_SDRAM_SIZE)

    cache.io.clock      := clock
    // 冲刷期间继续排空旧总线事务，但禁止其回填结果重新变为有效。
    cache.io.reset      := reset.asBool || io.flush || flushPending ||
      (fillDone && (refillError || io.master.rresp =/= 0.U))
    // CPU 接收完整的对齐字，字节/半字提取由 LSU 完成。
    cache.io.addr       := Cat(addr(CONFIG_ADDR_WIDTH - 1, 2), 0.U(2.W))
    cache.io.update_en  := filling
    cache.io.reset_en   := false.B
    cache.io.write_en   := filling && io.master.rFire
    cache.io.write_data := io.master.rdata

    hit          := cacheable && cache.io.read_en
    hitData      := cache.io.read_data
    refill       := filling
    refillAddr   := lineBase | fillOffset
    refillLast   := fillOffset === lastOffset
    refillTarget := fillOffset === Cat(addr(M - 1, 2), 0.U(2.W))

    when(state === lookup && !op(3)) {
      rspCacheStat := Mux(hit, CacheStat.HIT, Mux(cacheable, CacheStat.MISS, CacheStat.NONE))
    }
    when(state === lookup && !op(3) && cacheable && !hit) {
      filling     := true.B
      fillOffset  := 0.U
      refillError := false.B
    }
    when(filling && io.master.rFire) {
      refillError := refillError || io.master.rresp =/= 0.U
      when(refillLast) {
        filling := false.B
      }.otherwise {
        fillOffset := fillOffset + 4.U
      }
    }
    if (writeEn) {
      // 未命中时 reset_en 会选中默认 way，必须用命中信号限定。
      cache.io.reset_en := state === lookup && op(3) && cache.io.read_en
    }
  }

  when(io.cpu.req.fire) {
    addr         := io.cpu.req.addr
    op           := io.cpu.req.op
    wdata        := io.cpu.req.wdata
    rspData      := 0.U
    rspError     := false.B
    rspCacheStat := CacheStat.NONE
    if (writeEn) {
      state := lookup
    } else {
      state := Mux(io.cpu.req.op(3), response, lookup)
    }
  }

  when(state === lookup) {
    when(op(3)) {
      if (writeEn) {
        state := writeReq
      } else {
        state := response
      }
    }.elsewhen(hit) {
      rspData := hitData
      state   := response
    }.otherwise {
      state := readAddr
    }
  }

  when(state === readAddr && io.master.arFire) {
    state := readData
  }
  when(state === readData && io.master.rFire) {
    when(!refill || refillTarget) {
      rspData := io.master.rdata
    }
    rspError := rspError || io.master.rresp =/= 0.U
    // 单拍顺序填行，兼容不支持 AXI burst 的 flash 等从设备。
    state := Mux(!refill || refillLast, response, readAddr)
  }

  if (writeEn) {
    val awDone = RegInit(false.B)
    val wDone  = RegInit(false.B)
    val shift  = Cat(addr(1, 0), 0.U(3.W))
    val strb   = MuxLookup(op(1, 0), "b1111".U(4.W))(
      Seq(
        0.U -> "b0001".U(4.W),
        1.U -> "b0011".U(4.W),
        2.U -> "b1111".U(4.W)
      )
    )

    io.master.awvalid := state === writeReq && !awDone
    io.master.awaddr  := addr
    io.master.awsize  := Cat(0.U(1.W), op(1, 0))
    io.master.awburst := 1.U
    io.master.wvalid  := state === writeReq && !wDone
    io.master.wdata   := wdata << shift
    io.master.wstrb   := strb << addr(1, 0)
    io.master.wlast   := true.B
    io.master.bready  := state === writeResp

    when(io.cpu.req.fire) {
      awDone := false.B
      wDone  := false.B
    }
    when(io.master.awFire) { awDone := true.B }
    when(io.master.wFire) { wDone := true.B }
    when(
      state === writeReq &&
        (awDone || io.master.awFire) && (wDone || io.master.wFire)
    ) {
      state := writeResp
    }
    when(state === writeResp && io.master.bFire) {
      rspError := io.master.bresp =/= 0.U
      state    := response
    }
  }

  when(io.cpu.rsp.fire) {
    state := idle
  }
}
