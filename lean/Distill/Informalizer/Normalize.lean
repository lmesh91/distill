import Distill.Informalizer.Normalize.Basic
import Distill.Informalizer.Normalize.Statement

/-!
# Normalization: Presentation IR ⟶ Presentation IR

Normalization is a sequence of *passes*. Each one rewrites a `PresentedDecl` into one that says
the same thing and reads better: it groups objects, attaches a hypothesis to the object it is
about, merges steps, …. A pass does not produce English; that is rendering.

Passes run in ascending `Pass.order`, and passes with the same order in the order they are
listed: the built-in `passes` first, then those a library registered with
`@[distill_normalizer]`, like a recognizer with `@[distill_recognizer]`. A pass that throws is
skipped, so a proof a pass was not written for is presented without it.
-/

namespace Distill.Informalizer

open Lean Meta
open Distill.Informalizer.IR

/-- The built-in passes. -/
def passes : Array Pass := #[
  Normalize.membershipAsProperty,
  Normalize.groupObjects
]

/-- The passes to run, in order. -/
def allPasses (env : Environment) : Array Pass :=
  -- The attribute lists the most recent first.
  let registered := (normalizerAttribute.getValues env `pass).reverse
  -- `mergeSort` is stable.
  ((passes.toList ++ registered).mergeSort (·.order ≤ ·.order)).toArray

/-- Runs the normalization passes on `d`, the presentation of `ir`. Runs inside
`ir.withContext`. -/
def normalize (ir : ProofIR) (d : PresentedDecl) : MetaM PresentedDecl := do
  let mut d := d
  for pass in allPasses (← getEnv) do
    try
      d ← pass.run d ir
    catch _ => pure ()
  return d

end Distill.Informalizer
