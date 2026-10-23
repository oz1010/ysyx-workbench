package pipeline_manual

import chisel3._
import scala.language.reflectiveCalls

/** 数据端先采用无缓存桥接：BaseCache 锁存请求、单拍读、写直通并等待 B。
  * 返回完整对齐字，load 抽取由 LSU 完成；数据移位和字节使能仅在桥内处理。
  */
class DCache() extends Module {
  val io = IO(new Bundle {
    val cpu    = Flipped(new CacheIO())
    val master = new Axi4IO()
  })

  val bridge = Module(new BaseCache(cacheEn = false, writeEn = true))
  bridge.io.cpu <> io.cpu
  io.master <> bridge.io.master
}
