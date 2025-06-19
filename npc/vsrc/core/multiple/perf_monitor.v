module perf_monitor (
    input  wire         clk,
    input  wire         rst
);

`ifdef RISCV_PERF_MONITOR_EN

initial begin
    // $display("Enable perf monitor");
end

/*
IFU取到指令
LSU取到数据
EXU完成计算
译码出各种类别的指令, 如计算类指令, 访存指令, CSR指令等
*/
always @(posedge clk or posedge rst) begin
    if (rst) begin
    end else begin
    end
end

`endif

endmodule