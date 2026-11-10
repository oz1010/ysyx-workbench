package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._

class GprsExt
    extends ExtModule(
      Map(
        "DATA_WIDTH" -> CONFIG_ADDR_WIDTH,
        "REG_COUNT"  -> GPR_COUNT
      )
    ) {
  override def desiredName = "gprs"

  val clock = IO(Input(Clock()))
  val reset = IO(Input(Bool()))
  val rs1   = IO(Input(UInt(GPR_ADDR_W.W)))
  val src1  = IO(Output(UInt(CONFIG_ADDR_WIDTH.W)))
  val rs2   = IO(Input(UInt(GPR_ADDR_W.W)))
  val src2  = IO(Output(UInt(CONFIG_ADDR_WIDTH.W)))
  val a0    = IO(Output(UInt(CONFIG_ADDR_WIDTH.W)))
  val a1    = IO(Output(UInt(CONFIG_ADDR_WIDTH.W)))
  val a2    = IO(Output(UInt(CONFIG_ADDR_WIDTH.W)))
  val wen   = IO(Input(Bool()))
  val waddr = IO(Input(UInt(GPR_ADDR_W.W)))
  val wdata = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
}

class CsrsExt
    extends ExtModule(
      Map(
        "INST_WIDTH" -> CONFIG_ADDR_WIDTH,
        "DATA_WIDTH" -> CONFIG_ADDR_WIDTH
      )
    ) {
  override def desiredName = "csrs"

  val clock       = IO(Input(Clock()))
  val reset       = IO(Input(Bool()))
  val raddr       = IO(Input(UInt(CSR_ADDR_W.W)))
  val rdata       = IO(Output(UInt(CONFIG_ADDR_WIDTH.W)))
  val status      = IO(Output(UInt(CONFIG_ADDR_WIDTH.W)))
  val mepc        = IO(Output(UInt(CONFIG_ADDR_WIDTH.W)))
  val mtvec       = IO(Output(UInt(CONFIG_ADDR_WIDTH.W)))
  val wen         = IO(Input(Bool()))
  val waddr       = IO(Input(UInt(CSR_ADDR_W.W)))
  val wdata       = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val trap_en     = IO(Input(Bool()))
  val trap_epc    = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val trap_cause  = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val trap_tval   = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val trap_status = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
}

class PerfMonitorExt extends ExtModule {
  override def desiredName = "perf_monitor"

  val clock            = IO(Input(Clock()))
  val reset            = IO(Input(Bool()))
  val if_in_done       = IO(Input(Bool()))
  val if_out_done      = IO(Input(Bool()))
  val id_in_done       = IO(Input(Bool()))
  val id_out_done      = IO(Input(Bool()))
  val ex_in_done       = IO(Input(Bool()))
  val ex_out_done      = IO(Input(Bool()))
  val ls_in_done       = IO(Input(Bool()))
  val ls_out_done      = IO(Input(Bool()))
  val wb_in_done       = IO(Input(Bool()))
  val wb_out_done      = IO(Input(Bool()))
  val in_if_pc         = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val in_id_pc         = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val in_ex_pc         = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val in_ls_pc         = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val in_wb_pc         = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val out_if_pc        = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val out_id_pc        = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val out_ex_pc        = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val out_ls_pc        = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val out_wb_pc        = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val predict_pc       = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val inst_code        = IO(Input(UInt(16.W)))
  val wb_write_done    = IO(Input(Bool()))
  val wb_gpr_wen       = IO(Input(Bool()))
  val wb_gpr_windex    = IO(Input(UInt(5.W)))
  val wb_gpr_wdata     = IO(Input(UInt(CONFIG_DATA_WIDTH.W)))
  val wb_csr_wch       = IO(Input(UInt((3 * (1 + CSR_ADDR_W + CONFIG_DATA_WIDTH)).W)))
  val if_cache_stat    = IO(Input(UInt(2.W)))
  val ls_cache_stat    = IO(Input(UInt(2.W)))
  val ls_mem_access    = IO(Input(Bool()))
  val ls_mem_addr      = IO(Input(UInt(CONFIG_ADDR_WIDTH.W)))
  val core_flush_type  = IO(Input(UInt(2.W)))
  val core_stage_flush = IO(Input(UInt(5.W)))
  val core_flush_done  = IO(Input(Bool()))
  val done             = IO(Output(Bool()))
}

