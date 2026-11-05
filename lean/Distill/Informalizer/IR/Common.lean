import Lean

/-!
# Shared IR types

Types used by both the Proof IR (`Distill.Informalizer.IR.Proof`) and the Presentation IR
(`Distill.Informalizer.IR.Presentation`).

Expressions are elaborated `Lean.Expr` values, never strings. Free variables in them are
`FVarId`s from the enclosing `ProofIR`'s hypothesis table: Lean allocates every `FVarId` of
one declaration from a single name generator, so the ids are unique within it. Goals are
identified by their `MVarId`. Declarations are referred to by `Name`; their kind and module
are looked up in the environment when needed.

Distill's own ids are plain `Nat`s: a tactic node's id is its index in `ProofIR.nodes`, and
step and fact ids are numbers unique within a `PresentedDecl`.
-/

namespace Distill.Informalizer.IR

open Lean

/-- A region of the source file, as Lean positions (1-based line, 0-based column). -/
structure SourceSpan where
  start : Position
  stop : Position
  deriving Inhabited, Repr, BEq

/-- Where a piece of syntax came from. -/
inductive SyntaxOrigin where
  /-- Written by the user. -/
  | original (span : SourceSpan)
  /-- Produced by a macro or elaborator. Lean copies the range of the syntax it was generated
  from, so `span` points at the user's text that caused it. -/
  | synthetic (span : SourceSpan)
  /-- No position information. -/
  | none
  deriving Inhabited, Repr, BEq

/-- Extension data has no structure Distill knows about; show only its type. -/
instance : Repr Dynamic := ⟨fun d _ => s!"<{d.typeName}>"⟩

end Distill.Informalizer.IR
