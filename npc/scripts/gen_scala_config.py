#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Generate a Scala configuration object from Kconfig, optional .config,
and an optional user-specified C header.

Python standard library only. No kconfiglib dependency.

Priority:
    Kconfig defaults
    < same-directory .config
    < explicitly specified .h

Usage:
    python3 scripts/gen_scala_config.py
    python3 scripts/gen_scala_config.py path/to/Kconfig
    python3 scripts/gen_scala_config.py path/to/Kconfig --header path/to/config.h
    python3 scripts/gen_scala_config.py path/to/Kconfig --output AutoConfig.scala
    python3 scripts/gen_scala_config.py path/to/Kconfig --package config

Supported Kconfig features:
    config, menuconfig
    bool, boolean, tristate, string, int, hex
    default, depends on, visible if
    if/endif, menu/endmenu
    source, rsource
    Basic logical and comparison expressions

Scala type mapping:
    bool -> Boolean, tristate/string -> String
    int -> Int literal in decimal
        (BigInt fallback when outside the 32-bit range)
    hex -> chisel UInt literal (0x0040_0000.U), zero-padded to at
        least 8 hex digits; no width limit (UInt supports wide values)

Limitations:
    This is a lightweight Kconfig interpreter, not a complete replacement
    for the official Kconfig implementation. In particular, choice,
    select/imply, range constraints, and full tristate visibility semantics
    are not implemented.
