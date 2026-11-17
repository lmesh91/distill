#!/usr/bin/env python3
"""The edge-case catalog of the informalizer (docs/informalization/edge-cases.md).

    catalog.py doc      rewrite the table of entries in edge-cases.md from the entry headers
    catalog.py split    move the held-out entries to lean/Tests/HeldOut/ (fixed seed)
    catalog.py list     print the ids of the entries that are not held out

An entry is a file `lean/Tests/Catalog/cases/<id>.lean.txt`: a Lean source with a header of
`-- key: value` lines (id, level, kind, note). The files are not `.lean` so that Lake never
compiles them: some do not parse, and the held-out ones must not be run.

`split` only reads the headers' ids. It is deterministic: the same seed moves the same
entries, and running it again moves nothing more.
"""

import random
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CASES = ROOT / "lean" / "Tests" / "Catalog" / "cases"
HELD_OUT = ROOT / "lean" / "Tests" / "HeldOut"
SPLIT_RECORD = ROOT / "lean" / "Tests" / "Catalog" / "held-out.txt"
DOC = ROOT / "docs" / "informalization" / "edge-cases.md"
SUFFIX = ".lean.txt"

SEED = 20261116
HELD_OUT_FRACTION = 0.25
KINDS = ["alternative", "partial", "broken", "unsupported"]


def header(path: Path) -> dict:
    """The `-- key: value` lines a file starts with."""
    fields = {}
    for line in path.read_text().splitlines():
        m = re.match(r"-- (\w+): (.*)", line)
        if not m:
            break
        fields[m.group(1)] = m.group(2)
    return fields


def ids(directory: Path) -> list:
    return sorted(p.name[: -len(SUFFIX)] for p in directory.glob("*" + SUFFIX))


def split() -> None:
    if SPLIT_RECORD.exists():
        sys.exit(f"already split: {SPLIT_RECORD.relative_to(ROOT)} exists")
    # Stratified by kind, so that every kind is held out in proportion.
    by_kind = {k: [] for k in KINDS}
    for entry in ids(CASES):
        by_kind[header(CASES / (entry + SUFFIX))["kind"]].append(entry)
    rng = random.Random(SEED)
    held = []
    for kind in KINDS:
        entries = by_kind[kind]
        held += rng.sample(entries, round(len(entries) * HELD_OUT_FRACTION))
    HELD_OUT.mkdir(parents=True, exist_ok=True)
    for entry in sorted(held):
        (CASES / (entry + SUFFIX)).rename(HELD_OUT / (entry + SUFFIX))
    SPLIT_RECORD.write_text(
        f"# seed {SEED}, fraction {HELD_OUT_FRACTION}, stratified by kind\n"
        + "".join(e + "\n" for e in sorted(held))
    )
    print(f"held out {len(held)} of {len(held) + len(ids(CASES))} entries")


def doc() -> None:
    """Rewrites the table between the markers in edge-cases.md. Run before `split`: it reads
    every entry's header."""
    if SPLIT_RECORD.exists():
        sys.exit("the table is frozen once the catalog is split")
    rows = []
    for entry in ids(CASES):
        h = header(CASES / (entry + SUFFIX))
        level = h["level"] if h["level"] != "0" else "–"
        rows.append((KINDS.index(h["kind"]), h["level"], entry, f"| `{entry}` | {level} | {h['kind']} | {h['note']} |"))
    table = "\n".join(
        ["| Entry | Level | Kind | What it is |", "| --- | --- | --- | --- |"] + [r[3] for r in sorted(rows)]
    )
    text = DOC.read_text()
    begin, end = "<!-- entries:begin -->", "<!-- entries:end -->"
    before, rest = text.split(begin)
    _, after = rest.split(end)
    DOC.write_text(f"{before}{begin}\n\n{table}\n\n{end}{after}")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "split":
        split()
    elif command == "doc":
        doc()
    elif command == "list":
        print("\n".join(ids(CASES)))
    else:
        sys.exit(__doc__)
