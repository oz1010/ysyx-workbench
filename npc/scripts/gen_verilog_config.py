#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
C语言头文件转Verilog头文件转换工具
用法: ./gen_verilog_config.py <FILE> -o [OUTPUT_PATH]
示例: ./gen_verilog_config.py autoconf.h
"""

import re
import os
import argparse
from pathlib import Path

HEADER_COMMENT = """/*
 *
 * Automatically generated file; DO NOT EDIT.
 * Using in verilog
 *
 */

"""

def convert_file(input_path, output_path):
    """转换单个文件"""
    with open(input_path, 'r', encoding='utf-8') as f_in, \
         open(output_path, 'w', encoding='utf-8') as f_out:
        f_out.write(HEADER_COMMENT)
        for line in f_in:
            line = line.strip()
            if not line or line.startswith(('//', '/*')):
                continue
                
            match = re.match(r'#define\s+(\w+)\s+(.+)', line)
            if match:
                name, value = match.groups()
                if re.match(r'0x[0-9a-fA-F]+', value):
                    value = f"32'h{value[2:]}"
                f_out.write(f"`define {name} {value}\n")

def main():
    parser = argparse.ArgumentParser(
        description='批量转换C头文件到Verilog头文件',
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        'input_files', 
        nargs='+',
        help='输入的头文件(.h)，支持通配符如*.h')
    parser.add_argument(
        '-o', '--output',
        help='输出目录路径（默认同输入文件目录）')
    args = parser.parse_args()
    if args.output and not os.path.exists(args.output):
        os.makedirs(args.output, exist_ok=True)
    for input_file in args.input_files:
        # 生成输出路径
        input_path = Path(input_file)
        output_name = input_path.stem + '.vh'
        if args.output:
            output_path = Path(args.output) / output_name
        else:
            output_path = input_path.with_suffix('.vh')
        # 执行转换
        convert_file(input_file, str(output_path))
        # print(f"Converted: {input_file} -> {output_path}")

if __name__ == "__main__":
    main()
