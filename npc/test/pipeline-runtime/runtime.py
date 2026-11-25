#!/usr/bin/env python3
"""Run small RV32E programs through the real NPC CLI and NEMU Difftest."""

import argparse
import os
from pathlib import Path
import re
import subprocess


NPC = Path(__file__).resolve().parents[2]
BUILD = NPC / "build" / "pipeline-runtime"
CASES = {
    "consecutive": ("""
        addi t0, zero, 1
        addi t0, t0, 2
        addi t1, t0, 3
        add t2, t0, t1
        addi a0, zero, 0
        ebreak
    """, 0, 6),
    "load_store": ("""
        lui t0, 0x0f000
        addi t1, zero, -1
        sw t1, 0(t0)
        lw t2, 0(t0)
        addi a1, zero, 1
        add a2, t2, a1
        sb a1, 1(t0)
        lb a3, 0(t0)
        lbu a4, 0(t0)
        lh a5, 0(t0)
        lhu t1, 0(t0)
        lw t2, 0(t0)
        addi a0, zero, 0
        ebreak
    """, 0, 14),
    "redirect": ("""
        addi t0, zero, 3
    loop:
        addi t0, t0, -1
        bne t0, zero, loop
        beq t0, zero, taken
        addi a0, zero, 91
        sw a0, 0(zero)
    taken:
        la t1, indirect
        jalr ra, 0(t1)
        addi a0, zero, 92
        sw a0, 0(zero)
    indirect:
        jal ra, finish
        addi a0, zero, 93
    finish:
        addi a0, zero, 0
        ebreak
    """, 0, 14),
    "csr_trap": ("""
        la t0, handler
        csrrw zero, mtvec, t0
        ecall
        addi a0, zero, 0
        ebreak
    handler:
        csrrs t1, mepc, zero
        addi t1, t1, 4
        csrrw zero, mepc, t1
        mret
    """, 0, 10),
    "bad_trap": ("""
        addi a0, zero, 7
        ebreak
    """, 7, 2),
    "load_a0_trap": ("""
        lui t0, 0x0f000
        addi t1, zero, 7
        sw t1, 0(t0)
        addi a0, zero, 0
        lw a0, 0(t0)
        ebreak
    """, 7, 6),
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("cases", nargs="*", help="case names (default: all)")
    parser.add_argument("--npc-bin", type=Path, default=NPC / "build/riscv32-npc-interpreter")
    parser.add_argument("--ref", type=Path, default=NPC / "tools/nemu-diff/build/riscv32-nemu-so")
    args = parser.parse_args()
    for name in args.cases:
        if name not in CASES:
            parser.error(f"unknown case {name}; choose from {', '.join(sorted(CASES))}")
    BUILD.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, NPC_HOME=str(NPC))
    for name in args.cases or sorted(CASES):
        body, exit_code, instructions = CASES[name]
        instructions += 1  # The reset-vector JAL is now executed as well.
        source = BUILD / f"{name}.S"
        elf = source.with_suffix(".elf")
        image = source.with_suffix(".bin")
        source.write_text("""
            .section .text
            .option norvc
            .option norelax
            jal x0, _start
            .word 0
            .rept 8
            .word 0
            .endr
            .globl _start
        _start:
        """ + body)
        subprocess.run([
            "riscv64-linux-gnu-gcc", "-march=rv32e_zicsr", "-mabi=ilp32e",
            "-nostdlib", "-nostartfiles", "-static", "-fno-pic", "-no-pie",
            "-Wl,-Ttext=0x30000000,--build-id=none", "-o", str(elf), str(source),
        ], check=True, cwd=NPC, env=env)
        subprocess.run([
            "riscv64-linux-gnu-objcopy", "-O", "binary", "-j", ".text",
            str(elf), str(image),
        ], check=True, cwd=NPC, env=env)
        result = subprocess.run([
            str(args.npc_bin.resolve()), "-b",
            f"--output={BUILD}", f"--log={name}.log",
            f"--diff={args.ref.resolve()}", str(image),
        ], cwd=NPC, env=env, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, timeout=30)
        output = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout)
        (BUILD / f"{name}.stdout").write_text(output)
        expected = "HIT GOOD TRAP" if exit_code == 0 else "HIT BAD TRAP"
        count = re.search(r"total guest instructions = ([\d,]+)", output)
        trap_return = re.search(r"ret: (0x[0-9a-f]+|0)\b", output)
        valid = (
            result.returncode == exit_code
            and expected in output
            and trap_return is not None
            and int(trap_return.group(1), 0) == exit_code
            and "Differential testing: ON" in output
            and "Found " not in output
            and "ABORT" not in output
            and count is not None
            and int(count.group(1).replace(",", "")) == instructions
        )
        if not valid:
            print(output)
            raise SystemExit(f"FAIL {name}: exit={result.returncode}, log={BUILD}/{name}.stdout")
        print(f"PASS {name}: {instructions} instructions, {expected}, ret={exit_code:#x}")


if __name__ == "__main__":
    main()
