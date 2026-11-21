import Distill.Informalizer.Pipeline
import Distill.Informalizer.Constants

/-!
# Coverage: what a proof uses that has no English

`coverageGaps` lists, for one informalized proof, everything the translation could not put
into English (#104):

* a step shown as the Lean it came from (a tactic or term without a translation), or any Lean
  code in the English;
* a proof the pipeline failed on, or whose presentation did not verify (and so is quoted);
* a constant the proof uses (`referencedConstants`) that has no English: a definition, type or
  constructor without a translator, or a theorem whose statement does not render as English.

A gap in an unfinished proof's `sorry` is not a gap in the translation: "the Lean proof leaves
this out with `sorry`" names the Lean keyword on purpose.
-/

namespace Distill.Informalizer

open Lean Meta Elab
open Distill.Informalizer.IR

/-- Whether the constant `c`, used by a proof, can be said in English. -/
def constantHasEnglish (c : ReferencedConstant) : MetaM Bool := do
  if ← Render.hasTranslator c.name then return true
  match c.kind with
  | .theorem | .axiom =>
    -- Cited by its statement: "the previously proved theorem that for all sets $A$ and $B$, …".
    let text? ← (citation c.name #[]).run {} |>.run' {}
    return text?.any fun t => !t.leaves.any (· matches .code _)
  | _ => return false

/-- What is not translated in the informalized proof `r` (see the module documentation). Runs
in the proof's command context. -/
def coverageGaps (r : Informalized) : MetaM (Array String) := do
  let mut gaps := #[]
  if let some v := r.verification? then
    if let some reason := v.failure? then gaps := gaps.push s!"the presentation does not verify: {reason}"
  let isSorryCode (t : String) := t == "sorry"
  for s in r.english.steps do
    let code := s.text.leaves.filterMap fun | .code c => some c | _ => none
    for c in code do
      let gap := s!"Lean code in the English: `{c}`"
      unless isSorryCode c || gaps.contains gap do gaps := gaps.push gap
  if r.english.statement?.any (·.leaves.any (· matches .code _)) then
    gaps := gaps.push "Lean code in the statement"
  let constants ← referencedConstants r.ir
  let missing ← r.ir.withContext <| constants.filterM fun c => return !(← constantHasEnglish c)
  for c in missing do
    gaps := gaps.push s!"no English for the {c.kind.describe} `{c.name}`"
  return gaps

/-- The coverage gaps of every proof in the InfoTree of a command, by declaration. A proof the
pipeline fails on is a gap of its own. -/
def treeCoverageGaps (tree : InfoTree) (env? : Option Environment := none) :
    IO (Array (Name × Array String)) := do
  let some ctx := commandContext? tree env? | return #[]
  let proofs ← try Extract.extractProofs tree catch _ => pure #[]
  proofs.mapM fun ir => do
    try
      let gaps ← ctx.runMetaM {} do coverageGaps (← informalize ir)
      return (ir.decl, gaps)
    catch e => return (ir.decl, #[s!"the pipeline fails: {e}"])

end Distill.Informalizer
