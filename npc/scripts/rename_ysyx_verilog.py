#!/usr/bin/env python3
"""为 convert2v 生成的合并 Verilog 文件添加学号前缀。

默认用法: python3 scripts/rename_ysyx_verilog.py
指定文件: python3 scripts/rename_ysyx_verilog.py INPUT [-o OUTPUT] [--top TOP]
独立/SoC复位地址: 附加 --conditional-reset-pc
"""

import argparse
import os
import re
import sys
from pathlib import Path

IDENTIFIER = r"[A-Za-z_][A-Za-z0-9_$]*"
STUID_RE = re.compile(
    r"^[ \t]*STUID[ \t]*[:?+]?=[ \t]*(?:ysyx_)?(\d{8})[ \t]*(?:#.*)?$",
    re.MULTILINE,
)
MODULE_RE = re.compile(
    rf"^[ \t]*module[ \t]+(?:automatic[ \t]+)?({IDENTIFIER})",
    re.MULTILINE,
)
DEFINE_RE = re.compile(rf"^[ \t]*`define[ \t]+({IDENTIFIER})", re.MULTILINE)


def mask_non_code(text):
    masked = list(text)
    length = len(text)
    i = 0

    while i < length:
        if text.startswith("//", i):
            end = text.find("\n", i + 2)
            end = length if end == -1 else end
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            end = length if end == -1 else end + 2
        elif text[i] == '"':
            end = i + 1
            while end < length:
                if text[end] == "\\":
                    end += 2
                elif text[end] == '"':
                    end += 1
                    break
                else:
                    end += 1
        else:
            i += 1
            continue

        for j in range(i, min(end, length)):
            if text[j] not in "\r\n":
                masked[j] = " "
        i = end

    return "".join(masked)


def read_student_id(makefile):
    content = makefile.read_text(encoding="utf-8")
    match = STUID_RE.search(content)
    if not match:
        raise ValueError(f"无法从 {makefile} 提取 8 位学号（STUID）")
    return match.group(1)


def rename_verilog(text, student_id, top_module):
    masked = mask_non_code(text)
    module_names = set(MODULE_RE.findall(masked))
    if top_module not in module_names:
        raise ValueError(f"找不到顶层模块 {top_module}")

    macro_names = set(DEFINE_RE.findall(masked))
    module_prefix = f"ysyx_{student_id}_"
    macro_prefix = module_prefix
    module_map = {name: module_prefix + name for name in module_names}
    module_map[top_module] = f"ysyx_{student_id}"
    module_alternation = "|".join(
        re.escape(name) for name in sorted(module_names, key=len, reverse=True)
    )
    token_re = re.compile(
        rf"(?P<directive>^[ \t]*`(?:define|ifdef|ifndef|elsif|undef)[ \t]+)"
        rf"(?P<directive_macro>{IDENTIFIER})"
        rf"|`(?P<reference_macro>{IDENTIFIER})"
        rf"|(?<![A-Za-z0-9_$`])(?P<module>{module_alternation})"
        rf"(?![A-Za-z0-9_$])",
        re.MULTILINE,
    )

    result = []
    last = 0
    module_replacements = 0
    macro_replacements = 0

    for match in token_re.finditer(masked):
        directive_macro = match.group("directive_macro")
        reference_macro = match.group("reference_macro")
        module_name = match.group("module")

        if directive_macro is not None:
            if directive_macro not in macro_names:
                continue
            replacement = match.group("directive") + macro_prefix + directive_macro
            macro_replacements += 1
        elif reference_macro is not None:
            if reference_macro not in macro_names:
                continue
            replacement = "`" + macro_prefix + reference_macro
            macro_replacements += 1
        else:
            replacement = module_map[module_name]
            module_replacements += 1

        result.append(text[last:match.start()])
        result.append(replacement)
        last = match.end()

    result.append(text[last:])
    return "".join(result), {
        "modules": len(module_names),
        "macros": len(macro_names),
        "module_replacements": module_replacements,
        "macro_replacements": macro_replacements,
    }


def configure_reset_pc(text, student_id):
    macro = f"YSYX_{student_id}_RESET_PC"
    patterns = (
        rf"(\bfunc_get_reset_pc\s*=\s*)32'h[0-9a-fA-F_]+(\s*;)",
        rf"(\bassign\s+reset_pc\s*=\s*)32'h[0-9a-fA-F_]+(\s*;)",
    )
    for pattern in patterns:
        text, count = re.subn(pattern, rf"\1`{macro}\2", text)
        if count != 1:
            raise ValueError(f"复位地址赋值匹配数量应为 1，实际为 {count}")
    definitions = (
        "`ifdef YSYX_SOC\n"
        f"`define {macro} 32'h30000000\n"
        "`else\n"
        f"`define {macro} 32'h80000000\n"
        "`endif\n\n"
    )
    return definitions + text


def main():
    default_input = Path(__file__).resolve().parent.parent / "build/yosys/ysyxSoCFull.v"
    parser = argparse.ArgumentParser(
        description="从 $YSYX_HOME/Makefile 提取学号，重命名合并 Verilog 的顶层、模块和宏。"
    )
    parser.add_argument("input", nargs="?", type=Path, default=default_input)
    parser.add_argument("-o", "--output", type=Path, help="默认输出到输入文件所在目录")
    parser.add_argument("--top", default="ysyxSoCFull", help="原始顶层模块名")
    parser.add_argument(
        "--conditional-reset-pc",
        action="store_true",
        help="保留 YSYX_SOC=0x30000000、独立仿真=0x80000000 的复位地址选择",
    )
    args = parser.parse_args()

    try:
        ysyx_home = os.environ.get("YSYX_HOME")
        if not ysyx_home:
            raise ValueError("环境变量 YSYX_HOME 未设置")
        student_id = read_student_id(Path(ysyx_home).expanduser() / "Makefile")

        input_path = args.input
        output_path = args.output or input_path.with_name(f"ysyx_{student_id}.v")
        if input_path.resolve() == output_path.resolve():
            raise ValueError("输出文件不能覆盖输入文件")

        with input_path.open("r", encoding="utf-8", newline="") as source:
            content = source.read()
        converted, stats = rename_verilog(content, student_id, args.top)
        if args.conditional_reset_pc:
            converted = configure_reset_pc(converted, student_id)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with output_path.open("w", encoding="utf-8", newline="") as target:
            target.write(converted)
    except (OSError, ValueError) as error:
        print(f"错误: {error}", file=sys.stderr)
        return 1

    print(f"学号: {student_id}")
    print(f"输出: {output_path}")
    print(f"顶层模块: {args.top} -> ysyx_{student_id}")
    print(
        f"模块: {stats['modules']} 个，替换 {stats['module_replacements']} 处；"
        f"宏: {stats['macros']} 个，替换 {stats['macro_replacements']} 处"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
