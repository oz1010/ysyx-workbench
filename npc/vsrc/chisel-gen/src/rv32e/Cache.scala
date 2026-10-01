package rv32e

import chisel3._
import chisel3.util._

/**
 * 直接映射 Cache（ICache / DCache 共用）。
 *   - 读 miss：经 refill 接口从 AXI 读整行（burst），填入后重新查表返回数据
 *   - 写策略：写直通（write-through）+ 写缓冲（Store Buffer），Store miss 不分配行
 *   - SRAM_READ_DELAY：模拟 tag/data SRAM 读延迟（0 = 组合读）
 */
class Cache(p: CoreParams, nLines: Int, readOnly: Boolean) extends Module {
  val offBits = log2Ceil(p.LINE_BYTES)
  val idxBits = log2Ceil(nLines)
  val tagBits = p.ADDR_WIDTH - idxBits - offBits
  val wordBits = log2Ceil(p.LINE_WORDS)

  val io = IO(new Bundle {
    // CPU 侧（Cache 视角，与 CacheCpuIO 方向相反）
    val cpu = new Bundle {
      val req = new Bundle {
        val valid   = Input(Bool())
        val ready   = Output(Bool())
        val addr    = Input(UInt(p.ADDR_WIDTH.W))
        val wdata   = Input(UInt(p.DATA_WIDTH.W))
        val wstrb   = Input(UInt((p.DATA_WIDTH / 8).W))
        val isWrite = Input(Bool())
      }
      val resp = new Bundle {
        val valid = Output(Bool())
        val data  = Output(UInt(p.DATA_WIDTH.W))
      }
    }
    val refill = new RefillMasterIO(p)      // 总线侧行读（输出 req，输入 gnt/resp）
  })

  // 写直通出口（仅 DCache 存在；条件 IO，作为类成员）
  val store = if (readOnly) None else Some(IO(Decoupled(new StoreReq(p))))

  // -------- 存储阵列（异步读模型，延迟由 SRAM_READ_DELAY 产生） --------
  val tagMem  = Mem(nLines, UInt(tagBits.W))
  val dataMem = Mem(nLines * p.LINE_WORDS, UInt(p.DATA_WIDTH.W))
  val validBits = RegInit(VecInit(Seq.fill(nLines)(false.B)))

  // -------- 请求寄存 --------
  val rAddr    = Reg(UInt(p.ADDR_WIDTH.W))
  val rWdata   = Reg(UInt(p.DATA_WIDTH.W))
  val rWstrb   = Reg(UInt((p.DATA_WIDTH / 8).W))
  val rIsWrite = Reg(Bool())

  // -------- 状态机 --------
  val sIdle :: sLookup :: sMiss :: sRefill :: sFill :: sResp :: sStWait :: Nil = Enum(7)
  val state   = RegInit(sIdle)
  val waitCnt = RegInit(0.U(8.W))                       // SRAM 读延迟计数
  val refillBuf = Reg(Vec(p.LINE_WORDS, UInt(p.DATA_WIDTH.W)))
  val beatCnt = RegInit(0.U(8.W))
  val rdataReg = Reg(UInt(p.DATA_WIDTH.W))

  // 输出默认值（避免未完全初始化）
  io.cpu.resp.valid   := false.B
  io.cpu.resp.data    := rdataReg
  io.refill.req.valid := false.B
  io.refill.req.addr  := 0.U

  val lidx = rAddr(idxBits + offBits - 1, offBits)
  val woff = if (wordBits > 0) rAddr(wordBits + 1, 2) else 0.U(1.W)
  val tagHit = validBits(lidx) && tagMem.read(lidx) === rAddr(p.ADDR_WIDTH - 1, idxBits + offBits)
  val wordRd = dataMem.read(lidx * p.LINE_WORDS.U + woff)

  // -------- CPU 握手 --------
  io.cpu.req.ready := state === sIdle
  when(io.cpu.req.valid && io.cpu.req.ready) {
    rAddr := io.cpu.req.addr
    rWdata := io.cpu.req.wdata
    rWstrb := io.cpu.req.wstrb
    rIsWrite := io.cpu.req.isWrite
    waitCnt := 0.U
    state := sLookup
  }

  // -------- Store 直通出口 --------
  val storeIO = if (!readOnly) store.get else null
  if (!readOnly) {
    val st = storeIO
    st.valid := (state === sLookup && waitCnt >= p.SRAM_READ_DELAY.U && rIsWrite) ||
                (state === sStWait)
    st.bits.addr := rAddr
    st.bits.data := rWdata
    st.bits.strb := rWstrb
  }

  // -------- 读数据字节选择工具（供 hit 时 RMW 与 load 返回共用） --------
  def mergeStrb(oldWord: UInt, newWord: UInt, strb: UInt): UInt = {
    val byteMask = VecInit(Seq.tabulate(p.DATA_WIDTH / 8)(i => Fill(8, strb(i)))).asUInt
    (oldWord & ~byteMask) | (newWord & byteMask)
  }

  // -------- 主状态机 --------
  switch(state) {
    is(sLookup) {
      when(waitCnt < p.SRAM_READ_DELAY.U) {
        waitCnt := waitCnt + 1.U // 模拟 SRAM 读延迟
      }.otherwise {
        if (readOnly) {
          // ICache：只读
          when(tagHit) {
            rdataReg := wordRd
            state := sResp
          }.otherwise {
            state := sMiss
          }
        } else {
          when(rIsWrite) {
            // 写直通：命中则更新 Cache 行（RMW），随后送 Store Buffer
            when(tagHit) {
              dataMem.write(lidx * p.LINE_WORDS.U + woff, mergeStrb(wordRd, rWdata, rWstrb))
            }
            when(storeIO.ready) { state := sResp }
            .otherwise           { state := sStWait }
          }.otherwise {
            when(tagHit) {
              rdataReg := wordRd
              state := sResp
            }.otherwise {
              state := sMiss
            }
          }
        }
      }
    }

    is(sStWait) { // 等 Store Buffer 腾出空间（仅 DCache 会进入）
      if (!readOnly) { when(storeIO.ready) { state := sResp } }
    }

    is(sMiss) { // 发出行读请求，等待仲裁器授权
      io.refill.req.valid := true.B
      io.refill.req.addr  := Cat(rAddr(p.ADDR_WIDTH - 1, offBits), 0.U(offBits.W))
      when(io.refill.gnt) {
        beatCnt := 0.U
        state := sRefill
      }
    }

    is(sRefill) { // 接收 burst 数据
      when(io.refill.resp.valid) {
        refillBuf(beatCnt) := io.refill.resp.data
        when(io.refill.resp.last) {
          state := sFill
        }.otherwise {
          beatCnt := beatCnt + 1.U
        }
      }
    }

    is(sFill) { // 回填整个 Cache 行
      validBits(lidx) := true.B
      tagMem.write(lidx, rAddr(p.ADDR_WIDTH - 1, idxBits + offBits))
      for (w <- 0 until p.LINE_WORDS) {
        dataMem.write(lidx * p.LINE_WORDS.U + w.U, refillBuf(w))
      }
      waitCnt := 0.U
      state := sLookup // 重新查表返回数据
    }

    is(sResp) {
      io.cpu.resp.valid := true.B
      state := sIdle
    }
  }
}
