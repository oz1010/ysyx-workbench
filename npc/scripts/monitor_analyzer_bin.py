#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
分析monitor性能监控数据
格式如下：
01 01 9b 01 02 01 02 12 01 04 01 01 05 00
01 01 9b 01 02 01 02 01 01 04 01 01 05 00
用法: ./monitor_analyzer.py <FILE>
"""


import sys
import mmap
import os
from dataclasses import dataclass, field
from typing import DefaultDict, Dict, List, Tuple
from collections import defaultdict

@dataclass
class InstStat:
    inst_counts: DefaultDict[str, int] = field(
        default_factory=lambda: defaultdict(int))
    inst_cycles: DefaultDict[str, List[int]] = field(
        default_factory=lambda: defaultdict(list))
    stage_delays: DefaultDict[str, List[int]] = field(
        default_factory=lambda: defaultdict(list))
    lsu_avg_delays: List[int] = field(default_factory=list)
    exec_unit_usage: Dict[str, int] = field(
        default_factory=lambda: {'EXU': 0, 'LSU': 0})
    total_instructions: int = 0
    total_cycles: int = 0
stats = InstStat()

# # 统计指令类型
# inst_counts = defaultdict(int)
# inst_cycles = defaultdict(list)
# # 统计各阶段延迟
# stage_delays = defaultdict(list)
# # 特殊统计：LSU指令的IDU到WBU延迟
# lsu_avg_delays = []
# # 执行单元使用情况
# exec_unit_usage = {'EXU': 0, 'LSU': 0}
# total_instructions = 0

# @dataclass
# class Instruction:
#     start_tick:

def parse_binary_log(file_path):
    EVENT_STRS = [ "INVALID", "IFU", "IDU", "LSU", "EXU", "WBU" ]
    CODE_STRS = [
        "LUI",    "AUIPC", "JAL",   "JALR",  "BEQ",    "BNE",    "BLT",    "BGE",   "BLTU",    "BGEU",
        "LB",     "LH",    "LW",    "LBU",   "LHU",    "SB",     "SH",     "SW",    "ADDI",    "SLTI",
        "SLTIU",  "XORI",  "ORI",   "ANDI",  "SLLI",   "SRLI",   "SRAI",   "ADD",   "SUB",     "SLL",
        "SLT",    "SLTU",  "XOR",   "SRL",   "SRA",    "OR",     "AND",    "FENCE", "FENCE_I", "ECALL",
        "EBREAK", "CSRRW", "CSRRS", "CSRRC", "CSRRWI", "CSRRSI", "CSRRCI", "MUL",   "MULH",    "MULHSU",
        "MULHU",  "DIV",   "DIVU",  "REM",   "REMU",   "MRET"
    ]
    
    instructions = []
    current_inst = None
    start_tick = 0
    current_tick = 0  # 当前绝对时间
    i = 0
    size = 1
    
    try:
        with open(file_path, 'rb') as f:
            with mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
                size = mm.size()
                last_idx = 0
                show_mix_size = 1024*1024
                sys.stdout.write(f"\n解析文件进度: {(i/size*100):.2f}% ({i}/{size})")
                sys.stdout.flush()
                while i < size:
                    if (i-last_idx >= show_mix_size):
                        sys.stdout.write(f"\r解析文件进度: {(i/size*100):.2f}% ({i}/{size})")
                        last_idx = i
                        analyze_instructions(instructions)
                    # 解析第一个字节
                    first_byte = mm[i]
                    entry_type = first_byte & 0x3F  # 低6位
                    time_len_shift = (first_byte >> 6) & 0x03  # 高2位
                    time_len = 1 << time_len_shift  # 2^n字节
                    i += 1

                    if entry_type == 1:  # 阶段记录
                        if i >= size:
                            raise ValueError("数据不完整 (缺少阶段类型)")    
                        stage_type = mm[i]
                        i += 1
                        
                        if i + time_len > size:
                            raise ValueError(" 数据不完整 (缺少时间差值)")
                        time_diff_bytes = mm[i:i+time_len]
                        i += time_len
                        time_diff = int.from_bytes(time_diff_bytes, byteorder='little', signed=False)
                        current_tick += time_diff

                        if 1 <= stage_type < len(EVENT_STRS):
                            stage_name = EVENT_STRS[stage_type]
                        else:
                            stage_name = f'UNKNOWN_{stage_type}'
                            raise ValueError(f"未知的阶段类型: {stage_type}")
                        
                        if stage_name == 'IFU':
                            # 新指令开始
                            if current_inst is not None:
                                instructions.append(current_inst)
                            current_inst = {
                                'start_tick': start_tick,
                                'end_tick': current_tick,
                                'stages': {'IFU': current_tick},
                                'inst': None,
                                'has_exu': False,
                                'has_lsu': False
                            }
                        elif stage_name != 'INVALID':
                            if current_inst is not None:
                                if stage_name == 'EXU':
                                    if current_inst['has_lsu']:
                                        raise ValueError(f"警告: 指令同时包含EXU和LSU阶段 (tick={current_tick})")
                                    current_inst['has_exu'] = True
                                elif stage_name == 'LSU':
                                    if current_inst['has_exu']:
                                        raise ValueError(f"警告: 指令同时包含EXU和LSU阶段 (tick={current_tick})")
                                    current_inst['has_lsu'] = True

                                current_inst['stages'][stage_name] = current_tick
                                current_inst['end_tick'] = current_tick
                                start_tick = current_tick
                    
                    elif entry_type == 2:  # 指令记录
                        if i >= size:
                            raise ValueError("数据不完整 (缺少指令编码)")
                            
                        inst_code = mm[i]
                        i += 1
                        
                        # 获取指令名称
                        if 0 <= inst_code < len(CODE_STRS):
                            inst_name = CODE_STRS[inst_code]
                        else:
                            inst_name = f'UNKNOWN_{inst_code}'
                            raise ValueError(f"未知的指令编码: {inst_code}")
                        
                        if current_inst is not None:
                            current_inst['inst'] = inst_name
                    else:
                        raise ValueError(f"未知的条目类型: {entry_type}")
    except KeyboardInterrupt:
        sys.stdout.write(f"\r解析文件进度: {(pos/size*100):.2f}% ({pos}/{size})")
        sys.stdout.flush()
        print("\n用户中断解析")
        sys.exit(-1)    
    except Exception as e:
        sys.stdout.write(f"\r解析文件进度: {(i/size*100):.2f}% ({i}/{size})")
        sys.stdout.flush()
        print(f"\n解析错误在位置 i={i}: {str(e)}", file=sys.stderr)
        exit(-1)
    
    sys.stdout.write(f"\r解析文件进度: {(i/size*100):.2f}% ({i}/{size})")
    sys.stdout.flush()
    if current_inst is not None:
        instructions.append(current_inst)
    
    analyze_instructions(instructions)

def analyze_instructions(instructions):
    global stats

    for inst in instructions:
        if inst['inst'] is None:
            continue
            
        stats.total_instructions += 1
        inst_type = inst['inst']
        stats.inst_counts[inst_type] += 1
        
        # 计算指令总周期
        cycles = inst['end_tick'] - inst['start_tick']
        stats.inst_cycles[inst_type].append(cycles)
        stats.total_cycles += cycles
        
        # 记录执行单元使用情况
        if inst['has_exu']:
            stats.exec_unit_usage['EXU'] += 1
        if inst['has_lsu']:
            stats.exec_unit_usage['LSU'] += 1
            # 计算LSU指令的IDU到WBU延迟
            if 'IDU' in inst['stages'] and 'LSU' in inst['stages']:
                stats.lsu_avg_delays.append(inst['stages']['LSU'] - inst['stages']['IDU'])
        
        # 计算各阶段延迟
        stages = inst['stages']
        if 'IFU' in stages:
            stats.stage_delays['STR_IFU'].append(stages['IFU'] - inst['start_tick'])
        if 'IFU' in stages and 'IDU' in stages:
            stats.stage_delays['IFU_IDU'].append(stages['IDU'] - stages['IFU'])
        if 'IDU' in stages:
            next_stage = 'EXU' if 'EXU' in stages else 'LSU' if 'LSU' in stages else None
            if next_stage:
                stats.stage_delays[f'IDU_{next_stage}'].append(stages[next_stage] - stages['IDU'])
        if 'EXU' in stages and 'WBU' in stages:
            stats.stage_delays['EXU_WBU'].append(stages['WBU'] - stages['EXU'])
        if 'LSU' in stages and 'WBU' in stages:
            stats.stage_delays['LSU_WBU'].append(stages['WBU'] - stages['LSU'])

    instructions.clear()

def print_stats():
    global stats

    # 计算指令比例和平均周期
    inst_percentage = {inst: (count/stats.total_instructions)*100 for inst, count in stats.inst_counts.items()}
    inst_avg_cycles = {inst: sum(cycles)/len(cycles) if cycles else 0 
                      for inst, cycles in stats.inst_cycles.items()}
    
    # 计算LSU指令IDU到WBU平均延迟
    lsu_avg_idu_to_wbu = sum(stats.lsu_avg_delays)/len(stats.lsu_avg_delays) if stats.lsu_avg_delays else 0

    print("\n指令统计:")
    if not stats.inst_counts:
        print("  无有效指令数据")
    else:
        # 三级排序：平均周期↓ → 指令数量↓ → 指令名称↑
        sorted_insts = sorted(stats.inst_counts.keys(),
            key=lambda x: (-inst_avg_cycles[x],
                            -stats.inst_counts[x],
                            x.lower()))
        for inst in sorted_insts:
            count = stats.inst_counts[inst]
            percentage = inst_percentage[inst]
            avg_cycles = inst_avg_cycles[inst]
            # 模拟优化2倍，Amdahl's law公式计算的收益
            # amdahl_s_law = 1 / (1-percentage/100.0 + percentage/100.0/2)
            print(f"  {inst}: {avg_cycles:.1f} | {count} ({percentage:.1f}%)")
    print(f"指令总周期：{stats.total_cycles:.0f}")
    print(f"指令总数：{stats.total_instructions:.0f}")
    print(f"IPC：{(stats.total_instructions/stats.total_cycles):.3f}")

    # .format(stats['total_instructions'])

    # print("\n执行单元使用统计:")
    # print(f"  EXU使用次数: {stats['exec_unit_usage']['EXU']}")
    # print(f"  LSU使用次数: {stats['exec_unit_usage']['LSU']}")

    print("\n阶段延迟统计:")
    if not stats.stage_delays:
        print("  无有效阶段延迟数据")
    else:
        # 按平均延迟从大到小排序，若相同则按阶段名称排序
        sorted_stages = sorted(stats.stage_delays.items(),
            key=lambda item: (-sum(item[1])/len(item[1]) if item[1] else 0, item[0]))
        for stage, delays in sorted_stages:
            avg_delay = sum(delays)/len(delays) if delays else 0
            print(f"  {stage}: {avg_delay:.1f} | {len(delays)}")

def main():
    if len(sys.argv) != 2:
        print(f"用法: {sys.argv[0]} <日志文件>", file=sys.stderr)
        sys.exit(1)
    
    # 解析日志并进行统计
    parse_binary_log(sys.argv[1])
    
    # 打印统计结果
    print(f"\n分析结果 (文件: {sys.argv[1]})")
    print_stats()

if __name__ == "__main__":
    main()
