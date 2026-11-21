import Distill

/-!
The translator benchmark (#105). From `lean/`:

    lake env lean --run ../scripts/informalization/benchmark.lean [--write ../docs/informalization/benchmark.md]

It measures, as the median of 5 runs:

1. **Demo levels.** The time to elaborate `Distill/Levels/Demo.lean` (its commands, after the
   imports are loaded), and for each level the time to translate it: everything after
   elaboration, i.e. what `Distill.translate` does with the level's InfoTree (extraction,
   presentation, normalization, verification, rendering and line assignment).
   Threshold: each level's translation takes no longer than elaborating the file.
2. **Long proofs.** The translation time of a generated proof of about 500 tactic steps and of
   one twice as long. Threshold: doubling the length at most about doubles the time, which is
   checked as a ratio of at most 2.5.

It prints the results, writes them as Markdown with `--write`, and exits with code 1 if a
threshold is not met.
-/

open Lean Elab Distill Distill.Informalizer

def runs := 5
/-- "At most about doubles". -/
def maxRatio : Float := 2.5

def median (xs : Array Float) : Float :=
  let s := xs.qsort (· < ·)
  s[s.size / 2]!

def ms (nanos : Nat) : Float := nanos.toFloat / 1e6

/-- Elaborates `source` and returns its InfoTrees and how long the commands took, without the
imports. -/
unsafe def elaborate (source : String) (fileName : String) : IO (Array InfoTree × Float) := do
  enableInitializersExecution
  let inputCtx := Parser.mkInputContext source fileName
  let (header, parserState, messages) ← Parser.parseHeader inputCtx
  let (env, messages) ← processHeader header {} messages inputCtx
  let opts := Elab.async.set {} false
  let cmdState := { Command.mkState env messages opts with infoState := { enabled := true } }
  if messages.hasErrors then throw <| IO.userError s!"{fileName}: the imports failed"
  let start ← IO.monoNanosNow
  let s ← IO.processCommands inputCtx parserState cmdState
  let infoState ← IO.wait s.commandState.infoState.substituteLazy
  let stop ← IO.monoNanosNow
  if s.commandState.messages.hasErrors then throw <| IO.userError s!"{fileName} has errors"
  return (infoState.trees.toArray, ms (stop - start))

/-- How long translating `trees` takes, and how many lines of English it gives. -/
def translateTime (trees : Array InfoTree) : IO (Float × Nat) := do
  let start ← IO.monoNanosNow
  let lines ← translateTrees trees
  let stop ← IO.monoNanosNow
  return (ms (stop - start), lines.size)

/-- The InfoTrees of the commands that contain a proof, with the declaration name. -/
def proofTrees (trees : Array InfoTree) : IO (Array (Name × InfoTree)) := do
  trees.filterMapM fun t => do
    let proofs ← Extract.extractProofs t
    return proofs[0]?.map (·.decl, t)

/-- A proof of `n` steps in the demo's language: membership in intersections built with
anonymous constructors and taken apart with projections. -/
def longProof (n : Nat) : String := Id.run do
  let mut out := "import Distill.Levels.Demo\nopen Distill\n\n" ++
    "theorem long (A B : Set α) (x : α) (h0 : x ∈ A) (k : x ∈ B) : x ∈ A := by\n"
  let mut prev := "h0"
  let mut i := 1
  while i + 1 < n do
    out := out ++ s!"  have p{i} : x ∈ A ∩ B := ⟨{prev}, k⟩\n"
    out := out ++ s!"  have h{i} : x ∈ A := p{i}.left\n"
    prev := s!"h{i}"
    i := i + 2
  out := out ++ s!"  exact {prev}\n"
  return out

structure LevelResult where
  name : Name
  translate : Float
  deriving Inhabited

unsafe def main (args : List String) : IO UInt32 := do
  let demoPath := "Distill/Levels/Demo.lean"
  let demo ← IO.FS.readFile demoPath
  -- 1. Demo levels.
  let mut elabTimes := #[]
  let mut levelTimes : Std.HashMap Name (Array Float) := {}
  let mut order := #[]
  for _ in [0:runs] do
    let (trees, t) ← elaborate demo demoPath
    elabTimes := elabTimes.push t
    for (name, tree) in ← proofTrees trees do
      unless order.contains name do order := order.push name
      let (tt, _) ← translateTime #[tree]
      levelTimes := levelTimes.insert name ((levelTimes.getD name #[]).push tt)
  let elabTime := median elabTimes
  let levels := order.map fun n => ({ name := n, translate := median (levelTimes.getD n #[]) } : LevelResult)
  let levelsOk := levels.all (·.translate ≤ elabTime)
  -- 2. Long proofs.
  let lengths := #[500, 1000]
  let mut longResults := #[]
  for n in lengths do
    let (trees, _) ← elaborate (longProof n) s!"long{n}.lean"
    let mut times := #[]
    let mut lineCount := 0
    for _ in [0:runs] do
      let (t, lines) ← translateTime trees
      times := times.push t
      lineCount := lines
    longResults := longResults.push (n, median times, lineCount)
  let ratio := longResults[1]!.2.1 / longResults[0]!.2.1
  let longOk := ratio ≤ maxRatio
  -- Report.
  -- One decimal, or two for numbers below 10.
  let fmt (x : Float) : String :=
    let digits := if x < 10 then 2 else 1
    let scale := (10 : Float) ^ digits.toFloat
    let n := (x * scale).round.toUInt64.toNat
    let frac := toString (n % scale.toUInt64.toNat)
    s!"{n / scale.toUInt64.toNat}.{"".pushn '0' (digits - frac.length) ++ frac}"
  let mut md := "# Translator benchmark\n\n" ++
    "Generated by `scripts/informalization/benchmark.lean` (run it from `lean/` with " ++
    "`lake env lean --run ../scripts/informalization/benchmark.lean --write " ++
    "../docs/informalization/benchmark.md`). Times are the median of " ++ s!"{runs} runs, in milliseconds.\n\n" ++
    "## Demo levels\n\n" ++
    s!"Elaborating `Distill/Levels/Demo.lean` (its commands, imports already loaded): **{fmt elabTime} ms**.\n\n" ++
    "Translation is everything after elaboration that `Distill.translate` does for the level. " ++
    "Threshold: no longer than elaborating the file.\n\n" ++
    "| Level | Translation (ms) | Within threshold |\n| --- | --- | --- |\n"
  for l in levels do
    md := md ++ s!"| `{l.name}` | {fmt l.translate} | {if l.translate ≤ elabTime then "yes" else "NO"} |\n"
  md := md ++ "\n## Long proofs\n\n" ++
    "A generated proof alternating `have p : x ∈ A ∩ B := ⟨h, k⟩` and `have h : x ∈ A := p.left`. " ++
    s!"Threshold: doubling the length at most about doubles the translation time (ratio at most {fmt maxRatio}).\n\n" ++
    "| Steps | Translation (ms) | Lines of English |\n| --- | --- | --- |\n"
  for (n, t, lines) in longResults do
    md := md ++ s!"| {n} | {fmt t} | {lines} |\n"
  md := md ++ s!"\nRatio 1000 / 500: **{fmt ratio}** ({if longOk then "within" else "NOT within"} the threshold).\n"
  md := md ++ s!"\n## Result\n\n{if levelsOk && longOk then "Both thresholds are met." else "A threshold is NOT met."}\n"
  IO.println md
  if let ["--write", path] := args then
    IO.FS.writeFile path md
  return if levelsOk && longOk then 0 else 1
