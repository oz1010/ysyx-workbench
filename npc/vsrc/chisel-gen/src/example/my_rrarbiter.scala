import chisel3._
import chisel3.util._

class MyRRArbiter(n: Int) extends Module {
  require(n >= 2, "仲裁器至少要有 2 个输入")

  val io = IO(new Bundle {
    val req   = Input(Vec(n, Bool()))    // 各主机请求
    val grant = Output(Vec(n, Bool()))   // 独热授权
  })

  // 优先级指针：上次获得授权的主机编号
  // 复位时指向 n-1，这样第一轮从 0 号开始
  val ptr = RegInit((n - 1).U(log2Ceil(n).W))

  // ---------- 组合逻辑：选出本轮授权 ----------

  // 高于指针的请求（下一轮优先级最高的一圈）
  val higher = Wire(Vec(n, Bool()))
  // 低于等于指针的请求（兜底，轮一圈回来）
  val lower  = Wire(Vec(n, Bool()))

  for (i <- 0 until n) {
    higher(i) := io.req(i) && (i.U > ptr)
    lower(i)  := io.req(i) && (i.U <= ptr)
  }

  // 从高优先级圈里选编号最小的；空了再从低圈选
  val grantIdx = Wire(UInt(log2Ceil(n).W))
  when (higher.asUInt =/= 0.U) {
    grantIdx := PriorityEncoder(higher)      // 返回最高位的下标
  } .otherwise {
    grantIdx := PriorityEncoder(lower)
  }

  val anyReq = io.req.asUInt =/= 0.U

  for (i <- 0 until n) {
    io.grant(i) := anyReq && (grantIdx === i.U)
  }

  // ---------- 时序逻辑：授权后移动指针 ----------
  when (anyReq) {
    ptr := grantIdx
  }
}