"""

import argparse
import ast
import glob
import json
import os
import re
import sys

from dataclasses import dataclass, field
from pathlib import Path


# ----------------------------------------------------------------------
# Data structures
# ----------------------------------------------------------------------

@dataclass
class Symbol:
    name: str
    type: str = "unknown"
    depends: list = field(default_factory=list)
    defaults: list = field(default_factory=list)
    prompt_conditions: list = field(default_factory=list)
    declared: bool = False


@dataclass
class KconfigModel:
    symbols: dict = field(default_factory=dict)
    warnings: list = field(default_factory=list)
    parsed_files: set = field(default_factory=set)


# ----------------------------------------------------------------------
# General helpers
# ----------------------------------------------------------------------

def warn(model, message):
    model.warnings.append(message)


def strip_comment(line):
    """Remove a Kconfig comment outside quoted strings."""
    quoted = False
    escaped = False

    for i, ch in enumerate(line):
        if escaped:
            escaped = False
            continue

        if ch == "\\" and quoted:
            escaped = True
            continue

        if ch == '"':
            quoted = not quoted
        elif ch == "#" and not quoted:
            return line[:i]

    return line


def split_if_expression(text):
    """Split 'value if condition' outside strings and parentheses."""
    quoted = False
    escaped = False
    depth = 0
    i = 0

    while i < len(text):
        ch = text[i]

        if escaped:
            escaped = False
            i += 1
            continue

        if ch == "\\" and quoted:
            escaped = True
            i += 1
            continue

        if ch == '"':
            quoted = not quoted
        elif not quoted:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            elif depth == 0 and text[i:i + 4] == " if ":
                return text[:i].strip(), text[i + 4:].strip()

        i += 1

    return text.strip(), None


def unquote(value):
    value = value.strip()

    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        try:
            return ast.literal_eval(value)
        except (ValueError, SyntaxError):
            return value[1:-1]

    return value


def parse_scalar(value):
    value = value.strip()

    if value.startswith('"') and value.endswith('"'):
        return unquote(value)

    if value in ("y", "m", "n"):
        return value

    try:
        if value.lower().startswith("0x"):
            return int(value, 16)
        if value.lower().startswith("0b"):
            return int(value, 2)
        if len(value) > 1 and value.startswith("0") and value.isdigit():
            return int(value, 8)
        return int(value, 10)
    except ValueError:
        return value


# ----------------------------------------------------------------------
# Expression parser
# ----------------------------------------------------------------------

TOKEN_RE = re.compile(
    r'"(?:\\.|[^"\\])*"'
    r"|&&|\|\||!=|==|<=|>="
    r"|[()!<>]"
    r"|[A-Za-z_][A-Za-z0-9_./+-]*"
    r"|[0-9]+"
)


class ExpressionParser:
    """
    Small expression evaluator.

    Precedence:
        !
        comparisons
        &&
        ||
    """

    def __init__(self, expression, values):
        self.expression = expression.strip()
        self.values = values
        self.tokens = TOKEN_RE.findall(self.expression)
        self.pos = 0

        joined = "".join(self.tokens)
        compact = re.sub(r"\s+", "", self.expression)

        if joined != compact:
            raise ValueError(
                f"Unsupported expression syntax: {self.expression}"
            )

    def peek(self):
        if self.pos >= len(self.tokens):
            return None
        return self.tokens[self.pos]

    def take(self, expected=None):
        token = self.peek()

        if token is None:
            raise ValueError("Unexpected end of expression")

        if expected is not None and token != expected:
            raise ValueError(
                f"Expected {expected!r}, got {token!r}"
            )

        self.pos += 1
        return token

    def parse(self):
        if not self.tokens:
            return True

        result = self.parse_or()

        if self.peek() is not None:
            raise ValueError(
                f"Unexpected token {self.peek()!r}"
            )

        return result

    def parse_or(self):
        value = self.parse_and()

        while self.peek() == "||":
            self.take()
            right = self.parse_and()
            value = self.truth(value) or self.truth(right)

        return value

    def parse_and(self):
        value = self.parse_compare()

        while self.peek() == "&&":
            self.take()
            right = self.parse_compare()
            value = self.truth(value) and self.truth(right)

        return value

    def parse_compare(self):
        left = self.parse_unary()

        if self.peek() in ("=", "==", "!=", "<", ">", "<=", ">="):
            op = self.take()
            right = self.parse_unary()

            a = self.comparable(left)
            b = self.comparable(right)

            if op in ("=", "=="):
                return a == b
            if op == "!=":
                return a != b
            if op == "<":
                return a < b
            if op == ">":
                return a > b
            if op == "<=":
                return a <= b
            if op == ">=":
                return a >= b

        return left

    def parse_unary(self):
        if self.peek() == "!":
            self.take()
            return not self.truth(self.parse_unary())

        if self.peek() == "(":
            self.take()
            value = self.parse_or()
            self.take(")")
            return value

        token = self.take()

        if token.startswith('"'):
            return unquote(token)

        if token in ("y", "m", "n"):
            return token

        try:
            return int(token, 0)
        except ValueError:
            pass

        return self.values.get(token, "n")

    @staticmethod
    def truth(value):
        if isinstance(value, bool):
            return value
        if isinstance(value, int):
            return value != 0
        return value in ("y", "m", "true", "1")

    @staticmethod
    def comparable(value):
        if isinstance(value, (bool, int)):
            return value
        if isinstance(value, str):
            try:
                return int(value, 0)
            except ValueError:
                return value
        return value


def eval_expr(expression, values, model=None, context=""):
    if not expression:
        return True

    try:
        return ExpressionParser(expression, values).parse()
    except (ValueError, TypeError) as exc:
        if model is not None:
            warn(
                model,
                f"Unsupported expression {expression!r}"
                f"{' in ' + context if context else ''}: {exc}"
            )
        return False


# ----------------------------------------------------------------------
# Kconfig parser
# ----------------------------------------------------------------------

def resolve_source_pattern(pattern, current_file, root_dir, recursive):
    pattern = unquote(pattern)

    if pattern.startswith("$srctree/"):
        pattern = str(root_dir / pattern[len("$srctree/"):])
    elif pattern.startswith("$(srctree)/"):
        pattern = str(root_dir / pattern[len("$(srctree)/"):])
    elif not os.path.isabs(pattern):
        base = current_file.parent if recursive else root_dir
        pattern = str(base / pattern)

    return sorted(Path(p).resolve() for p in glob.glob(pattern))


def parse_kconfig_file(path, model, root_dir, conditions=None):
    path = Path(path).resolve()
    conditions = list(conditions or [])

    if path in model.parsed_files:
        return

    if not path.is_file():
        warn(model, f"Kconfig file not found: {path}")
        return

    model.parsed_files.add(path)

    try:
        lines = path.read_text(encoding="utf-8-sig").splitlines()
    except OSError as exc:
        warn(model, f"Cannot read {path}: {exc}")
        return

    current = None
    # Entries are (kind, expression). if/endif and menu/endmenu
    # use the same condition stack.
    context_stack = []
    menu_depends = []

    def active_conditions():
        return conditions + [
            expr for kind, expr in context_stack
            if expr
        ] + menu_depends

    def combined(extra=None):
        items = active_conditions()
        if extra:
            items.append(extra)
        return " && ".join(f"({x})" for x in items if x) or "y"

    for line_no, original in enumerate(lines, 1):
        line = strip_comment(original).strip()

        if not line:
            continue

        try:
            if line.startswith(("config ", "menuconfig ")):
                name = line.split(None, 1)[1].strip()

                if not re.fullmatch(r"[A-Za-z0-9_]+", name):
                    warn(model, f"{path}:{line_no}: invalid symbol {name!r}")
                    current = None
                    continue

                current = model.symbols.setdefault(name, Symbol(name))
                current.declared = True
                continue

            if line == "if" or line.startswith("if "):
                expression = line[2:].strip()
                context_stack.append(("if", expression))
                current = None
                continue

            if line == "endif" or line.startswith("endif "):
                for i in range(len(context_stack) - 1, -1, -1):
                    if context_stack[i][0] == "if":
                        del context_stack[i:]
                        break
                else:
                    warn(model, f"{path}:{line_no}: unmatched endif")
                current = None
                continue

            if line.startswith("menu "):
                context_stack.append(("menu", ""))
                current = None
                continue

            if line == "endmenu":
                for i in range(len(context_stack) - 1, -1, -1):
                    if context_stack[i][0] == "menu":
                        del context_stack[i:]
                        break
                current = None
                continue

            if line.startswith(("source ", "rsource ")):
                recursive = line.startswith("rsource ")
                pattern = line.split(None, 1)[1].strip()

                for included in resolve_source_pattern(
                    pattern, path, root_dir, recursive
                ):
                    parse_kconfig_file(
                        included,
                        model,
                        root_dir,
                        active_conditions(),
                    )

                current = None
                continue

            if line.startswith(("osource ", "orsource ")):
                recursive = line.startswith("orsource ")
                pattern = line.split(None, 1)[1].strip()

                for included in resolve_source_pattern(
                    pattern, path, root_dir, recursive
                ):
                    parse_kconfig_file(
                        included,
                        model,
                        root_dir,
                        active_conditions(),
                    )

                current = None
                continue

            if line.startswith("choice"):
                warn(
                    model,
                    f"{path}:{line_no}: choice blocks are not fully supported"
                )
                current = None
                continue

            if line == "endchoice":
                current = None
                continue

            if line.startswith(("comment ", "mainmenu ", "help")):
                current = None
                continue

            # Symbol properties
            if current is not None:
                if line.startswith(("bool", "boolean")):
                    current.type = "bool"
                    continue

                if line.startswith("tristate"):
                    current.type = "tristate"
                    continue

                if line.startswith("string"):
                    current.type = "string"
                    continue

                if line.startswith("int"):
                    current.type = "int"
                    continue

                if line.startswith("hex"):
                    current.type = "hex"
                    continue

                if line.startswith("depends on "):
                    current.depends.append(
                        combined(line[len("depends on "):])
                    )
                    continue

                if line.startswith("visible if "):
                    current.prompt_conditions.append(
                        combined(line[len("visible if "):])
                    )
                    continue

                if line.startswith("default "):
                    value, condition = split_if_expression(
                        line[len("default "):]
                    )
                    current.defaults.append((
                        value,
                        combined(condition),
                    ))
                    continue

                if line.startswith("def_bool "):
                    value, condition = split_if_expression(
                        line[len("def_bool "):]
                    )
                    current.type = "bool"
                    current.defaults.append((value, combined(condition)))
                    continue

                if line.startswith("def_tristate "):
                    value, condition = split_if_expression(
                        line[len("def_tristate "):]
                    )
                    current.type = "tristate"
                    current.defaults.append((value, combined(condition)))
                    continue

                if line.startswith(("select ", "imply ")):
                    warn(
                        model,
                        f"{path}:{line_no}: {line.split()[0]} "
                        "is not implemented"
                    )
                    continue

                if line.startswith("range "):
                    warn(
                        model,
                        f"{path}:{line_no}: range constraints "
                        "are not implemented"
                    )
                    continue

                if line.startswith("option "):
                    continue

                # Prompt-only properties, e.g. bool "Enable feature"
                if re.match(r'^(bool|boolean|tristate|string|int|hex)\s+"', line):
                    continue

            # Menu-level dependency
            if line.startswith("depends on ") and current is None:
                expression = line[len("depends on "):]
                if context_stack and context_stack[-1][0] == "menu":
                    menu_depends.append(expression)
                else:
                    warn(
                        model,
                        f"{path}:{line_no}: depends on outside a symbol/menu"
                    )
                continue

            if line.startswith("visible if "):
                continue

            # Unknown statements should not silently be treated as properties.
            if line.startswith(("config ", "menuconfig ")):
                continue

            if line in ("endmenu", "endif", "endchoice"):
                continue

        except (IndexError, ValueError) as exc:
            warn(model, f"{path}:{line_no}: {exc}")

    # The parser deliberately keeps diagnostics instead of failing on
    # every unfamiliar Kconfig construct.


# ----------------------------------------------------------------------
# .config and C header parsing
# ----------------------------------------------------------------------

CONFIG_RE = re.compile(r"^\s*CONFIG_([A-Za-z0-9_]+)=(.*)$")
NOT_SET_RE = re.compile(
    r"^\s*#\s*CONFIG_([A-Za-z0-9_]+)\s+is\s+not\s+set\s*$"
)

HEADER_DEFINE_RE = re.compile(
    r"^\s*#\s*define\s+"
    r"(CONFIG_[A-Za-z_][A-Za-z0-9_]*)"
    r"(?:\s+(.*?))?\s*$"
)


def read_config_file(path):
    result = {}

    if not path.is_file():
        return result

    for line in path.read_text(encoding="utf-8-sig").splitlines():
        match = CONFIG_RE.match(line)

        if match:
            name, raw = match.groups()
            result[name] = parse_scalar(raw)
            continue

        match = NOT_SET_RE.match(line)

        if match:
            result[match.group(1)] = "n"

    return result


def remove_c_comments(text):
    pattern = re.compile(
        r'"(?:\\.|[^"\\])*"'
        r"|'(?:\\.|[^'\\])*'"
        r"|/\*.*?\*/"
        r"|//[^\n]*",
        re.DOTALL,
    )

    def replace(match):
        value = match.group(0)
        if value.startswith(('"', "'")):
            return value
        if value.startswith("//"):
            return ""
        return "\n" * value.count("\n")

    return pattern.sub(replace, text)


def read_header(path):
    macros = {}
    warnings = []

    source = remove_c_comments(path.read_text(encoding="utf-8-sig"))

    for line_no, line in enumerate(source.splitlines(), 1):
        match = HEADER_DEFINE_RE.match(line)

        if not match:
            continue

        name, raw = match.groups()
        # name = name[len("CONFIG_"):]
        raw = (raw or "").strip()

        if not raw:
            macros[name] = "y"
            continue

        value = parse_scalar(raw)

        if isinstance(value, str) and value == raw:
            warnings.append(
                f"{path}:{line_no}: unsupported macro value "
                f"CONFIG_{name}={raw}"
            )
            continue

        macros[name] = value

    return macros, warnings


# ----------------------------------------------------------------------
# Configuration evaluation
# ----------------------------------------------------------------------

def normalize_value(symbol, value):
    kind = symbol.type

    if kind == "bool":
        if value in (True, 1, "y", "m", "true", "yes"):
            return "y"
        return "n"

    if kind == "tristate":
        if value in (True, 1, "y", "true", "yes"):
            return "y"
        if value == "m":
            return "m"
        return "n"

    if kind == "string":
        return str(value)

    if kind == "int":
        try:
            return str(int(str(value), 0))
        except ValueError:
            return "0"

    if kind == "hex":
        try:
            return hex(int(str(value), 0))
        except ValueError:
            return "0x0"

    return value


def value_for_expression(value):
    if value is None:
        return "n"
    return value


def evaluate_symbols(model, config_values, header_values):
    values = {
        name: "n"
        for name in model.symbols
    }

    # Apply defaults and overrides iteratively so that references to
    # other symbols can settle over several passes.
    overrides = dict(config_values)
    overrides.update(header_values)

    for _ in range(max(1, len(model.symbols) + 1)):
        changed = False

        for name, symbol in model.symbols.items():
            env = {
                key: value_for_expression(value)
                for key, value in values.items()
            }

            allowed = all(
                bool(eval_expr(dep, env, model, name))
                for dep in symbol.depends
            )

            value = None

            if name in overrides and allowed:
                value = overrides[name]
            else:
                for default, condition in symbol.defaults:
                    if eval_expr(condition, env, model, name):
                        if re.fullmatch(
                            r"[A-Za-z_][A-Za-z0-9_]*", default
                        ):
                            value = env.get(default, default)
                        else:
                            value = parse_scalar(default)
                        break

            if value is None:
                value = "n" if symbol.type in ("bool", "tristate") else ""

            value = normalize_value(symbol, value)

            if not allowed and symbol.type in ("bool", "tristate"):
                value = "n"

            if values.get(name) != value:
                values[name] = value
                changed = True

        if not changed:
            break

    return values


# ----------------------------------------------------------------------
# Scala generation
# ----------------------------------------------------------------------

INT32_MIN = -(2 ** 31)
INT32_MAX = 2 ** 31 - 1


def scala_hex(value):
    """Format an integer as a Scala-style hex literal (e.g. 0x0040_0000)."""
    if value < 0:
        return "-" + scala_hex(-value)

    # Zero-pad to at least 8 hex digits (32-bit); Scala UInt has no
    # width limit, so wider values are left unpadded.
    digits = format(value, "x").rjust(8, "0")
    head = len(digits) % 4 or 4
    groups = [digits[:head]]
    groups.extend(digits[i:i + 4] for i in range(head, len(digits), 4))
    return "0x" + "_".join(groups)


def scala_value(model, symbol, value):
    if symbol.type == "bool":
        return "boolean", value == "y"

    if symbol.type == "tristate":
        return "string", value

    if symbol.type == "int":
        try:
            number = int(value, 10)
        except (TypeError, ValueError):
            number = 0

        if INT32_MIN <= number <= INT32_MAX:
            return "int", number

        warn(
            model,
            f"{symbol.name}: value {number} is outside the 32-bit range; "
            "emitting BigInt instead of Int"
        )
        return "integer", number

    if symbol.type == "hex":
        try:
            return "hex", int(value, 16)
        except (TypeError, ValueError):
            return "hex", 0

    if symbol.type == "string":
        return "string", str(value)

    # Unknown Kconfig types are exposed as strings.
    return "string", str(value)


def scala_expr(kind, value):
    if kind == "boolean":
        return "true" if value else "false"

    if kind == "int":
        return str(value)

    if kind == "hex":
        return scala_hex(value) + ".U"

    if kind == "integer":
        return f'BigInt("{value}")'

    if kind == "string":
        return json.dumps(value, ensure_ascii=False)

    raise ValueError(f"Unsupported Scala value type: {kind}")


def scala_type(kind, value):
    if kind == "boolean":
        return "Boolean"

    if kind == "int":
        return "Int"

    if kind == "hex":
        return "UInt"

    return {
        "integer": "BigInt",
        "string": "String",
    }[kind]


def generate_scala(definitions, kconfig_names, header_names, package):
    lines = [
        "/*",
        " * Automatically generated file; DO NOT EDIT.",
        " * Source: Kconfig, optional .config and optional header.",
        " */",
        "",
        f"package {package}",
        "",
        "import chisel3._",
        "import chisel3.util._",
        "",
        "object AutoConfig {",
        "",
        "  val definedInHeader: Set[String] = Set(",
    ]

    for name in sorted(header_names):
        lines.append(f"    {json.dumps('CONFIG_' + name)},")

    lines.extend([
        "  )",
        "",
        "  val kconfigSymbols: Set[String] = Set(",
    ])

    for name in sorted(kconfig_names):
        lines.append(f"    {json.dumps('CONFIG_' + name)},")

    lines.extend([
        "  )",
        "",
        "  def isDefined(name: String): Boolean =",
        "    definedInHeader.contains(name)",
        "",
        "  def isKconfigSymbol(name: String): Boolean =",
        "    kconfigSymbols.contains(name)",
        "",
        "  val values: Map[String, Any] = Map(",
    ])

    for name, (kind, value) in sorted(definitions.items()):
        lines.append(
            f"    {json.dumps('CONFIG_' + name)} -> "
            f"{scala_expr(kind, value)},"
        )

    lines.extend([
        "  )",
        "",
        "  def isEnabled(name: String): Boolean =",
        "    values.get(name).exists {",
        "      case b: Boolean => b",
        '      case s: String => s == "y" || s == "m"',
        "      case n: BigInt => n != 0",
        "      case n: Int => n != 0",
        "      case n: UInt => n.litValue != 0",
        "      case _ => false",
        "    }",
        "",
    ])

    # Named constants for direct use from Scala/Chisel.
    for name, (kind, value) in sorted(definitions.items()):
        scala_name = "CONFIG_" + name
        lines.append(
            f"  val {scala_name}: {scala_type(kind, value)} = "
            f"{scala_expr(kind, value)}"
        )

    lines.extend(["}", ""])
    return "\n".join(lines)


# ----------------------------------------------------------------------
# Main conversion
# ----------------------------------------------------------------------

def convert(kconfig_path, header_path, output_path, package, silent):
    kconfig_path = kconfig_path.resolve()

    if not kconfig_path.is_file():
        raise FileNotFoundError(f"Kconfig not found: {kconfig_path}")

    root = kconfig_path.parent
    config_path = root / ".config"

    model = KconfigModel()
    parse_kconfig_file(kconfig_path, model, root)

    config_values = read_config_file(config_path)

    header_values = {}
    header_names = set()

    if header_path is not None:
        header_path = header_path.resolve()

        if not header_path.is_file():
            raise FileNotFoundError(f"Header not found: {header_path}")

        header_values, header_warnings = read_header(header_path)
        model.warnings.extend(header_warnings)
        header_names = set(header_values)

    values = evaluate_symbols(model, config_values, header_values)

    definitions = {}

    for name, symbol in sorted(model.symbols.items()):
        definitions[name] = scala_value(
            model, symbol, values.get(name, "n")
        )

    # Preserve header macros not declared in Kconfig.
    for name, value in header_values.items():
        if name in model.symbols:
            continue

        if isinstance(value, bool):
            definitions[name] = ("boolean", value)
        elif isinstance(value, int):
            definitions[name] = ("integer", value)
        else:
            definitions[name] = ("string", str(value))

    scala_source = generate_scala(
        definitions,
        model.symbols.keys(),
        header_names,
        package,
    )

    if not output_path.is_absolute():
        output_path = root / output_path

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(scala_source, encoding="utf-8")

    if not silent:
        print(f"Project root: {root}")
        print(f"Kconfig:     {kconfig_path}")
        print(
            f".config:     {config_path} "
            f"({'found' if config_path.is_file() else 'not found; defaults used'})"
        )
        print(f"Header:      {header_path if header_path else '(not specified)'}")
        print(f"Output:      {output_path}")
        print(f"Kconfig symbols: {len(model.symbols)}")
        print(f"Header macros:   {len(header_names)}")
        print(f"Scala values:    {len(definitions)}")

    if not silent and model.warnings:
        print("\nWarnings:", file=sys.stderr)
        for message in model.warnings:
            print(f"  {message}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Generate Scala configuration from Kconfig, .config "
            "and an optional C header (standard library only)."
        )
    )

    parser.add_argument(
        "kconfig",
        nargs="?",
        default="Kconfig",
        help="Kconfig file (default: ./Kconfig)",
    )
    parser.add_argument(
        "--header",
        help="Optional C header; its CONFIG_* macros have highest priority",
    )
    parser.add_argument(
        "--output",
        default="vsrc/chisel-gen/src/common/AutoConfig.scala",
        help="Output Scala file; relative paths are rooted at Kconfig directory",
    )
    parser.add_argument(
        "--package",
        default="config",
        help="Scala package name (default: config)",
    )
    parser.add_argument(
        "--silent",
        action="store_true",
        help="Suppress non-error messages",
    )

    args = parser.parse_args()

    try:
        convert(
            Path(args.kconfig),
            Path(args.header) if args.header else None,
            Path(args.output),
            args.package,
            args.silent,
        )
    except (OSError, ValueError) as exc:
        parser.error(str(exc))


if __name__ == "__main__":
    main()