package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._

class CacheRouter() extends Module {
  val io_if     = IO(Flipped(new CacheIO()))
  val io_mem    = IO(Flipped(new CacheIO()))
  val io_master = IO(new Axi4IO())

  val arbiter = Module(new Axi4IOArbiter(2))
  val icache  = Module(new ICache())
  val dcache  = Module(new DCache())

  icache.io.cpu <> io_if
  dcache.io.cpu <> io_mem

  arbiter.io.master <> io_master
  arbiter.io.clients(0) <> icache.io.master
  arbiter.io.clients(1) <> dcache.io.master
}
