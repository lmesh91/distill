#!/usr/bin/env python3
"""Judges the English the translator produces (acceptance criteria 2 and 3).

    scripts/judge.py blind         blind review: the judge sees only the English
    scripts/judge.py faithfulness  the judge sees the Lean and the English
    scripts/judge.py all           both

Options:

    --runs N       judge each proof N times (default: 3 for blind, 1 for faithfulness)
    --jobs N       judge calls run at the same time (default 6)
    --only ID ...  only these cases (a catalog id, or `demo`)
    --held-out     the held-out catalog entries instead of the demo and the other entries;
                   only for the final evaluation
    --write FILE   also write the results as Markdown
    --export DIR   write each judge prompt to DIR/<kind>/<case>.<n>.prompt.txt instead of asking
                   the CLI, for a judge run elsewhere (e.g. as subagents); it writes its reply
                   next to the prompt as <case>.<n>.reply.txt
    --import DIR   score the replies in DIR instead of asking the CLI

The cases are every proof in `lean/Distill/Levels/Demo.lean` and in each catalog entry of kind
`alternative` (complete alternative proofs of the demo levels). Other kinds are not reviewed:
criterion 2 names complete proofs, and the regression test checks the others' fallback.

The judge is `claude-haiku-5-5`, run with `claude -p` from an empty directory, without tools,
settings or session, so that it is given nothing but the prompt. The prompts are frozen:
`docs/informalization/judge-prompt.md` and `docs/informalization/faithfulness-prompt.md` (the
text below their `---` line). The faithfulness judge's Lean source starts with the library the
proof relies on: the set definitions, and the statements of the earlier theorems it names.

Exits with code 1 if any judgment is not a pass, and with an error before judging anything if
the judge cannot be reached (a failed call is never recorded as a judgment).
"""

import argparse
import json
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEAN = ROOT / "lean"
DEMO = LEAN / "Distill" / "Levels" / "Demo.lean"
SETS = LEAN / "Distill" / "Definitions" / "Sets.lean"
CASES = LEAN / "Tests" / "Catalog" / "cases"
HELD_OUT = LEAN / "Tests" / "HeldOut"
DOCS = ROOT / "docs" / "informalization"
MODEL = "claude-haiku-5-5"
SUFFIX = ".lean.txt"


def frozen_prompt(name: str) -> str:
    text = (DOCS / name).read_text()
    return text.split("\n---\n", 1)[1].strip() + "\n"


def header(path: Path) -> dict:
    fields = {}
    for line in path.read_text().splitlines():
        m = re.match(r"-- (\w+): (.*)", line)
        if not m:
            break
        fields[m.group(1)] = m.group(2)
    return fields


def strip_comments(source: str) -> str:
    """The source without `--` comment lines and the entry header."""
    lines = [l for l in source.splitlines() if not l.lstrip().startswith("--")]
    return "\n".join(lines).strip() + "\n"


def declaration_source(source: str, short_name: str) -> str:
    """The source of the theorem or lemma `short_name`: from its keyword up to the next line
    that starts in the first column."""
    lines = source.splitlines()
    for i, line in enumerate(lines):
        if re.match(rf"(theorem|lemma|example|def)\s+{re.escape(short_name)}\b", line):
            out = [line]
            for rest in lines[i + 1 :]:
                if rest and not rest[0].isspace():
                    break
                out.append(rest)
            return strip_comments("\n".join(out))
    return strip_comments(source)


def earlier_theorems(source: str, own: str) -> list:
    """The statements of the demo theorems that `source` names, other than `own` itself."""
    used = set(re.findall(r"[A-Za-z_][\w.']*", strip_comments(source)))
    out = []
    for m in re.finditer(r"^theorem\s+(\S+)(.*?):=", DEMO.read_text(), re.M | re.S):
        if m.group(1) != own and m.group(1) in used:
            out.append(f"theorem {m.group(1)}{m.group(2).rstrip()} := ...")
    return out


def with_library(source: str, own: str) -> str:
    """The proof's Lean source, after the library it relies on: the set definitions (in which
    `Set.ext` is not Mathlib's) and the statements of the earlier theorems it names."""
    parts = ["-- The definitions the proof uses (Distill/Definitions/Sets.lean):",
             strip_comments(SETS.read_text()).strip()]
    earlier = earlier_theorems(source, own)
    if earlier:
        parts += ["", "-- Earlier theorems the proof cites (proved before it):"] + earlier
    parts += ["", "-- The proof:", source.strip()]
    return "\n".join(parts) + "\n"


