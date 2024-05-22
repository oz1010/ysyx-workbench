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
