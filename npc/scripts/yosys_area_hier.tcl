# 层级化面积统计: 与 yosys-sta 的 yosys.tcl 读入相同的 RTL, 但 synth 不加 -flatten,
# 映射后 stat -liberty 会按模块分别打印面积, 用于分析流水线各模块 (IF/ID/EX/MEM/WB 等) 的占比。
# 流程与 yosys.tcl 保持一致 (clockgate/dfflibmap/abc), 仅去掉 flatten 和 6GHz 时序约束,
# 面积总和与 flat 流程的 synth_stat.txt 会有出入 (无跨层级优化), 用于模块间相对比较。
#
# argv: DESIGN LIB_FILE "verilog files" STAT_OUT "include dirs"
set DESIGN        [lindex $argv 0]
set LIB_FILE      [lindex $argv 1]
set VERILOG_FILES [string map {"\"" ""} [lindex $argv 2]]
set STAT_OUT      [lindex $argv 3]
set INC_DIRS      [string map {"\"" ""} [lindex $argv 4]]

yosys -import
verilog_defines -DIN_YOSYS_STA

set vIdirsArgs ""
foreach dir $INC_DIRS {
  lappend vIdirsArgs "-I$dir"
}

foreach file $VERILOG_FILES {
  read_verilog -sv {*}$vIdirsArgs $file
}

synth -top $DESIGN

# 以下顺序与 yosys-sta/scripts/yosys.tcl 一致, 保证触发器/门控时钟被正确映射
opt -purge
clockgate -liberty $LIB_FILE
dfflibmap -liberty $LIB_FILE
opt -undriven
abc -liberty $LIB_FILE

opt_clean -purge
tee -o $STAT_OUT stat -liberty $LIB_FILE
