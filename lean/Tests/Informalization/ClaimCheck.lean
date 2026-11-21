import Distill.Informalizer.Frontend
import Distill.Definitions.Sets

/-! Verification checks what a step says a hypothesis (introduced or from a `have`) or its goal
is (PR #193 review): a pass that makes such a claim say something else is skipped, although the
evidence still adds up. -/

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

section

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

end

/-- `b` with every `conclude` stating `True` instead of its goal. -/
partial def concludeTrue (b : Block) : Block := { b with steps := b.steps.map fun s =>
  match s.kind with
  | .conclude c => { s with kind := .conclude { c with prop := { expr := mkConst ``True } } }
  | .split k bs => { s with kind := .split k (bs.map fun br => { br with body := concludeTrue br.body }) }
  | .claim c p => { s with kind := .claim c (concludeTrue p) }
  | _ => s }

section

/-- Says that every goal concluded is `True`. -/
@[local distill_normalizer] def conclusionsTrue : Pass where
  name := `Tests.conclusionsTrue
  run d := return { d with proof := concludeTrue d.proof }

/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
  statement: identical to the original statement
  skipped Tests.conclusionsTrue: a step concludes True, but its goal is x✝ ∈ A
-/
#guard_msgs in
#informalize_statement
theorem conclude_check (A B : Set α) : A ∩ B ⊆ A := fun _ hx => hx.left

end

/-! A step that leaves one premise to show, next to one a hypothesis proves, states only the one
it leaves. -/

/--
warning: declaration uses `sorry`
---
info: PresentedDecl leaves_check   role theorem
  objects
    {α} : Type u_1
    {A}, {B}, {C} : Set α
  hypotheses
    f0: C ⊆ A   hyp hCA
    f1: C ⊆ B   hyp hCB
  conclusion
    f2: C ⊆ A ∩ B
  proof of ?g0
    s4 suffices   origin inferred [#4]
      f3: ∀ (x : α), x ∈ C → x ∈ A ∩ B
      by definition Distill.Set.Subset
      proves ?g0: fun x => ?g1 x
    s5 fix   origin partOf [#4]
      x : α   with f6: x ∈ C   hyp hx
      proves ?g1: fun hx => ?g2 hx
    s9 derive   origin partOf [#7]
      f8: x ∈ A   hyp ha
      by f0
      by f6
      by definition Distill.Set.Subset
      proves ?g2: have ha := hCA x hx; ?g3 ha
    s15 suffices   origin partOf [#19]
      f10: x ∈ B
      by lemma And.intro x ∈ A x ∈ B
      by f8
      by definition Distill.Set.Intersection
      by definition Distill.Set.mem
    s12 gap sorry   origin partOf [#19]
      f11: x ∈ B
      proves ?g3: ⟨ha, sorry⟩
English
  Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
  2: By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in C$, $x \in A \cap B$.
  2: Let $x \in C$.
  3: Since $C \subseteq A$ and $x \in C$, we have $x \in A$ by the definition of subset.
  4: Since $x \in A$, by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them) it suffices to show that $x \in B$.
  4: It remains to show that $x \in B$: the Lean proof leaves this out with `sorry`.
Verification
  statement: identical to the original statement
  proof: incomplete (the proof uses `sorry`)
-/
#guard_msgs in
#informalize
theorem leaves_check {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B := by
  intro x hx
  have ha : x ∈ A := hCA x hx
  exact ⟨ha, sorry⟩

/-- `b` with every derived fact that is a Lean hypothesis (a `have`) stating `True` instead. -/
partial def haveTrue (b : Block) : Block := { b with steps := b.steps.map fun s =>
  let wrong (c : Claim) : Claim := if c.hyp?.isSome then { c with prop := { expr := mkConst ``True } } else c
  match s.kind with
  | .derive cs => { s with kind := .derive (cs.map wrong) }
  | .claim c p => { s with kind := .claim (wrong c) (haveTrue p) }
  | .split k bs => { s with kind := .split k (bs.map fun br => { br with body := haveTrue br.body }) }
  | _ => s }

section

/-- Says that every `have` proves `True`. -/
@[local distill_normalizer] def havesTrue : Pass where
  name := `Tests.havesTrue
  run d := return { d with proof := haveTrue d.proof }

/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
  statement: identical to the original statement
  skipped Tests.havesTrue: a step states True for the hypothesis `h`, which is x ∈ A ∧ x ∈ B
-/
#guard_msgs in
#informalize_statement
theorem have_check (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  have h : x ∈ A ∧ x ∈ B := hx
  exact h.left

end
