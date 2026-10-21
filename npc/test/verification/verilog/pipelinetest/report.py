#!/usr/bin/env python3
"""Summarize existing SBY results without treating missing or expected failures as PASS."""
import argparse
import hashlib
import json
from pathlib import Path

PROJECT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", default="build")
    args = parser.parse_args()
    build = (PROJECT / args.build).resolve()
    if build == PROJECT or PROJECT not in build.parents:
        parser.error("build directory must be strictly inside this project")
    manifest_path = build / "manifest.json"
    if not manifest_path.is_file():
        parser.error("manifest missing; run make configure/check/verify first")
    manifest = json.loads(manifest_path.read_text())
    changed = []
    for name, digest in manifest["inputs"].items():
        path = PROJECT.parents[3] / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            changed.append(name)
    if changed:
        print("WARNING: sources changed since this manifest; results are stale:")
        for name in changed:
            print(f"  {name}")
    print("Recorded parameters (compare each task's config.sby if rerun separately):")
    print(json.dumps(manifest["parameters"], ensure_ascii=False, indent=2))
    statuses = sorted(build.glob("verify_*/status")) + sorted(build.glob("selftest_*/status"))
    if not statuses:
        print("No completed SBY status files in this build directory.")
    for status in statuses:
        print(f"{status.parent.name}: {status.read_text().strip()}")
    print("Safety, bounded progress and cover must be interpreted separately.")
    print("Selftest mutations intentionally produce FAIL; consult config.sby expect.")
    print("Logs and traces: each task directory; source/tool hashes: manifest.json")


if __name__ == "__main__":
    main()
