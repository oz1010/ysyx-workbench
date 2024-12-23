# "一生一芯"工程项目

这是"一生一芯"的工程项目. 通过运行
```bash
bash init.sh subproject-name
```
进行初始化, 具体请参考[实验讲义][lecture note].

[lecture note]: https://ysyx.oscc.cc/docs/

```bash
qemu-system-riscv32 -nographic -M virt -bios none -kernel /home/johnny/big-proj/mk-cpu-lesson-dev/ysyx-workbench/am-kernels/tests/am-tests/build/amtest-riscv32-nemu.bin -s -S

$ gdb-multiarch /home/johnny/big-proj/mk-cpu-lesson-dev/ysyx-workbench/am-kernels/tests/am-tests/build/amtest-riscv32-nemu.elf
(gdb) target remote :1234
(gdb) set $pc=0x80000000

```

## 电路评估

[Yosys README](https://github.com/OSCPU/yosys-sta)

```bash
git clone git@github.com:OSCPU/yosys-sta.git
```

### 安装依赖
```bash
apt-get update
apt-get install -y yosys
apt-get install -y libunwind-dev libyaml-cpp-dev libgomp1 libtcl8.6 wget
make init
```

### 评估样例设计

项目包含一个样例设计GCD, 可通过以下命令进行综合, 并评估其在nangate45工艺上的时序表现.

```bash
make sta
```

运行后, 可在`result/gcd-500MHz/`目录下查看评估结果. 部分文件说明如下:

- `gcd.netlist.syn.v` - Yosys综合的网表文件
- `synth_stat.txt` - Yosys综合的面积报告
- `synth_check.txt` - Yosys综合的检查报告, 用户需仔细阅读并决定是否需要排除相应警告
- `yosys.log` - Yosys综合的完整日志
- `gcd.netlist.fixed.v` - iNO优化扇出后的网表文件
- `fix-fanout.log` - iNO优化扇出的日志
- `gcd.rpt` - iSTA的时序分析报告, 包含WNS, TNS和时序路径
- `gcd.cap` - iSTA的电容违例报告
- `gcd.fanout` - iSTA的扇出违例报告
- `gcd.trans` - iSTA的转换时间违例报告
- `gcd_hold.skew` - iSTA的hold模式下时钟偏斜报告
- `gcd_setup.skew` - iSTA的setup模式下时钟偏斜报告
- `sta.log` - iSTA的日志

### 评估其他设计

需要屏蔽verilator特有的引用C函数部分

有两种操作方式：

1. 命令行传参方式, 在命令行中指定其他设计的信息

```bash
make sta DESIGN=mydesign SDC_FILE=/path/to/my.sdc RTL_FILES="/path/to/mydesign.v /path/to/xxx.v ..." CLK_FREQ_MHZ=100

PRO_PATH="/root/project/ysyx-dev/ysyx-workbench/npc/vsrc"
make sta DESIGN=top SDC_FILE=$PRO_PATH/cpu.sdc RTL_FILES="$PRO_PATH/cpu/adder.v $PRO_PATH/cpu/alu.v $PRO_PATH/cpu/decoder.v $PRO_PATH/cpu/muxkey.v $PRO_PATH/cpu/reg.v $PRO_PATH/cpu/riscv32e_defines.v $PRO_PATH/cpu/top.v" CLK_FREQ_MHZ=500
```

2. 修改变量方式, 在`Makefile`中修改上述变量, 然后运行`make sta`

注意:

- 在`RTL_FILES`的文件中必须包含一个名为`DESIGN`的module
- sdc文件中的时钟端口名称需要与设计文件保持一致, 具体内容可参考样例设计GCD中的相应文件
