#!/usr/bin/env python3
"""Reject firmware instructions outside the CPU's implemented RV32I subset."""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path


SUPPORTED = {
    "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and",
    "addi", "slli", "slti", "sltiu", "xori", "srli", "srai", "ori", "andi",
    "lb", "lh", "lw", "lbu", "lhu", "sb", "sh", "sw",
    "beq", "bne", "blt", "bge", "bltu", "bgeu",
    "jal", "jalr", "lui", "auipc",
}


def run(*command: str) -> str:
    return subprocess.run(
        command, check=True, text=True, stdout=subprocess.PIPE
    ).stdout


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("elf", type=Path)
    parser.add_argument("--objdump", required=True)
    parser.add_argument("--readelf", required=True)
    args = parser.parse_args()

    attributes = run(args.readelf, "-A", str(args.elf))
    architecture = re.search(r'Tag_RISCV_arch: "([^"]+)"', attributes)
    if architecture is None or not architecture.group(1).startswith("rv32i"):
        raise SystemExit(f"unexpected ELF architecture:\n{attributes}")

    disassembly = run(
        args.objdump, "-d", "-M", "no-aliases,numeric", str(args.elf)
    )
    used: set[str] = set()
    for line in disassembly.splitlines():
        match = re.match(r"\s*[0-9a-f]+:\s+[0-9a-f]{8}\s+(\S+)", line)
        if match:
            used.add(match.group(1))

    unsupported = sorted(used - SUPPORTED)
    if unsupported:
        raise SystemExit(
            "unsupported instructions: " + ", ".join(unsupported)
        )
    if not used:
        raise SystemExit("no instructions found in ELF disassembly")

    print("RV32I audit passed; instructions: " + ", ".join(sorted(used)))


if __name__ == "__main__":
    main()
