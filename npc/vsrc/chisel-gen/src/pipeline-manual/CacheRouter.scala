package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._

class CacheRouter() extends Module {
  val io_if     = IO(Flipped(new CacheIO()))
  val io_mem    = IO(Flipped(new CacheIO()))
  val io_master = IO(new Axi4IO())

  val arbiter = Module(new Axi4IOArbiter(1))
  val icache  = Module(new ICache())

  icache.io.cpu <> io_if

  arbiter.io.master <> io_master
  arbiter.io.clients(0) <> icache.io.master

  CacheIOSlaveDefaults(io_mem)
}
