import Distill.Informalizer.Frontend
import Distill.Definitions.Sets

/-! Verification checks what a step says a hypothesis is (PR #193 review): a pass that makes a
hypothesis's claim say something else is skipped, although the evidence still adds up. -/

open Lean Meta
open Distill
open Distill.Informalizer Distill.Informalizer.IR

/-- `b` with every claim that is a Lean hypothesis stating `True` instead. -/
partial def trueBlock (b : Block) : Block := { b with steps := b.steps.map fun s =>
  let wrong (c : Claim) : Claim := if c.hyp?.isSome then { c with prop := { expr := mkConst ``True } } else c
  match s.kind with
  | .fix os => { s with kind := .fix (os.map fun o => { o with properties := o.properties.map wrong }) }
  | .derive cs => { s with kind := .derive (cs.map wrong) }
  | .assume cs p => { s with kind := .assume (cs.map wrong) p }
  | .split k bs => { s with kind := .split k (bs.map fun br => { br with body := trueBlock br.body }) }
  | .claim c p => { s with kind := .claim (wrong c) (trueBlock p) }
  | _ => s }

/-- Says that every hypothesis of the proof is `True`. -/
@[local distill_normalizer] def hypothesesTrue : Pass where
  name := `Tests.hypothesesTrue
  run d := return { d with proof := trueBlock d.proof }

/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
  statement: identical to the original statement
  skipped Tests.hypothesesTrue: a step states True for the hypothesis `hx`, which is x ∈ A ∩ B
-/
#guard_msgs in
#informalize_statement
theorem claim_check (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  have h : x ∈ A ∧ x ∈ B := hx
  exact h.left
