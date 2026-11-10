import Distill.Informalizer.Pipeline
import Distill.Informalizer.Verify
import Distill.Informalizer.Extract.Frontend
import Distill.Informalizer.IR.PresentationFormat

/-!
# Running the pipeline outside the language server

`#informalize cmd` elaborates `cmd` and logs, for each of its proofs, the Presentation IR after
normalization, the English rendered from it, and whether the presentation verifies
(`Distill.Informalizer.verify`). It is for debugging in the editor and for tests,
like `#proof_ir` for extraction. Source lines are relative to the start of `cmd`.

`printFile` does the same for every proof of a Lean file, with absolute lines.
-/

namespace Distill.Informalizer

open Lean Meta Elab Command
open Distill.Informalizer.IR

/-- The Presentation IR and English of a proof and what `verify` finds, as text. Source lines
are printed with `lineOffset` subtracted. -/
def report (ir : ProofIR) (lineOffset : Nat := 0) : MetaM String := do
  let r ← informalize ir
  let mut out ← ir.withContext (r.presented.format ir) (goalName := ir.goalNumbering)
  out := out ++ "English\n"
  if ir.isDeclBody then
    out := out ++ s!"  {r.english.statement}\n"
  for s in r.english.steps do
    let line := match stepLine? ir s with
      | some l => toString (l - lineOffset)
      | none => "?"
    out := out ++ s!"  {line}: {s.text}\n"
  let v ← ir.withContext (verify ir r.presented) (goalName := ir.goalNumbering)
  out := out ++ s!"Verification\n  statement: {v.statement.describe}\n  proof: {v.proof.describe}\n"
  return out

/-- Elaborates `cmd` and logs `describe ir lineOffset` for each of its proofs, where
`lineOffset` is the number of lines before `cmd`. -/
def elabAndDescribe (cmd : Syntax) (describe : ProofIR → Nat → MetaM String) :
    CommandElabM Unit := do
  let before := (← getInfoState).trees.size
  withScope (fun scope => { scope with opts := Elab.async.set scope.opts false }) do
    elabCommand cmd
  let trees := (← getInfoState).trees.toArray.extract before
  let fileMap ← getFileMap
  let lineOffset := match cmd.getPos? with
    | some pos => (fileMap.toPosition pos).line - 1
    | none => 0
  let mut found := false
  for tree in trees do
    let some ctx := commandContext? tree (← getEnv) | continue
    for ir in ← Extract.extractProofs tree do
      found := true
      logInfoAt cmd (← ctx.runMetaM {} (describe ir lineOffset))
  unless found do logInfoAt cmd m!"no proofs"

/-- `#informalize cmd` elaborates `cmd` and shows the Presentation IR and English of its
proofs. -/
elab "#informalize " cmd:command : command =>
  elabAndDescribe cmd fun ir lineOffset => report ir lineOffset

/-- `#informalize_statement cmd` elaborates `cmd` and shows only the English of its statement,
and how `verify` relates the presented statement to the original. -/
elab "#informalize_statement " cmd:command : command =>
  elabAndDescribe cmd fun ir _ => do
    let r ← informalize ir
    let v ← ir.withContext (verify ir r.presented)
    return s!"{r.english.statement}\n  statement: {v.statement.describe}"

/-- Informalizes every proof in a Lean file and prints its Presentation IR and English, for
tests. -/
unsafe def printFile (path : System.FilePath) : IO Unit := do
  let (trees, messages, _) ← Extract.elabSource (← IO.FS.readFile path) path.toString
  for m in messages.toList do
    IO.println s!"message: {← m.toString}"
  for tree in trees do
    let some ctx := commandContext? tree | continue
    for ir in ← Extract.extractProofs tree do
      IO.print (← ctx.runMetaM {} (report ir))

end Distill.Informalizer
