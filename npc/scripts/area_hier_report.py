#!/usr/bin/env python3
"""解析 yosys `stat -liberty` 的层级统计结果, 按模块/流水线阶段汇总面积。

用法: area_hier_report.py stat_hier.txt [--csv area_hier.csv]

输入为 scripts/yosys_area_hier.tcl 的输出 (保留层级的 stat -liberty):
  - 每个模块一段 "=== name ===" + "Chip area for module"
  - 末尾 "=== design hierarchy ===" 树带每个特化模块的实例数
面积单位与 liberty 一致 (Nangate45 为 um^2)。synth 会把参数化模块特化成
$paramod$<hash>\\<name> / $paramod\\<name>\\<PARAM=...> 形式, 这里归一化成
原始模块名后聚合; 实例数从 design hierarchy 树累计。
"""

import argparse
import csv
import re
import sys

AREA_RE = re.compile(r"Chip area for module '(.*)': ([\d.]+)$")
SEQ_RE = re.compile(r"of which used for sequential elements: ([\d.]+)")
HIER_RE = re.compile(r"^(\s*)(\S+)\s+(\d+)\s*$")
PARAMOD_RE = re.compile(r"^\$paramod(?:\$[0-9a-f]+)?\\+([^\\]+)")

# riscv32e_core 各子树包含的模块 (流水线各阶段)
GROUPS = {
    "IF": ["inst_fetch", "icache", "static_predictor"],
    "ID": ["inst_decode", "risk_control", "risk_raw"],
    "EX": ["execute", "ex_muldivrem", "ex_muldivrem_multi"],
    "MEM": ["load_store", "dcache"],
    "WB": ["write_back"],
    "CSR": ["csrs", "trigger"],
    "GPR": ["gprs"],
    "流水线寄存器": ["stage_regs"],
    "总线/SoC": [
        "xbar_axi4", "arbiter_axi4", "axi_master_reader", "axi_master_writer",
        "axi4_salve_reader", "axi4_salve_writer", "exter_dev", "clint",
        "inner_con", "scom", "cache", "cache_block", "cache_line", "lfsr",
        "perf_monitor",
    ],
    "顶层连线": ["ysyxSoCFull", "ysyx_23060295", "riscv32e_core"],
}


def base_name(name):
    name = name.lstrip("\\")
    m = PARAMOD_RE.match(name)
    return m.group(1) if m else name


def parse_stat(path):
    # spec_name -> {area, seq};  design hierarchy 树中的实例数
    modules = {}
    inst_counts = {}
    cur = None
    in_hier = False
    with open(path) as f:
        for line in f:
            m = re.match(r"^=== (.+) ===$", line.strip())
            if m:
                name = m.group(1)
                if name == "design hierarchy":
                    in_hier = True
                    cur = None
                else:
                    in_hier = False
                    cur = name
                    modules[cur] = {"area": 0.0, "seq": 0.0}
                continue
            if in_hier:
                hm = HIER_RE.match(line.rstrip("\n"))
                if hm:
                    spec = hm.group(2).lstrip("\\")
                    inst_counts[spec] = inst_counts.get(spec, 0) + int(hm.group(3))
                continue
            if cur is None:
                continue
            am = AREA_RE.search(line)
            if am and am.group(1).lstrip("\\") == cur.lstrip("\\"):
                modules[cur]["area"] = float(am.group(2))
                continue
            sm = SEQ_RE.search(line)
            if sm:
                modules[cur]["seq"] = float(sm.group(1))
    return modules, inst_counts


def group_of(base):
    for g, names in GROUPS.items():
        if base in names:
            return g
    return "其他"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("stat")
    ap.add_argument("--csv", default=None)
    args = ap.parse_args()

    modules, inst_counts = parse_stat(args.stat)
    if not modules:
        sys.exit("no module stats parsed, check input file")

    # 按原始模块名聚合所有特化版本: area_total = Σ area*instances
    agg = {}
    for spec, st in modules.items():
        b = base_name(spec)
        inst = inst_counts.get(spec, 1)
        a = agg.setdefault(b, {"area": 0.0, "seq": 0.0, "inst": 0})
        a["area"] += st["area"] * inst
        a["seq"] += st["seq"] * inst
        a["inst"] += inst

    rows = [
        {"module": b, "group": group_of(b), "inst": a["inst"], "area": a["area"], "seq": a["seq"]}
        for b, a in agg.items()
    ]
    rows.sort(key=lambda r: -r["area"])
    total = sum(r["area"] for r in rows)

    groups = {}
    for r in rows:
        g = groups.setdefault(r["group"], 0.0)
        groups[r["group"]] = g + r["area"]

    print(f"{'group':<10} {'area':>10} {'pct':>7}")
    for g, v in sorted(groups.items(), key=lambda kv: -kv[1]):
        print(f"{g:<10} {v:>10.1f} {100*v/total:>6.1f}%")
    print(f"{'TOTAL':<10} {total:>10.1f}   (flat 流程 ysyxSoCFull 为 48023.6, 供参考)")
    print()
    print(f"{'module':<24} {'group':<10} {'inst':>4} {'area':>10} {'seq':>10} {'pct':>6}")
    for r in rows:
        print(f"{r['module']:<24} {r['group']:<10} {r['inst']:>4} {r['area']:>10.1f} {r['seq']:>10.1f} {100*r['area']/total:>5.1f}%")

    if args.csv:
        with open(args.csv, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=["module", "group", "inst", "area", "seq", "pct"])
            w.writeheader()
            for r in rows:
                w.writerow({**r, "pct": f"{100*r['area']/total:.2f}"})
        print(f"\ncsv written to {args.csv}")


if __name__ == "__main__":
    main()