class PerfMonitor extends Module {
  val io = IO(new Bundle {
    val ifReq      = Input(new CacheReqIO())
    val ifOut      = Input(Decoupled(new IfBundle()))
    val idOut      = Input(Decoupled(new IdBundle()))
    val exOut      = Input(Decoupled(new ExBundle()))
    val lsOut      = Input(Decoupled(new LsBundle()))
    val wbOut      = Input(Decoupled(new WbBundle()))
    val gprWrite   = Flipped(new RegWriteIO(GPR_ADDR_W, CONFIG_DATA_WIDTH))
    val csrWrite   = Flipped(new RegWriteIO(CSR_ADDR_W, CONFIG_DATA_WIDTH))
    val exRedirect = Input(new Redirect())
    val wbRedirect = Input(new Redirect())
    val done       = Output(Bool())
  })

  val perfMonitor = Module(new PerfMonitorExt())
  perfMonitor.clock := clock
  perfMonitor.reset := reset

  perfMonitor.if_in_done    := io.ifReq.fire
  perfMonitor.if_out_done   := io.ifOut.fire
  perfMonitor.id_in_done    := io.ifOut.fire
  perfMonitor.id_out_done   := io.idOut.fire
  perfMonitor.ex_in_done    := io.idOut.fire
  perfMonitor.ex_out_done   := io.exOut.fire
  perfMonitor.ls_in_done    := io.exOut.fire
  perfMonitor.ls_out_done   := io.lsOut.fire
  perfMonitor.wb_in_done    := io.lsOut.fire
  perfMonitor.wb_out_done   := io.wbOut.fire
  perfMonitor.in_if_pc      := io.ifReq.addr
  perfMonitor.in_id_pc      := io.ifOut.bits.pc
  perfMonitor.in_ex_pc      := io.idOut.bits.pc
  perfMonitor.in_ls_pc      := io.exOut.bits.pc
  perfMonitor.in_wb_pc      := io.lsOut.bits.pc
  perfMonitor.out_if_pc     := io.ifOut.bits.pc
  perfMonitor.out_id_pc     := io.idOut.bits.pc
  perfMonitor.out_ex_pc     := io.exOut.bits.pc
  perfMonitor.out_ls_pc     := io.lsOut.bits.pc
  perfMonitor.out_wb_pc     := io.wbOut.bits.pc
  perfMonitor.predict_pc    := Mux(
    io.ifOut.bits.predTaken,
    io.ifOut.bits.predTarget,
    io.ifOut.bits.pc + 4.U
  )
  perfMonitor.inst_code     := Cat(0.U(1.W), io.idOut.bits.ctrl.code)
  perfMonitor.wb_write_done := io.wbOut.fire
  perfMonitor.wb_gpr_wen    := io.gprWrite.wen
  perfMonitor.wb_gpr_windex := io.gprWrite.waddr
  perfMonitor.wb_gpr_wdata  := io.gprWrite.wdata
  perfMonitor.wb_csr_wch    := Cat(
    0.U(2.W),
    io.csrWrite.wen,
    0.U((2 * CSR_ADDR_W).W),
    io.csrWrite.waddr,
    0.U((2 * CONFIG_DATA_WIDTH).W),
    io.csrWrite.wdata
  )
  perfMonitor.if_cache_stat := 0.U
  perfMonitor.ls_cache_stat := 0.U
  perfMonitor.ls_mem_access := io.lsOut.valid &&
    (io.lsOut.bits.ctrl.isLoad || io.lsOut.bits.ctrl.isStore) &&
    !io.lsOut.bits.expt.en
  perfMonitor.ls_mem_addr := io.lsOut.bits.aluResult

  val globalFlush = io.exRedirect.valid || io.wbRedirect.valid
  perfMonitor.core_flush_type := RegNext(
    Cat(io.wbRedirect.valid, io.exRedirect.valid),
    0.U(2.W)
  )
  perfMonitor.core_stage_flush := RegNext(
    Cat(
      io.wbRedirect.valid,
      io.wbRedirect.valid,
      io.wbRedirect.valid,
      globalFlush,
      globalFlush
    ),
    0.U(5.W)
  )
  perfMonitor.core_flush_done := RegNext(globalFlush, false.B)
  io.done                     := perfMonitor.done
}

class ResetPcGetter(addrWidth: Int)
    extends ExtModule(Map("ADDR_WIDTH" -> addrWidth)) {
  val io = FlatIO(new Bundle {
    val clk      = Input(Clock())
    val rst      = Input(Bool())
    val reset_pc = Output(UInt(addrWidth.W))
  })

  setInline(
    "ResetPcGetter.v",
    s"""
module ResetPcGetter #(
    parameter ADDR_WIDTH = 32
)(
    input   wire            clk,
    input   wire            rst,
    output [ADDR_WIDTH-1:0] reset_pc
);
    assign reset_pc = r_pc;

    reg [31:0] r_pc;
    always @(posedge clk) begin
        if (rst) begin
            r_pc <= func_get_reset_pc();
        end
    end
endmodule
  """.stripMargin
  )
}
