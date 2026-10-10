module ResetPcGetter #(
    parameter addrWidth = 32
)(
    output [addrWidth-1:0] reset_pc
);
    // 调用 Verilog 的 function 赋值给输出端口
    assign reset_pc = func_get_reset_pc();
endmodule
