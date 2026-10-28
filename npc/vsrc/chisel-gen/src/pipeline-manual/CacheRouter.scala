package pipeline_manual

import chisel3._
import chisel3.util._
import scala.language.reflectiveCalls
import config.AutoConfig._
import config.ManuConfig._

class CacheRouter() extends Module {
  val io_if     = IO(Flipped(new CacheIO()))
  val io_mem    = IO(Flipped(new CacheIO()))
  val io_master = IO(new Axi4IO())

  val arbiter = Module(new Axi4IOArbiter(2))
  val icache  = Module(if (CONFIG_ICACHE) {
    new BaseCache(
      cacheEn = true,
      writeEn = false,
      W = CONFIG_ICACHE_PARAMETER_W,
      N = CONFIG_ICACHE_PARAMETER_N,
      M = CONFIG_ICACHE_PARAMETER_M
    )
  } else {
    new BaseCache(cacheEn = false, writeEn = false)
  })
  val dcache  = Module(if (CONFIG_DCACHE) {
    new BaseCache(
      cacheEn = true,
      writeEn = true,
      W = CONFIG_DCACHE_PARAMETER_W,
      N = CONFIG_DCACHE_PARAMETER_N,
      M = CONFIG_DCACHE_PARAMETER_M
    )
  } else {
    new BaseCache(cacheEn = false, writeEn = true)
  })

  icache.io.cpu <> io_if
  dcache.io.cpu <> io_mem

  arbiter.io.master <> io_master
  arbiter.io.clients(0) <> icache.io.master
  arbiter.io.clients(1) <> dcache.io.master
}
