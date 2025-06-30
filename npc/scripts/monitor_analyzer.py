#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
分析monitor性能监控数据
格式如下：
155|1|IFU 156|1|IDU 156|2|ADDI 157|1|EXU 157|1|WBU
312|1|IFU 313|1|IDU 313|2|AUIPC 314|1|EXU 314|1|WBU
469|1|IFU 470|1|IDU 470|2|ADDI 471|1|EXU 471|1|WBU
用法: ./monitor_analyzer.py <FILE>
"""


import sys
from collections import defaultdict

def parse_log(log_lines):
    instructions = []
    current_inst = None
    start_tick = 0
    current_tick = 0
    
    for line in log_lines:
        entries = line.strip().split()
        for entry in entries:
            try:
                tick, entry_type, value = entry.split('|')
                tick = int(tick)
                current_tick += tick
                entry_type = int(entry_type)
                
                if entry_type == 1:  # 阶段记录
                    if value in ['IFU', 'IDU', 'EXU', 'LSU', 'WBU']:
                        if value == 'IFU':
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
                        else:
                            if current_inst is not None:
                                if value == 'EXU':
                                    if current_inst['has_lsu']:
                                        print(f"警告: 指令同时包含EXU和LSU阶段 (tick={current_tick})", file=sys.stderr)
                                    current_inst['has_exu'] = True
                                elif value == 'LSU':
                                    if current_inst['has_exu']:
                                        print(f"警告: 指令同时包含EXU和LSU阶段 (tick={current_tick})", file=sys.stderr)
                                    current_inst['has_lsu'] = True
                                
                                current_inst['stages'][value] = current_tick
                                current_inst['end_tick'] = current_tick
                                start_tick = current_tick
                    else:
                        print(f"警告: 未知的阶段类型: {value}", file=sys.stderr)
                elif entry_type == 2:  # 指令记录
                    if current_inst is not None:
                        current_inst['inst'] = value
            except ValueError as e:
                print(f"警告: 解析错误 '{entry}': {e}", file=sys.stderr)
    
    if current_inst is not None:
        instructions.append(current_inst)
    
    return instructions

def analyze_instructions(instructions):
    # 统计指令类型
    inst_counts = defaultdict(int)
    inst_cycles = defaultdict(list)
    
    # 统计各阶段延迟
    stage_delays = defaultdict(list)
    
    # 特殊统计：LSU指令的IDU到WBU延迟
    lsu_avg_delays = []
    
    # 执行单元使用情况
    exec_unit_usage = {'EXU': 0, 'LSU': 0}
    
    total_instructions = 0
    
    for inst in instructions:
        if inst['inst'] is None:
            continue
            
        total_instructions += 1
        inst_type = inst['inst']
        inst_counts[inst_type] += 1
        
        # 计算指令总周期
        cycles = inst['end_tick'] - inst['start_tick']
        inst_cycles[inst_type].append(cycles)
        
        # 记录执行单元使用情况
        if inst['has_exu']:
            exec_unit_usage['EXU'] += 1
        if inst['has_lsu']:
            exec_unit_usage['LSU'] += 1
            # 计算LSU指令的IDU到WBU延迟
            if 'IDU' in inst['stages'] and 'LSU' in inst['stages']:
                lsu_avg_delays.append(inst['stages']['LSU'] - inst['stages']['IDU'])
        
        # 计算各阶段延迟
        stages = inst['stages']
        if 'IFU' in stages:
            stage_delays['STR_IFU'].append(stages['IFU'] - inst['start_tick'])
        if 'IFU' in stages and 'IDU' in stages:
            stage_delays['IFU_IDU'].append(stages['IDU'] - stages['IFU'])
        if 'IDU' in stages:
            next_stage = 'EXU' if 'EXU' in stages else 'LSU' if 'LSU' in stages else None
            if next_stage:
                stage_delays[f'IDU_{next_stage}'].append(stages[next_stage] - stages['IDU'])
        if 'EXU' in stages and 'WBU' in stages:
            stage_delays['EXU_WBU'].append(stages['WBU'] - stages['EXU'])
        if 'LSU' in stages and 'WBU' in stages:
            stage_delays['LSU_WBU'].append(stages['WBU'] - stages['LSU'])
    
    # 计算指令比例和平均周期
    inst_percentage = {inst: (count/total_instructions)*100 for inst, count in inst_counts.items()}
    inst_avg_cycles = {inst: sum(cycles)/len(cycles) if cycles else 0 
                      for inst, cycles in inst_cycles.items()}
    
    # 计算LSU指令IDU到WBU平均延迟
    lsu_avg_idu_to_wbu = sum(lsu_avg_delays)/len(lsu_avg_delays) if lsu_avg_delays else 0
    
    return {
        'inst_counts': inst_counts,
        'inst_percentage': inst_percentage,
        'inst_avg_cycles': inst_avg_cycles,
        'stage_delays': stage_delays,
        'exec_unit_usage': exec_unit_usage,
        'lsu_avg_idu_to_wbu': lsu_avg_idu_to_wbu,
        'total_instructions': total_instructions
    }

def print_stats(stats):
    total_cycles = 0

    print("\n指令统计:")
    if not stats['inst_counts']:
        print("  无有效指令数据")
    else:
        # 三级排序：平均周期↓ → 指令数量↓ → 指令名称↑
        sorted_insts = sorted(stats['inst_counts'].keys(),
            key=lambda x: (-stats['inst_avg_cycles'][x],
                            -stats['inst_counts'][x],
                            x.lower()))
        for inst in sorted_insts:
            count = stats['inst_counts'][inst]
            percentage = stats['inst_percentage'][inst]
            avg_cycles = stats['inst_avg_cycles'][inst]
            total_cycles += avg_cycles * count
            # 模拟优化2倍，Amdahl's law公式计算的收益
            # amdahl_s_law = 1 / (1-percentage/100.0 + percentage/100.0/2)
            print(f"  {inst}: {avg_cycles:.1f} | {count} ({percentage:.1f}%)")
    print(f"指令总周期：{total_cycles:.0f}")
    print(f"指令总数：{stats['total_instructions']:.0f}")
    print(f"IPC：{(stats['total_instructions']/total_cycles):.3f}")

    # .format(stats['total_instructions'])

    # print("\n执行单元使用统计:")
    # print(f"  EXU使用次数: {stats['exec_unit_usage']['EXU']}")
    # print(f"  LSU使用次数: {stats['exec_unit_usage']['LSU']}")

    print("\n阶段延迟统计:")
    if not stats['stage_delays']:
        print("  无有效阶段延迟数据")
    else:
        # 按平均延迟从大到小排序，若相同则按阶段名称排序
        sorted_stages = sorted(stats['stage_delays'].items(),
            key=lambda item: (-sum(item[1])/len(item[1]) if item[1] else 0, item[0]))
        for stage, delays in sorted_stages:
            avg_delay = sum(delays)/len(delays) if delays else 0
            print(f"  {stage}: {avg_delay:.1f} | {len(delays)}")

def main():
    if len(sys.argv) != 2:
        print(f"用法: {sys.argv[0]} <日志文件>", file=sys.stderr)
        sys.exit(1)
    
    try:
        with open(sys.argv[1], 'r') as f:
            log_lines = f.readlines()
    except IOError as e:
        print(f"错误: 无法读取文件 '{sys.argv[1]}': {e}", file=sys.stderr)
        sys.exit(1)
    
    # 解析日志
    instructions = parse_log(log_lines)
    
    # 分析数据
    stats = analyze_instructions(instructions)
    
    # 打印统计结果
    print(f"\n分析结果 (文件: {sys.argv[1]})")
    print_stats(stats)

if __name__ == "__main__":
    main()
