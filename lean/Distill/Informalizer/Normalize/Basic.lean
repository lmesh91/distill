import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation

/-!
# Normalization passes

What a pass is, and how a library registers one. The passes themselves are in the other files of
this directory, and `Distill.Informalizer.Normalize` runs them.
-/

namespace Distill.Informalizer

open Lean Meta
open Distill.Informalizer.IR

/-- Passes can read the Proof IR, and run inside `ProofIR.withContext`: every hypothesis is in the
local context and every goal is declared. -/
abbrev NormalizeM := ReaderT ProofIR MetaM

/-- One normalization pass. -/
structure Pass where
  /-- Recorded where the pass says what it did (`Restatement.rule`, `StepOrigin.rule?`). -/
  name : Name
  /-- Passes run in ascending order. -/
  order : Nat := 500
  run : PresentedDecl → NormalizeM PresentedDecl
  deriving Inhabited

/-- `@[distill_normalizer] def p : Pass := …` adds `p` to the passes that normalize every
presentation. -/
unsafe initialize normalizerAttribute : KeyedDeclsAttribute Pass ←
  KeyedDeclsAttribute.init {
    builtinName := `builtin_distill_normalizer
    name := `distill_normalizer
    descr := "a pass that normalizes Distill's Presentation IR"
    valueTypeName := ``Pass
    -- The attribute has no argument: every pass is stored under the same key.
    evalKey := fun _ _ => pure `pass }

end Distill.Informalizer
