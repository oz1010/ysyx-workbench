package pipeline_manual

import chisel3._
import chisel3.util._
import scala.language.reflectiveCalls
import config.AutoConfig._
import config.ManuConfig._

/** LSU：通过 CacheIO 完成访存，锁存响应以承受 WB 反压；跨字 load 读取两个字拼接，
  * 跨字 store 拆成字节写。冲刷后排空已接受请求的响应，不将旧响应交给新指令；
  * 已发出的 store 无法撤销。
  */
class Lsu() extends Module {
  val io = IO(new Bundle {
    val cache = new CacheIO()
    val in    = Flipped(Decoupled(new ExBundle()))
    val out   = Decoupled(new LsBundle())
    val kill  = Input(Bool())
  })

  val in = io.in.bits
  val isMemInst = (in.ctrl.isLoad || in.ctrl.isStore) && !in.expt.en
  val pending = RegInit(false.B)
  val discard = RegInit(false.B)
  val responseValid = RegInit(false.B)
  val responseError = RegInit(false.B)
  val responseData = Reg(UInt(CONFIG_DATA_WIDTH.W))
  val beatIndex = RegInit(0.U(2.W))
  val firstData = Reg(UInt(CONFIG_DATA_WIDTH.W))

  val addr = in.aluResult
  val off = addr(1, 0)
  val accessBytes = MuxLookup(in.ctrl.memOp(1, 0), 1.U)(
    Seq(0.U -> 1.U, 1.U -> 2.U, 2.U -> 4.U)
  )
  val split = (off +& accessBytes) > 4.U
  val splitStore = split && in.ctrl.isStore
  val totalBeats = Mux(splitStore, accessBytes, Mux(split, 2.U, 1.U))

  // 跨字 load 读两个字后拼接；跨字 store 逐字节提交，避免改写相邻字节。
  io.cache.req.valid := io.in.valid && isMemInst && !io.kill && !reset.asBool &&
    !pending && !responseValid && !discard
  io.cache.req.addr  := addr + beatIndex
  io.cache.req.op    := Mux(splitStore, MemOp.SB, in.ctrl.memOp)
  io.cache.req.wdata := Mux(splitStore,
    in.storeData >> Cat(beatIndex, 0.U(3.W)), in.storeData)
  io.cache.rsp.ready := pending || io.cache.req.fire
  when(io.cache.req.fire) {
    pending := true.B
  }
  when(io.cache.rsp.fire) {
    pending := false.B
    discard := false.B
    when(!discard && !io.kill) {
      when(io.cache.rsp.error) {
        responseValid := true.B
        responseError := true.B
        responseData  := io.cache.rsp.data
      }.elsewhen(beatIndex +& 1.U < totalBeats) {
        firstData := io.cache.rsp.data
        beatIndex := beatIndex + 1.U
      }.otherwise {
        responseValid := true.B
        responseError := false.B
        responseData  := io.cache.rsp.data
      }
    }.otherwise {
      beatIndex := 0.U
    }
  }
  when(io.out.fire) {
    responseValid := false.B
    responseError := false.B
    beatIndex := 0.U
  }
  when(io.kill) {
    responseValid := false.B
    responseError := false.B
    when(pending && !io.cache.rsp.fire) {
      discard := true.B
    }.otherwise {
      beatIndex := 0.U
    }
  }

  val rdata = responseData
  val loadWord = Mux(beatIndex =/= 0.U, Cat(rdata, firstData) >> Cat(off, 0.U(3.W)),
    Cat(0.U(32.W), rdata) >> Cat(off, 0.U(3.W)))(31, 0)
  val byteSel = loadWord(7, 0)
  val halfSel = loadWord(15, 0)
  val loadData = MuxLookup(in.ctrl.memOp, loadWord)(
    Seq(
      MemOp.LB  -> Cat(Fill(24, byteSel(7)), byteSel),
      MemOp.LH  -> Cat(Fill(16, halfSel(15)), halfSel),
      MemOp.LW  -> loadWord,
      MemOp.LBU -> Cat(0.U(24.W), byteSel),
      MemOp.LHU -> Cat(0.U(16.W), halfSel)
    )
  )

  val expt = Wire(new Expt)
  ExptDefaults(expt)
  expt.en    := responseValid && responseError
  expt.cause := Mux(in.ctrl.isStore, ExptCode.STORE_ACCESS, ExptCode.LOAD_ACCESS)
  expt.tval  := addr + beatIndex

  // 上游异常不访问 Cache；AXI 错误在本级转换为 load/store access fault。
  val memWait = isMemInst && !responseValid
  io.in.ready           := io.out.ready && !memWait && !io.kill
  io.out.valid          := io.in.valid && !memWait && !io.kill
  io.out.bits.pc        := in.pc
  io.out.bits.dnpc      := in.dnpc
  io.out.bits.aluResult := in.aluResult
  io.out.bits.loadData  := loadData
  io.out.bits.rdAddr    := in.rdAddr
  io.out.bits.ctrl      := in.ctrl
  io.out.bits.csrAddr   := in.csrAddr
  io.out.bits.csrWdata  := in.csrWdata
  io.out.bits.csrRdata  := in.csrRdata
  io.out.bits.expt      := Mux(in.expt.en, in.expt, expt)
}
