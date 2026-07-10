#!/usr/bin/env python3
"""Generate the deterministic, solver-verified Water Sort level catalog."""

from __future__ import annotations

import argparse
import itertools
import random
from collections import deque
from pathlib import Path

CAPACITY = 4
MAX_TUBES = 8
LEVELS_PER_DIFFICULTY = 12
CONFIGS = (
    ("EASY", 4, 2, 10, 15, 3, 0x13579BDF),
    ("NORMAL", 6, 1, 17, 23, 5, 0x2468ACE1),
    ("HARD", 7, 1, 22, 28, 6, 0xC001D00D),
)

State = tuple[tuple[int, ...], ...]


def canonical_state(state: State) -> State:
    """Tube positions are interchangeable while searching."""
    return tuple(sorted(state))


def canonical_structure(state: State, colors: int) -> State:
    """Normalize both tube positions and color names for catalog deduplication."""
    best = None
    for permutation in itertools.permutations(range(1, colors + 1)):
        color_map = (0,) + permutation
        mapped = tuple(sorted(tuple(color_map[color] for color in tube)
                              for tube in state))
        if best is None or mapped < best:
            best = mapped
    assert best is not None
    return best


def is_solved(state: State) -> bool:
    return all(not tube or (len(tube) == CAPACITY and len(set(tube)) == 1)
               for tube in state)


def legal_moves(state: State):
    for source, tube in enumerate(state):
        if not tube:
            continue
        color = tube[-1]
        run = 1
        while run < len(tube) and tube[-run - 1] == color:
            run += 1
        for target, destination in enumerate(state):
            if source == target or len(destination) == CAPACITY:
                continue
            if destination and destination[-1] != color:
                continue
            amount = min(run, CAPACITY - len(destination))
            updated = list(state)
            updated[source] = tube[:-amount]
            updated[target] = destination + (color,) * amount
            yield tuple(updated)


def shortest_solution_length(initial: State, state_limit: int = 300_000):
    queue = deque([(initial, 0)])
    visited = {canonical_state(initial)}
    while queue and len(visited) <= state_limit:
        state, distance = queue.popleft()
        if is_solved(state):
            return distance
        for updated in legal_moves(state):
            key = canonical_state(updated)
            if key not in visited:
                visited.add(key)
                queue.append((updated, distance + 1))
    return None


def mixed_tube_count(state: State) -> int:
    return sum(bool(tube) and len(set(tube)) > 1 for tube in state)


def transition_count(state: State) -> int:
    return sum(sum(a != b for a, b in zip(tube, tube[1:]))
               for tube in state)


def generate_difficulty(config):
    name, colors, empties, min_moves, max_moves, min_mixed, rng_seed = config
    rng = random.Random(rng_seed)
    levels = []
    fingerprints = set()
    attempts = 0

    while len(levels) < LEVELS_PER_DIFFICULTY:
        attempts += 1
        if attempts > 200_000:
            raise RuntimeError(f"unable to fill {name} catalog")
        liquid = [color for color in range(1, colors + 1)
                  for _ in range(CAPACITY)]
        rng.shuffle(liquid)
        tubes = [tuple(liquid[index:index + CAPACITY])
                 for index in range(0, len(liquid), CAPACITY)]
        tubes.extend([()] * empties)
        state = tuple(tubes)
        if mixed_tube_count(state) < min_mixed:
            continue
        if transition_count(state) < min_mixed * 2:
            continue
        distance = shortest_solution_length(state)
        if distance is None or not min_moves <= distance <= max_moves:
            continue
        fingerprint = canonical_structure(state, colors)
        if fingerprint in fingerprints:
            continue
        fingerprints.add(fingerprint)
        positioned = list(state)
        rng.shuffle(positioned)
        state = tuple(positioned)
        levels.append((state, distance))

    levels.sort(key=lambda item: (item[1], item[0]))
    return levels


def pack_tube(tube: tuple[int, ...]) -> int:
    packed = 0
    for layer, color in enumerate(tube):
        packed |= color << (layer * 4)
    return packed


def render_catalog(catalog) -> str:
    lines = [
        "#ifndef WATER_SORT_LEVEL_CATALOG_H",
        "#define WATER_SORT_LEVEL_CATALOG_H",
        "",
        "#include <stdint.h>",
        "",
        "enum { WATER_SORT_LEVELS_PER_DIFFICULTY = 12 };",
        "",
        "static const uint16_t water_sort_level_catalog[3][12][8] = {",
    ]
    for difficulty, (config, levels) in enumerate(zip(CONFIGS, catalog)):
        lines.append(f"    {{ /* {config[0]} */")
        for level_index, (state, distance) in enumerate(levels):
            packed = [pack_tube(tube) for tube in state]
            packed.extend([0] * (MAX_TUBES - len(packed)))
            values = ", ".join(f"0x{value:04x}" for value in packed)
            comma = "," if level_index + 1 < len(levels) else ""
            lines.append(f"        {{{values}}}{comma} /* min {distance} */")
        lines.append("    }," if difficulty < 2 else "    }")
    lines.extend([
        "};",
        "",
        "static const uint8_t water_sort_level_solution_lengths[3][12] = {",
    ])
    for difficulty, levels in enumerate(catalog):
        values = ", ".join(str(distance) for _, distance in levels)
        comma = "," if difficulty < 2 else ""
        lines.append(f"    {{{values}}}{comma}")
    lines.extend(["};", "", "#endif", ""])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="verify the committed catalog is reproducible")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    default_output = Path(__file__).resolve().parents[1] / "level_catalog.h"
    output = args.output or default_output
    catalog = [generate_difficulty(config) for config in CONFIGS]
    rendered = render_catalog(catalog)

    if args.check:
        if not output.exists() or output.read_text(encoding="ascii") != rendered:
            print(f"catalog mismatch: regenerate {output}")
            return 1
        print("level catalog verified: 12 EASY, 12 NORMAL, 12 HARD")
        return 0

    output.write_text(rendered, encoding="ascii")
    for config, levels in zip(CONFIGS, catalog):
        distances = [distance for _, distance in levels]
        print(f"{config[0]}: {len(levels)} levels, shortest {min(distances)}..{max(distances)}")
    print(f"wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
