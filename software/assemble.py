#!/usr/bin/env python3
"""Small, strict RV32I assembler for the voice game firmware.

The project intentionally keeps this dependency-free so the COE image can be
regenerated on machines without a RISC-V GNU toolchain.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass
class SourceLine:
    number: int
    text: str
    instruction: str
    address: int


def fail(line: SourceLine, message: str) -> ValueError:
    return ValueError(f"{line.number}: {message}: {line.text}")


def register(token: str, line: SourceLine) -> int:
    match = re.fullmatch(r"x([0-9]|[12][0-9]|3[01])", token.lower())
    if not match:
        raise fail(line, f"invalid register {token!r}")
    return int(match.group(1))


def number(token: str, line: SourceLine) -> int:
    try:
        return int(token, 0)
    except ValueError as exc:
        raise fail(line, f"invalid integer {token!r}") from exc


def signed_immediate(value: int, bits: int, line: SourceLine) -> int:
    minimum = -(1 << (bits - 1))
    maximum = (1 << (bits - 1)) - 1
    if not minimum <= value <= maximum:
        raise fail(line, f"immediate {value} does not fit signed {bits} bits")
    return value & ((1 << bits) - 1)


def r_type(funct7: int, rs2: int, rs1: int, funct3: int, rd: int) -> int:
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | (rd << 7) | 0x33


def i_type(imm: int, rs1: int, funct3: int, rd: int, opcode: int) -> int:
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | \
           (rd << 7) | opcode


def s_type(imm: int, rs2: int, rs1: int, funct3: int) -> int:
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | ((imm & 0x1F) << 7) | 0x23


def b_type(offset: int, rs2: int, rs1: int, funct3: int) -> int:
    return (((offset >> 12) & 1) << 31) | \
           (((offset >> 5) & 0x3F) << 25) | \
           (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | \
           (((offset >> 1) & 0xF) << 8) | \
           (((offset >> 11) & 1) << 7) | 0x63


def j_type(offset: int, rd: int) -> int:
    return (((offset >> 20) & 1) << 31) | \
           (((offset >> 1) & 0x3FF) << 21) | \
           (((offset >> 11) & 1) << 20) | \
           (((offset >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F


def memory_operand(token: str, line: SourceLine) -> tuple[int, int]:
    match = re.fullmatch(r"(.+)\((x(?:[0-9]|[12][0-9]|3[01]))\)", token.lower())
    if not match:
        raise fail(line, f"invalid memory operand {token!r}")
    return number(match.group(1), line), register(match.group(2), line)


def target_offset(token: str, labels: dict[str, int], line: SourceLine) -> int:
    if token in labels:
        return labels[token] - line.address
    return number(token, line)


def tokenize(instruction: str) -> list[str]:
    return instruction.replace(",", " ").split()


def encode(line: SourceLine, labels: dict[str, int]) -> int:
    tokens = tokenize(line.instruction)
    op = tokens[0].lower()
    args = tokens[1:]

    if op == ".word":
        if len(args) != 1:
            raise fail(line, ".word expects one argument")
        return number(args[0], line) & 0xFFFFFFFF
    if op == "nop":
        if args:
            raise fail(line, "nop expects no arguments")
        return 0x00000013
    if op == "j":
        if len(args) != 1:
            raise fail(line, "j expects one target")
        offset = target_offset(args[0], labels, line)
        if offset & 1:
            raise fail(line, "jump target is not 2-byte aligned")
        offset = signed_immediate(offset, 21, line)
        return j_type(offset, 0)

    r_ops = {
        "add": (0x00, 0x0), "sub": (0x20, 0x0),
        "sll": (0x00, 0x1), "slt": (0x00, 0x2),
        "sltu": (0x00, 0x3), "xor": (0x00, 0x4),
        "srl": (0x00, 0x5), "sra": (0x20, 0x5),
        "or": (0x00, 0x6), "and": (0x00, 0x7),
    }
    if op in r_ops:
        if len(args) != 3:
            raise fail(line, f"{op} expects rd, rs1, rs2")
        rd, rs1, rs2 = (register(arg, line) for arg in args)
        funct7, funct3 = r_ops[op]
        return r_type(funct7, rs2, rs1, funct3, rd)

    i_ops = {
        "addi": 0x0, "slti": 0x2, "sltiu": 0x3,
        "xori": 0x4, "ori": 0x6, "andi": 0x7,
    }
    if op in i_ops:
        if len(args) != 3:
            raise fail(line, f"{op} expects rd, rs1, immediate")
        rd = register(args[0], line)
        rs1 = register(args[1], line)
        imm = signed_immediate(number(args[2], line), 12, line)
        return i_type(imm, rs1, i_ops[op], rd, 0x13)

    if op in ("slli", "srli", "srai"):
        if len(args) != 3:
            raise fail(line, f"{op} expects rd, rs1, shift")
        rd = register(args[0], line)
        rs1 = register(args[1], line)
        shift = number(args[2], line)
        if not 0 <= shift <= 31:
            raise fail(line, "shift amount must be between 0 and 31")
        funct3 = 0x1 if op == "slli" else 0x5
        imm = shift | (0x400 if op == "srai" else 0)
        return i_type(imm, rs1, funct3, rd, 0x13)

    if op == "lw":
        if len(args) != 2:
            raise fail(line, "lw expects rd, offset(rs1)")
        rd = register(args[0], line)
        imm_value, rs1 = memory_operand(args[1], line)
        imm = signed_immediate(imm_value, 12, line)
        return i_type(imm, rs1, 0x2, rd, 0x03)

    if op == "sw":
        if len(args) != 2:
            raise fail(line, "sw expects rs2, offset(rs1)")
        rs2 = register(args[0], line)
        imm_value, rs1 = memory_operand(args[1], line)
        imm = signed_immediate(imm_value, 12, line)
        return s_type(imm, rs2, rs1, 0x2)

    branch_ops = {
        "beq": 0x0, "bne": 0x1, "blt": 0x4,
        "bge": 0x5, "bltu": 0x6, "bgeu": 0x7,
    }
    if op in branch_ops:
        if len(args) != 3:
            raise fail(line, f"{op} expects rs1, rs2, target")
        rs1 = register(args[0], line)
        rs2 = register(args[1], line)
        offset = target_offset(args[2], labels, line)
        if offset & 1:
            raise fail(line, "branch target is not 2-byte aligned")
        offset = signed_immediate(offset, 13, line)
        return b_type(offset, rs2, rs1, branch_ops[op])

    if op == "jal":
        if len(args) != 2:
            raise fail(line, "jal expects rd, target")
        rd = register(args[0], line)
        offset = target_offset(args[1], labels, line)
        if offset & 1:
            raise fail(line, "jump target is not 2-byte aligned")
        offset = signed_immediate(offset, 21, line)
        return j_type(offset, rd)

    if op in ("lui", "auipc"):
        if len(args) != 2:
            raise fail(line, f"{op} expects rd, upper-immediate")
        rd = register(args[0], line)
        imm = number(args[1], line)
        if not 0 <= imm <= 0xFFFFF:
            raise fail(line, "upper-immediate must fit 20 unsigned bits")
        opcode = 0x37 if op == "lui" else 0x17
        return (imm << 12) | (rd << 7) | opcode

    raise fail(line, f"unsupported instruction {op!r}")


def parse_source(path: Path) -> tuple[list[SourceLine], dict[str, int]]:
    labels: dict[str, int] = {}
    lines: list[SourceLine] = []
    address = 0

    for number_value, original in enumerate(path.read_text().splitlines(), 1):
        instruction = original.split("#", 1)[0].split("//", 1)[0].strip()
        if not instruction:
            continue

        while ":" in instruction:
            label, remainder = instruction.split(":", 1)
            label = label.strip()
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", label):
                raise ValueError(f"{number_value}: invalid label {label!r}")
            if label in labels:
                raise ValueError(f"{number_value}: duplicate label {label!r}")
            labels[label] = address
            instruction = remainder.strip()
            if not instruction:
                break

        if instruction:
            lines.append(SourceLine(number_value, original, instruction, address))
            address += 4

    return lines, labels


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--hex", dest="hex_path", type=Path, required=True)
    parser.add_argument("--coe", dest="coe_path", type=Path, required=True)
    parser.add_argument("--listing", type=Path, required=True)
    parser.add_argument("--depth", type=int, default=1024)
    args = parser.parse_args()

    lines, labels = parse_source(args.source)
    words = [encode(line, labels) for line in lines]
    if len(words) > args.depth:
        raise ValueError(f"program has {len(words)} words; ROM depth is {args.depth}")

    padded = words + [0x00000013] * (args.depth - len(words))
    args.hex_path.write_text("".join(f"{word:08x}\n" for word in padded))

    vector = ",\n".join(f"{word:08x}" for word in padded)
    args.coe_path.write_text(
        "memory_initialization_radix=16;\n"
        "memory_initialization_vector=\n"
        f"{vector};\n"
    )

    listing_lines = [
        f"{line.address:08x}  {word:08x}  {line.text}\n"
        for line, word in zip(lines, words)
    ]
    args.listing.write_text("".join(listing_lines))
    print(f"assembled {len(words)} words ({len(words) * 4} bytes)")


if __name__ == "__main__":
    main()
