#!/usr/bin/env python3
"""Convert a little-endian RV32 binary image to readmemh and Vivado COE."""

from __future__ import annotations

import argparse
from pathlib import Path


NOP = 0x00000013


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("binary", type=Path)
    parser.add_argument("--hex", dest="hex_path", type=Path, required=True)
    parser.add_argument("--coe", dest="coe_path", type=Path, required=True)
    parser.add_argument("--depth", type=int, default=1024)
    args = parser.parse_args()

    data = args.binary.read_bytes()
    if len(data) > args.depth * 4:
        raise ValueError(
            f"firmware is {len(data)} bytes; ROM holds {args.depth * 4} bytes"
        )

    data += bytes((-len(data)) % 4)
    words = [
        int.from_bytes(data[offset : offset + 4], "little")
        for offset in range(0, len(data), 4)
    ]
    padded = words + [NOP] * (args.depth - len(words))

    args.hex_path.write_text(
        "".join(f"{word:08x}\n" for word in padded), encoding="ascii"
    )
    vector = ",\n".join(f"{word:08x}" for word in padded)
    args.coe_path.write_text(
        "memory_initialization_radix=16;\n"
        "memory_initialization_vector=\n"
        f"{vector};\n",
        encoding="ascii",
    )
    print(f"converted {len(words)} words ({len(data)} bytes) from {args.binary}")


if __name__ == "__main__":
    main()