def translate(paths: list) -> list:
    """The translator's output for each file (scripts/informalization/translate.lean)."""
    result = subprocess.run(
        ["lake", "env", "lean", "--run", "../scripts/informalization/translate.lean"]
        + [str(p) for p in paths],
        cwd=LEAN, capture_output=True, text=True, check=True)
    return [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")]


def cases(held_out: bool, only: set) -> list:
    """(case id, proof name, Lean source, English statement, English proof, translation ok)."""
    files = []
    if not held_out and (not only or "demo" in only):
        files.append(("demo", DEMO))
    directory = HELD_OUT if held_out else CASES
    for path in sorted(directory.glob("*" + SUFFIX)):
        entry = path.name[: -len(SUFFIX)]
        if header(path).get("kind") == "alternative" and (not only or entry in only):
            files.append((entry, path))
    out = []
    for (entry, path), result in zip(files, translate([p for _, p in files])):
        source = path.read_text()
        for proof in result["proofs"]:
            short = proof["decl"].split(".")[-1]
            lean = declaration_source(source, short) if entry == "demo" else strip_comments(source)
            lean = with_library(lean, short)
            out.append({
                "case": entry, "decl": proof["decl"], "lean": lean,
                "statement": proof["statement"] or "", "proof": proof["proof"],
                "verified": bool(proof["verification"] and proof["verification"]["ok"]),
            })
    return out


def ask(prompt: str) -> str:
    with tempfile.TemporaryDirectory() as empty:
        result = subprocess.run(
            ["claude", "-p", "--model", MODEL, "--tools", "", "--setting-sources", "",
             "--no-session-persistence", "--strict-mcp-config"],
            input=prompt, cwd=empty, capture_output=True, text=True, timeout=600)
    if result.returncode != 0:
        raise RuntimeError(f"claude failed: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout.strip()


def verdict(reply: str) -> str:
    m = re.search(r"VERDICT:\s*(\w+)", reply)
    return m.group(1).upper() if m else "NONE"


def prompt_for(kind: str, case: dict) -> str:
    if kind == "blind":
        prompt = frozen_prompt("judge-prompt.md")
    else:
        prompt = frozen_prompt("faithfulness-prompt.md").replace("{{LEAN}}", case["lean"].strip())
    return prompt.replace("{{STATEMENT}}", case["statement"]).replace("{{PROOF}}", case["proof"])


def judge(kind: str, case: dict, runs: int) -> list:
    # A failed call (authentication, network) is not a judgment: it stops the run rather than
    # being recorded as a failure.
    return [ask(prompt_for(kind, case)) for _ in range(runs)]


def file_stem(index: int, case: dict) -> str:
    """A file name for a case: its position, catalog id and declaration."""
    return f"{index:03}-{case['case']}-{case['decl'].split('.')[-1]}"


def export(directory: Path, kind: str, cases_: list, runs: int) -> None:
    (directory / kind).mkdir(parents=True, exist_ok=True)
    for i, case in enumerate(cases_):
        for r in range(runs):
            (directory / kind / f"{file_stem(i, case)}.{r}.prompt.txt").write_text(
                prompt_for(kind, case))


def imported(directory: Path, kind: str, cases_: list, runs: int) -> list:
    """The replies for each case. A missing reply stops the run: it is not a judgment."""
    out = []
    for i, case in enumerate(cases_):
        replies = []
        for r in range(runs):
            path = directory / kind / f"{file_stem(i, case)}.{r}.reply.txt"
            if not path.exists():
                sys.exit(f"no reply {path}: nothing was scored")
            replies.append(path.read_text().strip())
        out.append(replies)
    return out


PASS = {"blind": "PASS", "faithfulness": "FAITHFUL"}


def markdown(results: dict, cases_: list) -> str:
    out = ["# Judge results", "",
           f"Generated by `scripts/judge.py`. Judge: `{MODEL}`.", ""]
    for kind, rows in results.items():
        out += [f"## {kind}", "", "| Case | Proof | Verdicts | Passes |", "| --- | --- | --- | --- |"]
        for case, replies in zip(cases_, rows):
            verdicts = [verdict(r) for r in replies]
            ok = all(v == PASS[kind] for v in verdicts)
            out.append(f"| {case['case']} | `{case['decl']}` | {' '.join(verdicts)} | "
                       f"{'yes' if ok else 'NO'} |")
        out.append("")
        failures = [(c, r) for c, replies in zip(cases_, rows)
                    for r in replies if verdict(r) != PASS[kind]]
        if failures:
            out += [f"### {kind}: what the judge reported", ""]
            for case, reply in failures:
                out += [f"**{case['case']}** `{case['decl']}`", "", "```", reply, "```", ""]
    return "\n".join(out)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("kind", choices=["blind", "faithfulness", "all"])
    parser.add_argument("--runs", type=int)
    parser.add_argument("--jobs", type=int, default=6)
    parser.add_argument("--only", nargs="*", default=[])
    parser.add_argument("--held-out", action="store_true")
    parser.add_argument("--write")
    parser.add_argument("--json")
    parser.add_argument("--export")
    parser.add_argument("--import", dest="import_")
    args = parser.parse_args()
    kinds = ["blind", "faithfulness"] if args.kind == "all" else [args.kind]
    runs_of = lambda kind: args.runs or (3 if kind == "blind" else 1)
    cases_ = cases(args.held_out, set(args.only))
    if args.export:
        for kind in kinds:
            export(Path(args.export), kind, cases_, runs_of(kind))
        print(f"wrote the prompts of {len(cases_)} cases to {args.export}")
        return
    results = {}
    if args.import_:
        for kind in kinds:
            results[kind] = imported(Path(args.import_), kind, cases_, runs_of(kind))
    else:
        # Before anything is judged: a judge that cannot be reached must not produce results.
        try:
            ask("Reply with the single word OK.")
        except Exception as e:  # noqa: BLE001
            sys.exit(f"the judge cannot be reached, nothing was judged: {e}")
        with ThreadPoolExecutor(args.jobs) as pool:
            for kind in kinds:
                results[kind] = list(pool.map(lambda c: judge(kind, c, runs_of(kind)), cases_))
    failed = False
    for kind, rows in results.items():
        for case, replies in zip(cases_, rows):
            verdicts = [verdict(r) for r in replies]
            ok = all(v == PASS[kind] for v in verdicts)
            failed |= not ok
            print(f"{kind:12} {case['case']:24} {case['decl']:50} {' '.join(verdicts)}"
                  f"{'' if ok else '   <-- FAIL'}")
    unverified = [c for c in cases_ if not c["verified"]]
    for c in unverified:
        print(f"translator verification failed: {c['case']} {c['decl']}")
    failed |= bool(unverified)
    if args.write:
        Path(args.write).write_text(markdown(results, cases_))
    if args.json:
        Path(args.json).write_text(json.dumps(
            {"cases": cases_, "results": results}, indent=1, ensure_ascii=False))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
