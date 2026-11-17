import Distill

/-!
Prints the English translation of Lean files as JSON, one object per file:

    lake env lean --run ../scripts/informalization/translate.lean FILE...

(from `lean/`). Each object has the file's `messages` (Lean's errors and warnings), its `lines`
(what `Distill.translate` returns to the web app) and its `proofs`: for every proof the
`statement`, the `proof` as one paragraph, and what `verify` found.
-/

open Lean Distill Distill.Informalizer

unsafe def translateFile (path : String) : IO Json := do
  let source ← IO.FS.readFile path
  let (trees, messages, _) ← Extract.elabSource source path
  let messages ← messages.toList.mapM fun m => do
    return Json.mkObj [("severity", match m.severity with | .error => "error" | .warning => "warning" | .information => "info"), ("text", ← m.data.toString)]
  let mut proofs := #[]
  for tree in trees do
    for p in ← informalizeTree tree do
      proofs := proofs.push <| Json.mkObj [
        ("decl", toString p.ir.decl),
        ("statement", (p.english.statement?.map (Json.str ·.toMarkup)).getD .null),
        ("proof", p.english.proofText.toMarkup),
        ("hasCode", p.english.steps.any (·.text.leaves.any (· matches .code _))),
        ("verification", match p.verification? with
          | some v => Json.mkObj [("statement", v.statement.describe), ("proof", v.proof.describe), ("ok", v.ok)]
          | none => .null)]
  let lines ← translateTrees trees
  return Json.mkObj [
    ("file", path), ("messages", Json.arr messages.toArray), ("proofs", Json.arr proofs),
    ("lines", Json.arr (lines.map fun l => Json.mkObj [("line", l.line), ("english", l.english.toMarkup)]))]

unsafe def main (args : List String) : IO Unit := do
  for path in args do
    IO.println (← translateFile path).compress
