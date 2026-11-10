import Distill.Informalizer.Frontend
import Distill.Levels.Demo

/-! The pipeline's stages on proofs of different shapes, and what a library can add to it. -/

open Distill Distill.Levels.Demo
open Distill.Informalizer Distill.Informalizer.IR

/-! ## Shapes -/

/-! Binders that are propositions become hypotheses, the others objects. A nested `by` block's
tactics are steps of their own. -/
/--
info: PresentedDecl nested   role theorem
  objects
    α : Type u_1
    A : Set α
    B : Set α
    C : Set α
  hypotheses
    f0: C ⊆ A   hyp hCA
    f1: C ⊆ B   hyp hCB
  conclusion
    f2: C ⊆ A ∩ B
  proof
    s3 untranslated `intro x hx`   origin direct [#4]
    s4 untranslated `have ha : x ∈ A := by …`   origin direct [#7]
    s5 untranslated `exact hCA x hx`   origin direct [#23]
    s6 untranslated `exact ⟨ha, hCB x hx⟩`   origin direct [#24]
English
  Theorem. Let `α : Type u_1`, `A : Set α`, `B : Set α` and `C : Set α`. Assume `C ⊆ A` and `C ⊆ B`. Then `C ⊆ A ∩ B`.
  2: Apply `intro x hx`.
  3: Apply `have ha : x ∈ A := by …`.
  4: Apply `exact hCA x hx`.
  5: Apply `exact ⟨ha, hCB x hx⟩`.
-/
#guard_msgs in
#informalize
theorem nested {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B := by
  intro x hx
  have ha : x ∈ A := by
    exact hCA x hx
  exact ⟨ha, hCB x hx⟩

/-! A term proof is one step, and the `by` blocks in it are further steps. -/
/--
info: PresentedDecl _example   role example
  objects
    p : Prop
    q : Prop
  hypotheses
    f0: p   hyp hp
    f1: q   hyp hq
  conclusion
    f2: p ∧ q
  proof
    s3 untranslated `⟨hp, by exact hq⟩`   origin direct [#0]
    s4 untranslated `exact hq`   origin direct [#5]
English
  Example. Let `p : Prop` and `q : Prop`. Assume `p` and `q`. Then `p ∧ q`.
  1: Apply `⟨hp, by exact hq⟩`.
  1: Apply `exact hq`.
-/
#guard_msgs in
#informalize
example (p q : Prop) (hp : p) (hq : q) : p ∧ q := ⟨hp, by exact hq⟩

/-! A statement without binders. -/
/--
info: PresentedDecl no_binders   role theorem
  objects
  hypotheses
  conclusion
    f0: ∀ (p : Prop), p → p
  proof
    s1 untranslated `intro p hp`   origin direct [#4]
    s2 untranslated `exact hp`   origin direct [#7]
English
  Theorem. `∀ (p : Prop), p → p`.
  2: Apply `intro p hp`.
  3: Apply `exact hp`.
-/
#guard_msgs in
#informalize
theorem no_binders : ∀ p : Prop, p → p := by
  intro p hp
  exact hp

/-! A `by` block that is not a declaration's body has steps but no statement. -/
/--
info: PresentedDecl positive   role theorem
  objects
  hypotheses
  conclusion
    f0: 1 > 0
  proof
    s1 untranslated `decide`   origin direct [#4]
English
  1: Apply `decide`.
-/
#guard_msgs in
#informalize
def positive : { n : Nat // n > 0 } := ⟨1, by decide⟩

/-! An unfinished proof and a proof with an error are still presented. -/
/--
warning: declaration uses `sorry`
---
info: PresentedDecl unfinished   role theorem
  objects
    α : Type u_1
    A : Set α
    B : Set α
  hypotheses
  conclusion
    f0: A ∩ B ⊆ A
  proof
    s1 untranslated `intro x hx`   origin direct [#4]
    s2 untranslated `sorry`   origin direct [#7]
English
  Theorem. Let `α : Type u_1`, `A : Set α` and `B : Set α`. Then `A ∩ B ⊆ A`.
  2: Apply `intro x hx`.
  3: Apply `sorry`.
-/
#guard_msgs in
#informalize
theorem unfinished (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  sorry

/--
error: Type mismatch
  hx
has type
  x ∈ A ∩ B
but is expected to have type
  x ∈ A
---
info: PresentedDecl failing   role theorem
  objects
    α : Type u_1
    A : Set α
    B : Set α
  hypotheses
  conclusion
    f0: A ∩ B ⊆ A
  proof
    s1 untranslated `intro x hx`   origin direct [#4]
English
  Theorem. Let `α : Type u_1`, `A : Set α` and `B : Set α`. Then `A ∩ B ⊆ A`.
  2: Apply `intro x hx`.
-/
#guard_msgs in
#informalize
theorem failing (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  exact hx

/-! A command without proofs. -/
/--
info: no proofs
-/
#guard_msgs in
#informalize
def notAProof : Nat := 1

/-! ## Code in rich text

The fence is longer than any run of backticks in the code. -/
#guard code "exact hx" == "`exact hx`"
#guard code "exact `a" == "``exact `a``"
#guard code "``a" == "``` ``a ```"

/-! ## Passes from a library

Passes registered with `@[distill_normalizer]` run in ascending `order`, and one that throws is
skipped. -/

/-- States the hypotheses in the opposite order. -/
@[local distill_normalizer] def reverseHypotheses : Pass where
  name := `Tests.reverseHypotheses
  order := 700
  run d := return { d with hypotheses := d.hypotheses.reverse }

/-- Runs first, so `reverseHypotheses` puts back what it dropped last. -/
@[local distill_normalizer] def dropLastHypothesis : Pass where
  name := `Tests.dropLastHypothesis
  order := 600
  run d := return { d with hypotheses := d.hypotheses.pop }

@[local distill_normalizer] def failingPass : Pass where
  name := `Tests.failingPass
  run _ := throwError "not applicable"

/--
info: PresentedDecl with_passes   role theorem
  objects
    α : Type u_1
    A : Set α
    B : Set α
    C : Set α
  hypotheses
    f1: C ⊆ B   hyp hCB
    f0: C ⊆ A   hyp hCA
  conclusion
    f3: C ⊆ A ∩ B
  proof
    s4 untranslated `exact subset_inter hCA hCB`   origin direct [#4]
English
  Theorem. Let `α : Type u_1`, `A : Set α`, `B : Set α` and `C : Set α`. Assume `C ⊆ B` and `C ⊆ A`. Then `C ⊆ A ∩ B`.
  2: Apply `exact subset_inter hCA hCB`.
-/
#guard_msgs in
#informalize
theorem with_passes {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) (_hAB : A ⊆ B) : C ⊆ A ∩ B := by
  exact subset_inter hCA hCB
