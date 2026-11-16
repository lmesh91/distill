import Distill.Informalizer.Extract
import Distill.Informalizer.Present
import Distill.Informalizer.Normalize
import Distill.Informalizer.Render

/-!
# The informalization pipeline

```
InfoTree ──extract──▶ Proof IR ──present──▶ Presentation IR ──normalize──▶ Presentation IR ──render──▶ English
```

`informalize` runs the stages after extraction on one proof, and `informalizeTree` runs all of
them on the InfoTree of an elaborated command. Like extraction, they work from InfoTrees alone,
so they run in the language server as well as on source text.
-/

namespace Distill.Informalizer

open Lean Meta Elab
open Distill.Informalizer.IR Distill.Informalizer.Extract

/-- A proof at every stage of the pipeline. -/
structure Informalized where
  ir : ProofIR
  /-- The Presentation IR after normalization. -/
  presented : PresentedDecl
  english : Rendered
  deriving Inhabited

/-- The one-based source line node `n` starts on. -/
def nodeLine? (ir : ProofIR) (n : Nat) : Option Nat :=
  match (ir.node? n).map (·.origin) with
  | some (IR.SyntaxOrigin.original span) | some (IR.SyntaxOrigin.synthetic span) =>
    some span.start.line
  | _ => none

/-- The one-based source line a step is shown at: where the first of its nodes starts. -/
def stepLine? (ir : ProofIR) (s : RenderedStep) : Option Nat :=
  s.nodes.findSome? (nodeLine? ir)

/-- Presents, normalizes and renders `ir`. -/
def informalize (ir : ProofIR) : MetaM Informalized := ir.withContext do
  let presented ← normalize ir (← present ir)
  return { ir, presented, english := ← render ir presented }

/-- The context to run the pipeline's `MetaM` stages in for the proofs of a command's InfoTree:
the environment after the command (or `env?`), and the command's namespace, open declarations
and options, which decide how Lean code is printed. -/
def commandContext? (tree : InfoTree) (env? : Option Environment := none) : Option ContextInfo :=
  match tree with
  | .context (.commandCtx ci) _ =>
    some { ci with env := env?.getD (ci.cmdEnv?.getD ci.env), mctx := {} }
  | _ => none

/-- Informalizes every proof in the InfoTree of an elaborated command. Like extraction, it does
not fail because of the proofs it is given: a proof that cannot be informalized is left out. -/
def informalizeTree (tree : InfoTree) (env? : Option Environment := none) :
    IO (Array Informalized) := do
  let some ctx := commandContext? tree env? | return #[]
  let proofs ← try extractProofs tree catch _ => pure #[]
  proofs.filterMapM fun ir => do
    try return some (← ctx.runMetaM {} (informalize ir)) catch _ => return none

end Distill.Informalizer
