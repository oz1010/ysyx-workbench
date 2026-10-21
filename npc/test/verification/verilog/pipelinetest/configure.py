#!/usr/bin/env python3
"""Render local formal jobs and a reproducibility manifest; never rewrite RTL."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

PROJECT = Path(__file__).resolve().parent
NPC = PROJECT.parents[3]
COMMON = ["riscv32e_defines.v", "gprs.v", "csrs.v"]
REFERENCE = ["inst_decode_sc.v", "write_back_sc.v", "riscv32e_core_sc.v"]
DUT = ["Ifu.v", "Idu.v", "Exu.v", "Lsu.v", "Wbu.v", "GprFile.v",
       "CsrFile.v", "HazardUnit.v", "ResetPcGetter.v", "riscv32e_core.v"]
HARNESS = ["instruction_sequence.sv", "formal_env.sv", "ref_monitor.sv",
           "dut_monitor.sv", "event_scoreboard.sv", "pipelinetest.sv"]


def sources():
    return ([NPC / "vsrc/core/common" / name for name in COMMON]
            + [NPC / "vsrc/core/single" / name for name in REFERENCE]
            + [NPC / "vsrc/core/pipeline-chisel" / name for name in DUT]
            + [PROJECT / name for name in HARNESS])


def tool_version(tool, argument):
    executable = shutil.which(tool)
    if not executable:
        return {"path": None, "version": "unavailable"}
    try:
        result = subprocess.run([executable, argument], text=True,
                                capture_output=True, timeout=10, check=False)
        return {"path": executable,
                "version": (result.stdout + result.stderr).strip()[:2000]}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"path": executable, "version": str(error)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", default="build")
    parser.add_argument("--n", type=int, default=5)
    parser.add_argument("--depth", type=int, default=40)
    parser.add_argument("--cover-depth", type=int, default=120)
    parser.add_argument("--max-cycles", type=int, default=96)
    parser.add_argument("--max-wait", type=int, default=2)
    parser.add_argument("--mem-bytes", type=int, default=16)
    parser.add_argument("--solver", default="boolector")
    parser.add_argument("--selftest-depth", type=int, default=16)
    args = parser.parse_args()
    build = (PROJECT / args.build).resolve()
    if build == PROJECT or PROJECT not in build.parents:
        parser.error("build directory must be strictly inside this project")
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.solver):
        parser.error("solver must be a solver name, not a shell command")
    if (args.n < 1 or args.depth < 1 or args.cover_depth < 1
            or args.max_cycles <= args.n + 3 or args.max_wait < 0
            or args.mem_bytes < 4 or args.mem_bytes % 4
            or args.selftest_depth < 14):
        parser.error("invalid window, depth, timeout, memory size or latency")
    build.mkdir(parents=True, exist_ok=True)
    rtl = sources()
    extra = [PROJECT / "pipeline_types.svh", NPC / "include/generated/autoconf.vh"]
    controls = [PROJECT / name for name in
                ["configure.py", "report.py", "Makefile", "verify.sby", "selftest.sby",
                 "scoreboard_selftest.sv", "README.md", ".gitignore"]]
    for path in rtl + extra + controls:
        if not path.is_file():
            parser.error(f"missing input: {path}")
        if any(character.isspace() for character in str(path)):
            parser.error("SBY input paths containing whitespace are unsupported")
    # The shared header declares an unused zero-argument macro using () which
    # Slang rejects. Normalize only that declaration in a build-local copy;
    # original RTL is read-only and its original hash remains in the manifest.
    defines = rtl[0].read_text()
    old_macro = "`define EXPT_EXU_ILL()"
    if defines.count(old_macro) != 1:
        parser.error("shared header changed: review the local macro compatibility rule")
    if any("`EXPT_EXU_ILL" in p.read_text() for p in rtl[1:]):
        parser.error("EXPT_EXU_ILL is now used: review macro compatibility before running")
    staged_defines = build / "riscv32e_defines.v"
    staged_defines.write_text(defines.replace(old_macro, "`define EXPT_EXU_ILL"))
    compiled_rtl = [staged_defines] + rtl[1:]
    # REF chains a slice of an already sliced vector, rejected by Slang.
    # Flatten exactly the three decoder field selects, preserving the width.
    decoder_index = next(i for i, p in enumerate(rtl) if p.name == "inst_decode_sc.v")
    decoder = rtl[decoder_index].read_text()
    for high, low in [(11, 7), (19, 15), (24, 20)]:
        old = f"inst[{high}:{low}][0 +: `RISCV_GPR_ADDR_W]"
        if decoder.count(old) != 1:
            parser.error("REF decoder changed: review local slice compatibility rules")
        decoder = decoder.replace(old, f"inst[{low} +: `RISCV_GPR_ADDR_W]")
    staged_decoder = build / "inst_decode_sc.v"
    staged_decoder.write_text(decoder)
    compiled_rtl[decoder_index] = staged_decoder
    files = [f"{path.name} {path}" for path in compiled_rtl]
    files += [f"pipeline_types.svh {extra[0]}", f"generated/autoconf.vh {extra[1]}",
              f"manifest.json {build / 'manifest.json'}"]
    base = ("read_slang --single-unit --allow-use-before-declare "
            "-D FORMAL -D FORMAL_VERIFY -D SYNTHESIS -I. --top pipelinetest "
            f"-G N={args.n} -G MAX_CYCLES={args.max_cycles} "
            f"-G MAX_WAIT={args.max_wait} -G MEM_BYTES={args.mem_bytes} ")
    scripts = []
    for mode, with_mem, stall in [("alu", 0, 0), ("mem", 1, 0), ("stall", 1, 1)]:
        for kind in ["bmc", "progress", "cvr"]:
            command = base + f"-G WITH_MEM={with_mem} -G STALL={stall} "
            if kind == "progress":
                command += "-D CHECK_PROGRESS "
            scripts.append(f"{mode}_{kind}: {command}" + " ".join(p.name for p in rtl))
    substitutions = {
        "NPC_HOME": str(NPC), "PROJECT_DIR": str(PROJECT),
        "DEPTH": str(args.depth), "CVR_DEPTH": str(args.cover_depth),
        # Three reset edges, timeout edge, and assertion sampling margin.
        "PROGRESS_DEPTH": str(args.max_cycles + 8),
        "SOLVER": args.solver, "SELFTEST_DEPTH": str(args.selftest_depth),
        "TASK_SCRIPTS": "\n".join(scripts), "FILES": "\n".join(files),
    }
    for name in ["verify.sby", "selftest.sby"]:
        content = (PROJECT / name).read_text()
        for key, value in substitutions.items():
            content = content.replace(f"@{key}@", value)
        if re.search(r"@[A-Z_]+@", content):
            parser.error(f"unresolved placeholder in {name}")
        (build / name).write_text(content)
    # This frontend-only job is independent of solver/DUT correctness.
    (build / "elaborate.ys").write_text(
        "plugin -i slang\n" + base
        + "-G WITH_MEM=1 -G STALL=1 -D CHECK_PROGRESS "
        + " ".join(str(p) for p in compiled_rtl)
        + f" -I{build} -I{PROJECT} -I{NPC / 'include'}\n"
        + "prep -top pipelinetest\ncheck -assert\n")
    manifest = {
        "parameters": vars(args), "progress_depth": args.max_cycles + 8,
        "tools": {tool: tool_version(tool, flag) for tool, flag in
                  [("yosys", "-V"), ("sby", "--version"), (args.solver, "--version")]},
        "inputs": {str(p.relative_to(NPC)): hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in rtl + extra + controls},
        "generated": {name: hashlib.sha256((build / name).read_bytes()).hexdigest()
                      for name in ["verify.sby", "selftest.sby", "elaborate.ys",
                                   "riscv32e_defines.v", "inst_decode_sc.v"]},
    }
    (build / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Generated jobs and source/tool manifest in {build}")


if __name__ == "__main__":
    main()
