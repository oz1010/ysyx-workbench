package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._

class CacheRouter() extends Module {
  val io_if     = IO(Flipped(new CacheIO()))
  val io_mem    = IO(Flipped(new CacheIO()))
  val io_master = IO(new Axi4IO())

  CacheIOSlaveDefaults(io_if)
  CacheIOSlaveDefaults(io_mem)
  Axi4MasterDefaults(io_master)
}
