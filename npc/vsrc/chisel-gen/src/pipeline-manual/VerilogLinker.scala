package pipeline_manual

import chisel3._
import chisel3.util._
import config.AutoConfig._
import config.ManuConfig._

class ResetPcGetter(addrWidth: Int)
    extends BlackBox(Map("ADDR_WIDTH" -> addrWidth))
    with HasBlackBoxInline {
  val io = IO(new Bundle {
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
