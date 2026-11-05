import Distill.Informalizer.IR.Common

/-!
# Presentation IR

The Presentation IR records the mathematical argument that a readable proof should make.
It is organized around mathematical reasoning (`ProofStep`), not Lean tactics.

* **Order.** Within every `Block`, and among the branches of every `split`, steps are
  already in presentation order. Renderers walk the structure; they never reorder.
* **Semantics.** Statements are elaborated Lean expressions (`MathExpr`), so the same IR can
  be rendered in several languages and formats. Nothing here is English.
* **Normalization.** Later passes rewrite this IR. They may replace an expression by an
  equal one that reads better, e.g. `∀ x, A x → B x` (with `A B : α → Prop`) by `A ⊆ B` (with
  `A B : Set α`), and record the change in `MathExpr.history` with a proof or a
  definitional-equality claim that Lean can check. They may merge or simplify steps,
  keeping the originals in the new step's `expansion?`.
* **Detail.** Every step can carry a more detailed version of itself (`expansion?`), shown
  when the reader expands the step. Steps justified by automation point at the Proof IR node
  (`Reason.automation`), whose evidence an expansion can be built from.
* **Provenance.** `StepOrigin` links steps to Proof IR tactic nodes and hypotheses. The
  mapping is many-to-many: one tactic can yield several steps (`.partOf`), several tactics
  can be merged (`.consolidated`), and some steps have no tactic at all (`.inferred` from
  elaborated terms or the statement, or `.synthesized` for exposition).

## Free variables

Every free variable in a Presentation IR expression is either a hypothesis of the
corresponding `ProofIR` or the `fvar` of a `MathObject` in scope. Objects that exist only in
the presentation (calling `q.num` "a") get a fresh `FVarId` and a `value?`. The local
context needed to type-check any expression can therefore be rebuilt from the Proof IR and
the objects introduced so far.
-/

namespace Distill.Informalizer.IR

open Lean

/-! ## Mathematical content -/

/-- A change a normalization pass made to an expression. -/
structure Restatement where
  /-- The expression before the change. -/
  before : Expr
  /-- The pass or rule that made it, e.g. `Distill.Normalize.predicateAsSet`. -/
  rule : Name
  /-- A proof that `before` equals the new expression (`Eq`, or `Iff` for propositions).
  `none` means the two are definitionally equal, which `isDefEq` can check. -/
  proof? : Option Expr := none
  deriving Inhabited, Repr

/-- An expression as presented. -/
structure MathExpr where
  expr : Expr
  /-- How `expr` was obtained from the expression extraction produced, oldest change first.
  Empty if unchanged. -/
  history : Array Restatement := #[]
  deriving Inhabited, Repr

/-- A mathematical statement that the proof states, assumes, or establishes. -/
structure Claim where
  /-- Unique within the `PresentedDecl`; `Reason.fact` cites it. -/
  id : Nat
  prop : MathExpr
  /-- The Lean hypothesis this fact is, if any. -/
  hyp? : Option FVarId := none
  deriving Inhabited, Repr

/-- A mathematical object being introduced: "let `x ∈ X`", "obtain `y`", "write `a = num q`". -/
structure MathObject where
  /-- The Lean variable, or a fresh one for an object named only for exposition. -/
  fvar : FVarId
  name : Name
  type : MathExpr
  /-- For objects that abbreviate a term, e.g. `a := q.num`. -/
  value? : Option MathExpr := none
  /-- Structure the object carries: "let `X` be a *topological space*" (`TopologicalSpace X`). -/
  instances : Array MathExpr := #[]
  /-- Properties stated with the introduction: "let `U` be an *open* subset of `E`".
  Normalization can move `assume` facts here. -/
  properties : Array Claim := #[]
  deriving Inhabited, Repr

/-! ## Justifications -/

