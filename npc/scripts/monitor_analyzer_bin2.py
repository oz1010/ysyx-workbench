#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
分析monitor性能监控数据，直接翻译c++版本
格式如下：
01 01 9b 01 02 01 02 12 01 04 01 01 05 00
01 01 9b 01 02 01 02 01 01 04 01 01 05 00
用法: ./monitor_analyzer.py <FILE>
"""

import struct
import sys
import os
from collections import defaultdict
from typing import List, Dict

EVENT_STRS = ["INVALID", "IFU", "IDU", "LSU", "EXU", "WBU"]
CODE_STRS = [
    "LUI", "AUIPC", "JAL", "JALR", "BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU",
    "LB", "LH", "LW", "LBU", "LHU", "SB", "SH", "SW", "ADDI", "SLTI",
    "SLTIU", "XORI", "ORI", "ANDI", "SLLI", "SRLI", "SRAI", "ADD", "SUB", "SLL",
    "SLT", "SLTU", "XOR", "SRL", "SRA", "OR", "AND", "FENCE", "FENCE_I", "ECALL",
    "EBREAK", "CSRRW", "CSRRS", "CSRRC", "CSRRWI", "CSRRSI", "CSRRCI", "MUL", "MULH", "MULHSU",
    "MULHU", "DIV", "DIVU", "REM", "REMU", "MRET"
]

PERF_MONITOR_TYPE_EVENT = 1
PERF_MONITOR_TYPE_CODE = 2
EVENT_INVALID, EVENT_IFU, EVENT_IDU, EVENT_LSU, EVENT_EXU, EVENT_WBU, EVENT_COUNT = range(7)

class Instruction:
    def __init__(self):
        self.inst_code = 255
        self.start_tick = 0
        self.end_tick = 0
        self.stages: Dict[int, int] = {}
        self.has_exu = False
        self.has_lsu = False

class Stat:
    def __init__(self):
        self.inst_counts = defaultdict(int)
        self.inst_cycles_avg_total = defaultdict(int)
        self.inst_cycles_avg_count = defaultdict(int)
        self.stage_delays_avg_total = defaultdict(int)
        self.stage_delays_avg_count = defaultdict(int)
        self.total_instructions = 0
        self.total_cycles = 0

stats = Stat()

def show_progress(pos, size):
    print("\r解析文件进度: {:.2f}% ({}/{})".format(100.0 * pos / size, pos, size), end='', flush=True)

def analyze_instructions(instructions: List[Instruction]):
    for inst in instructions:
        if inst.inst_code == 255:
            continue

        stats.total_instructions += 1
        stats.inst_counts[inst.inst_code] += 1
        cycles = inst.end_tick - inst.start_tick
        stats.inst_cycles_avg_total[inst.inst_code] += cycles
        stats.inst_cycles_avg_count[inst.inst_code] += 1
        stats.total_cycles += cycles

        for event_type, delay in inst.stages.items():
            stats.stage_delays_avg_total[event_type] += delay
            stats.stage_delays_avg_count[event_type] += 1

    instructions.clear()

def parse_binary_log(filepath):
    if not os.path.isfile(filepath):
        print(f"无法打开文件: {filepath}")
        sys.exit(1)

    with open(filepath, 'rb') as f:
        buffer = f.read()

    size = len(buffer)
    instructions = []
    current_inst = Instruction()
    current_tick = 0
    start_tick = 0
    pos = 0
    last_idx = 0
    show_mix_size = 1024 * 1024

    show_progress(pos, size)

    try:
        while pos < size:
            if pos - last_idx >= show_mix_size:
                show_progress(pos, size)
                last_idx = pos
                analyze_instructions(instructions)

            first_byte = buffer[pos]
            pos += 1
            entry_type = first_byte & 0x3F
            time_len = 1 << ((first_byte >> 6) & 0x03)

            if entry_type == PERF_MONITOR_TYPE_EVENT:
                if pos >= size:
                    raise RuntimeError("缺少阶段类型")
                event_type = buffer[pos]
                pos += 1

                if pos + time_len > size:
                    raise RuntimeError("缺少时间差值")
                time_diff = int.from_bytes(buffer[pos:pos + time_len], 'little')
                pos += time_len

                current_tick += time_diff

                if event_type == EVENT_IFU:
                    if current_inst.inst_code != 255:
                        instructions.append(current_inst)
                    current_inst = Instruction()
                    current_inst.start_tick = start_tick
                    current_inst.end_tick = current_tick
                    current_inst.stages[event_type] = time_diff
                else:
                    if event_type == EVENT_EXU:
                        if current_inst.has_lsu:
                            raise RuntimeError("指令同时包含EXU和LSU")
                        current_inst.has_exu = True
                    elif event_type == EVENT_LSU:
                        if current_inst.has_exu:
                            raise RuntimeError("指令同时包含EXU和LSU")
                        current_inst.has_lsu = True
                    current_inst.stages[event_type] = time_diff
                    current_inst.end_tick = current_tick
                    start_tick = current_tick

            elif entry_type == PERF_MONITOR_TYPE_CODE:
                if pos >= size:
                    raise RuntimeError("缺少指令编码")
                inst_code = buffer[pos]
                pos += 1
                current_inst.inst_code = inst_code

            else:
                raise RuntimeError(f"未知条目类型: {entry_type}")

    except Exception as e:
        show_progress(pos, size)
        print(f"\n解析错误位置 pos={pos}: {e}")
        sys.exit(1)

    show_progress(pos, size)
    if current_inst.inst_code != 255:
        instructions.append(current_inst)
    analyze_instructions(instructions)

def print_stats(filepath):
    inst_avg_cycles = {}
    inst_percentage = {}

    for code, count in stats.inst_counts.items():
        inst_avg_cycles[code] = stats.inst_cycles_avg_total[code] / stats.inst_cycles_avg_count[code]
        inst_percentage[code] = (count * 100.0 / stats.total_instructions)

    print(f"\n分析结果 (文件: {filepath})")
    print("\n指令统计:")
    if not stats.inst_counts:
        print("  无有效指令数据")
    else:
        sorted_codes = sorted(stats.inst_counts, key=lambda c: (-inst_avg_cycles[c], -stats.inst_counts[c], c))
        for code in sorted_codes:
            name = CODE_STRS[code] if code < len(CODE_STRS) else f"UNKNOWN_{code}"
            print(f"  {name:>7}: {inst_avg_cycles[code]:.1f} | {stats.inst_counts[code]} ({inst_percentage[code]:.1f}%)")

    print(f"指令总周期：{stats.total_cycles}")
    print(f"指令总数：{stats.total_instructions}")
    ipc = stats.total_instructions / max(1, stats.total_cycles)
    print(f"IPC：{ipc:.3f}")

    print("\n阶段延迟统计:")
    if not stats.stage_delays_avg_total:
        print("  无有效阶段延迟数据")
    else:
        delay_avg = [
            (et, stats.stage_delays_avg_total[et] / stats.stage_delays_avg_count[et])
            for et in stats.stage_delays_avg_total
        ]
        for event_type, avg in sorted(delay_avg, key=lambda x: x[0]):
            print(f"{EVENT_STRS[event_type]:>5}: {avg:.1f} | {stats.stage_delays_avg_count[event_type]}")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f"用法: {sys.argv[0]} <日志文件>")
        sys.exit(1)
    parse_binary_log(sys.argv[1])
    print_stats(sys.argv[1])
