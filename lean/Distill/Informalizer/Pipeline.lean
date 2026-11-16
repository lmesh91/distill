import Distill.Informalizer.Extract
import Distill.Informalizer.Present
import Distill.Informalizer.Normalize
import Distill.Informalizer.Render
import Distill.Informalizer.Verify

/-!
# The informalization pipeline

```
InfoTree ──extract──▶ Proof IR ──present──▶ Presentation IR ──normalize──▶ Presentation IR ──render──▶ English
                                                                 ▲                 │
                                                                 └─────verify──────┘
```

Only a presentation that `verify` accepts is rendered. A normalization pass whose result does not
verify is skipped. If the presentation does not verify even before normalization, what does not
verify is shown as the Lean it is, which says nothing the Lean does not: the steps
(`renderStatementOnly`), or the statement too (`renderQuoted`).

`informalize` runs the stages after extraction on one proof, and `informalizeTree` runs all of
them on the InfoTree of an elaborated command. Like extraction, they work from InfoTrees alone,
so they run in the language server as well as on source text.
-/

namespace Distill.Informalizer

open Lean Meta Elab
open Distill.Informalizer.IR Distill.Informalizer.Extract

structure Config where
  /-- Whether to verify the presentation before rendering it. Only for measuring and debugging
  the other stages: without it nothing checks that the English says what the Lean says. -/
  verify : Bool := true

/-- A proof at every stage of the pipeline. -/
structure Informalized where
  ir : ProofIR
  /-- The Presentation IR after normalization. -/
  presented : PresentedDecl
  /-- What `verify` found for `presented`; `none` if `Config.verify` was off. -/
  verification? : Option Verification
  /-- The normalization passes that were left out: they threw, or their result did not verify. -/
  skipped : Array SkippedPass
  /-- Rendered from `presented` as far as it verifies, and quoted from the Lean source for the
  rest. -/
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

/-- Presents, normalizes, verifies and renders `ir`. -/
def informalize (ir : ProofIR) (config : Config := {}) : MetaM Informalized := ir.withContext do
  let direct ← present ir
  -- Whatever goes wrong after this, running out of heartbeats included, the Lean can be shown.
  tryCatchRuntimeEx (k direct) fun e => do
    let reason := s!"verification did not finish: {← e.toMessageData.toString}"
    return {
      ir, presented := direct, skipped := #[], english := ← renderQuoted ir direct
      verification? := some {
        original := ir.statement.conclusion, presented := direct.conclusion.prop.expr
        statement := .failed reason, proof := .failed reason } }
where k (direct : PresentedDecl) : MetaM Informalized := do
  unless config.verify do
    let (presented, skipped) ← normalize ir direct
    return { ir, presented, verification? := none, skipped, english := ← render ir presented }
  -- The usual case: every pass is right, and one check of the result shows it.
  let (presented, skipped) ← normalize ir direct
  let verification ← verify ir presented
  if verification.ok then
    return { ir, presented, verification? := verification, skipped, english := ← render ir presented }
  let verification ← verify ir direct
  unless verification.ok do
    let english ← match verification.statement with
      | .failed _ => renderQuoted ir direct
      | _ => renderStatementOnly ir direct
    return { ir, presented := direct, verification? := verification, skipped := #[], english }
  -- Some pass is wrong: run them again, checking after each one.
  let (presented, skipped) ← normalize ir direct fun d => return (← verify ir d).failure?
  return {
    ir, presented, verification? := ← verify ir presented, skipped
    english := ← render ir presented }

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