/-- One reason a step holds. -/
inductive Reason where
  /-- An established fact, instantiated at `args` if it is general ("since `x` is a cluster
  point of `Eᶜ` and `U` is an open neighborhood of `x`, …"). -/
  | fact (id : Nat) (args : Array MathExpr := #[])
  /-- A theorem, possibly applied to `args`. -/
  | lemma (decl : Name) (args : Array MathExpr := #[])
  /-- Unfolding a definition. -/
  | definition (decl : Name)
  /-- Automation at this Proof IR node. Its `AutomationEvidence` and its proof term hold
  whatever detail exists; the step's `expansion?` is built from them when they suffice. -/
  | automation (node : Nat)
  deriving Inhabited, Repr

/-! ## Provenance -/

/-- How a step relates to the Proof IR. -/
inductive OriginRelation where
  /-- The translation of one tactic node. -/
  | direct
  /-- One of several steps translated from the same node(s). -/
  | partOf
  /-- Several nodes merged into one step. -/
  | consolidated
  /-- Read off elaborated data rather than a tactic: the statement, a projection such as
  `hx.1` inside a term, the goal structure, or a definition's unfolding. -/
  | inferred
  /-- Added for exposition only; nothing in Lean corresponds to it. -/
  | synthesized
  deriving Inhabited, Repr, BEq

/-- Where a step came from. -/
structure StepOrigin where
  relation : OriginRelation
  /-- Ids of Proof IR tactic nodes. -/
  nodes : Array Nat := #[]
  hyps : Array FVarId := #[]
  /-- The normalization rule that produced this step, if any. The steps it replaced are in
  the step's `expansion?`. -/
  rule? : Option Name := none
  deriving Inhabited, Repr

/-! ## Steps -/

/-- Why an assumption is made. -/
inductive AssumptionPurpose where
  /-- To prove an implication or a universal statement with a hypothesis. -/
  | forImplication
  /-- To derive a contradiction, proving the negation. -/
  | forContradiction
  deriving Inhabited, Repr, BEq

/-- What a `split` divides the proof into. -/
inductive SplitKind where
  /-- The two directions of `↔`. -/
  | iff
  /-- The conjuncts of `∧`. -/
  | conjunction
  /-- A case distinction, e.g. on `p ∨ q` or on a constructor of `on`. -/
  | cases (on? : Option MathExpr := none)
  /-- Induction on `on`. Each branch's `assumptions` contains its induction hypotheses. -/
  | induction (on : MathExpr)
  deriving Inhabited, Repr

mutual

/-- The mathematical content of a step. -/
inductive StepKind where
  /-- Introduce arbitrary objects: "Let `x ∈ X`." -/
  | fix (objects : Array MathObject)
  /-- "Suppose `P`." -/
  | assume (facts : Array Claim) (purpose : AssumptionPurpose)
  /-- Forward reasoning: "Then `P`." Several facts at once read as "`P` and `Q`". -/
  | derive (facts : Array Claim)
  /-- Use an existential or a structure: "So there is `y` with `y ∈ U ∩ Eᶜ`." -/
  | obtain (objects : Array MathObject) (facts : Array Claim)
  /-- An intermediate claim with its own proof: "We claim `P`. *Proof.* …" -/
  | claim (fact : Claim) (proof : Block)
  /-- Backward reasoning: "It suffices to show `Q`." The reasons explain why `Q` implies the
  current goal. -/
  | suffices (goal : Claim)
  /-- Choose witnesses for an existential goal: "Take `t = N`." `remaining` is what is left to
  prove about the witnesses. -/
  | witness (values : Array MathExpr) (remaining : Claim)
  /-- A chain `a₀ R₁ a₁ R₂ … aₙ` proving `result`, i.e. `a₀ R aₙ`. The result is a `Claim`
  so that later steps can cite it. -/
  | calc (result : Claim) (links : Array CalcLink)
  /-- Divide the proof into branches, presented in order. -/
  | split (kind : SplitKind) (branches : Array Branch)
  /-- Derive a contradiction from the reasons' facts: "This contradicts …". -/
  | contradiction
  /-- "Hence `P`", where `P` is the goal of the enclosing block. -/
  | conclude (goal : Claim)
  deriving Repr

/-- One link `aᵢ₋₁ Rᵢ aᵢ` of a calculation. -/
structure CalcLink where
  relation : Claim
  reasons : Array Reason := #[]
  deriving Repr

/-- One branch of a `split`. -/
structure Branch where
  /-- Lean's case tag (`mp`, `mpr`, `inl`, `succ`, …), anonymous if there is none. -/
  tag : Name := .anonymous
  /-- Objects the branch introduces, e.g. `n` in the `n + 1` case. -/
  objects : Array MathObject := #[]
  /-- Case hypotheses and induction hypotheses. -/
  assumptions : Array Claim := #[]
  body : Block
  deriving Repr

/-- A sequence of steps proving `goal?`, in presentation order. -/
structure Block where
  goal? : Option Claim := none
  steps : Array ProofStep
  deriving Repr

/-- One step of mathematical reasoning. -/
structure ProofStep where
  /-- Unique within the `PresentedDecl`. -/
  id : Nat
  kind : StepKind
  /-- Why the step holds. Empty if it needs no stated reason. -/
  reasons : Array Reason := #[]
  origin : StepOrigin
  /-- A more detailed version of this step, proving the same thing: the steps a
  normalization pass merged into this one, or a breakdown built from automation evidence.
  Interactive output shows it when the reader expands the step. -/
  expansion? : Option Block := none
  deriving Repr

end

instance : Inhabited StepKind := ⟨.contradiction⟩
instance : Inhabited Block := ⟨{ steps := #[] }⟩
instance : Inhabited Branch := ⟨{ body := default }⟩
instance : Inhabited CalcLink := ⟨{ relation := default }⟩
instance : Inhabited ProofStep := ⟨{ id := default, kind := default, origin := default }⟩

/-! ## Declarations -/

/-- How a declaration is labeled in the presentation. -/
inductive DeclRole where
  | theorem
  | lemma
  | example
  deriving Inhabited, Repr, BEq

/-- The presentation of one declaration: its statement and proof. -/
structure PresentedDecl where
  decl : Name
  role : DeclRole
  /-- "Let `X` be a topological space and `E ⊆ X`." -/
  objects : Array MathObject
  /-- Hypotheses of the statement. -/
  hypotheses : Array Claim
  conclusion : Claim
  proof : Block
  deriving Inhabited, Repr

/-- A document: several related declarations in presentation order. A proof that relies on
an earlier declaration of the same document cites it with `Reason.lemma`, which lets a
renderer write "by the lemma" instead of a Lean name. -/
structure Document where
  decls : Array PresentedDecl
  deriving Inhabited, Repr

end Distill.Informalizer.IR
