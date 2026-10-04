package rv32e

import chisel3._
import chisel3.util._

/**
 * 组相联 Cache（ICache / DCache 共用），几何参数对应讲义"优化命中率"中的 W/N/M 模型：
 *   - W：路数（每组 cache 块数），默认 8
 *   - N：组索引位数（组数 = 2^N），默认 4
 *   - M：块内偏移位数（块字节数 = 2^M），默认 4
 *   访存地址划分：tag | index(N) | offset(M)
 *   - 读 miss：经 refill 接口从 AXI burst 读整行，按"无效路优先，否则 LRU"选路回填，
 *     然后重新查表返回数据
 *   - 写策略：写直通（write-through）+ 写缓冲（Store Buffer），Store miss 不分配行
 *   - SRAM_READ_DELAY：模拟 tag/data SRAM 读延迟（0 = 组合读）
 * 
 * 缓存基本单元结构：
 *    31    m+n m+n-1   m m-1    0
 *   +---------+---------+--------+
 *   |   tag   |  index  | offset |
 *   +---------+---------+--------+
 */
class Cache(
    p: CoreParams,
    readOnly: Boolean,
    val W: Int = 8,  // 路数（每组 cache 块数）
    val N: Int = 4,  // 组索引位数（组数 = 2^N）
    val M: Int = 4   // 块内偏移位数（块字节数 = 2^M）
) extends Module {
  val nSets      = 1 << N
  val LINE_BYTES = 1 << M
  val LINE_WORDS = LINE_BYTES / (p.DATA_WIDTH / 8)
  val tagBits    = p.ADDR_WIDTH - N - M
  val wayBits    = log2Ceil(W)
  val wordBits   = log2Ceil(LINE_WORDS)
  require(W >= 2 && N >= 0 && M >= 2 && tagBits > 0)

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
  // 平坦编址：tag/valid 下标 = set * W + way；数据字下标 = (set * W + way) * LINE_WORDS + woff
  val tagMem    = Mem(nSets * W, UInt(tagBits.W))
  val dataMem   = Mem(nSets * W * LINE_WORDS, UInt(p.DATA_WIDTH.W))
  val validBits = RegInit(VecInit(Seq.fill(nSets)(VecInit(Seq.fill(W)(false.B)))))
  // 真 LRU：每组每路一个年龄计数（0 = 最近使用，W-1 = 最久未用），复位后为 0..W-1 的排列
  val lruCnt = RegInit(VecInit(Seq.fill(nSets)(
    VecInit((0 until W).map(i => i.U(wayBits.W))))))

  // -------- 请求寄存 --------
  val rAddr    = Reg(UInt(p.ADDR_WIDTH.W))
  val rWdata   = Reg(UInt(p.DATA_WIDTH.W))
  val rWstrb   = Reg(UInt((p.DATA_WIDTH / 8).W))
  val rIsWrite = Reg(Bool())
  val rVictim  = Reg(UInt(wayBits.W))

  // -------- 状态机 --------
  val sIdle :: sLookup :: sMiss :: sRefill :: sFill :: sResp :: sStWait :: Nil = Enum(7)
  val state   = RegInit(sIdle)
  val waitCnt = RegInit(0.U(8.W))                       // SRAM 读延迟计数
  val refillBuf = Reg(Vec(LINE_WORDS, UInt(p.DATA_WIDTH.W)))
  val beatCnt = RegInit(0.U(8.W))
  val rdataReg = Reg(UInt(p.DATA_WIDTH.W))

  // 输出默认值（避免未完全初始化）
  io.cpu.resp.valid   := false.B
  io.cpu.resp.data    := rdataReg
  io.refill.req.valid := false.B
  io.refill.req.addr  := 0.U

  // -------- 地址译码与组内命中查找 --------
  val lidx  = if (N > 0) rAddr(N + M - 1, M) else 0.U(1.W)
  val woff  = if (wordBits > 0) rAddr(wordBits + 1, 2) else 0.U(1.W)
  val tagIn = rAddr(p.ADDR_WIDTH - 1, N + M)

  val validRow = validBits(lidx)
  val tagRd    = VecInit(Seq.tabulate(W)(w => tagMem.read(lidx * W.U + w.U)))
  val hitVec   = VecInit(Seq.tabulate(W)(w => validRow(w) && tagRd(w) === tagIn))
  val hitAny   = hitVec.asUInt.orR
  val hitWay   = OHToUInt(hitVec)
  val wordRd   = dataMem.read((lidx * W.U + hitWay) * LINE_WORDS.U + woff)

  // -------- LRU 更新与牺牲路选择（无效路优先，否则选最久未用路） --------
  def lruUpdate(set: UInt, way: UInt): Unit = {
    val row  = lruCnt(set)
    val c    = row(way)
    val next = Wire(Vec(W, UInt(wayBits.W)))
    for (w <- 0 until W) {
      next(w) := row(w)
      when(w.U =/= way && row(w) < c) { next(w) := row(w) + 1.U }
    }
    next(way) := 0.U
    lruCnt(set) := next
  }

  val invalidVec = ~validRow.asUInt                          // 1 = 无效路
  val oldestVec  = VecInit(lruCnt(lidx).map(_ === (W - 1).U)).asUInt
  val victimWay  = Mux(invalidVec.orR, PriorityEncoder(invalidVec), PriorityEncoder(oldestVec))

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
          when(hitAny) {
            lruUpdate(lidx, hitWay)
            rdataReg := wordRd
            state := sResp
          }.otherwise {
            rVictim := victimWay
            state := sMiss
          }
        } else {
          when(rIsWrite) {
            // 写直通：命中则更新 Cache 行（RMW）并刷新 LRU，随后送 Store Buffer
            when(hitAny) {
              dataMem.write((lidx * W.U + hitWay) * LINE_WORDS.U + woff,
                mergeStrb(wordRd, rWdata, rWstrb))
              lruUpdate(lidx, hitWay)
            }
            when(storeIO.ready) { state := sResp }
            .otherwise           { state := sStWait }
          }.otherwise {
            when(hitAny) {
              lruUpdate(lidx, hitWay)
              rdataReg := wordRd
              state := sResp
            }.otherwise {
              rVictim := victimWay
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
      io.refill.req.addr  := Cat(rAddr(p.ADDR_WIDTH - 1, M), 0.U(M.W))
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

    is(sFill) { // 回填被选中的路，并标记为最近使用
      validBits(lidx)(rVictim) := true.B
      tagMem.write(lidx * W.U + rVictim, tagIn)
      for (w <- 0 until LINE_WORDS) {
        dataMem.write((lidx * W.U + rVictim) * LINE_WORDS.U + w.U, refillBuf(w))
      }
      lruUpdate(lidx, rVictim)
      waitCnt := 0.U
      state := sLookup // 重新查表返回数据
    }

    is(sResp) {
      io.cpu.resp.valid := true.B
      state := sIdle
    }
  }
}
