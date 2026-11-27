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
    {α} : Type u_1
    {A}, {B}, {C} : Set α
  hypotheses
    f0: C ⊆ A   hyp hCA
    f1: C ⊆ B   hyp hCB
  conclusion
    f2: C ⊆ A ∩ B
  proof of ?g0
    s3 fix   origin direct [#4]
      x : α   with f4: x ∈ C   hyp hx
      proves ?g0: fun x hx => @?g2 x hx
    s5 claim   origin direct [#7]
      f6: x ∈ A   hyp ha
      proves ?g2: have ha := ?g3; ?g4 ha
      s7 conclude   origin direct [#23]
        f8: x ∈ A
        by hCA x hx
        proves ?g3: hCA x hx
    s9 conclude   origin direct [#24]
      f10: x ∈ A ∩ B
      by ⟨ha, hCB x hx⟩
      proves ?g4: ⟨ha, hCB x hx⟩
English
  Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
  2: Let $x \in C$.
  3: We claim that $x \in A$.
  4: Thus $x \in A$ by `hCA x hx`.
  5: Thus $x \in A \cap B$ by `⟨ha, hCB x hx⟩`.
Verification
  statement: identical to the original statement
  proof: the steps rebuild a proof of the presented statement
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
    p, q : Prop
  hypotheses
    f0: p   hyp hp
    f1: q   hyp hq
  conclusion
    f2: p ∧ q
  proof of ?g0
    s3 untranslated `⟨hp, by exact hq⟩`   origin direct [#0]
      proves ?g0: ⟨hp, ?g1⟩
    s4 conclude   origin direct [#5]
      f5: q
      by hq
      proves ?g1: hq
English
  Example. Let $p$ and $q$ be propositions. If $p$ and $q$, then $p$ and $q$.
  1: Apply `⟨hp, by exact hq⟩`.
  1: Thus $q$ by `hq`.
Verification
  statement: identical to the original statement
  proof: the steps rebuild a proof of the presented statement
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
  proof of ?g0
    s1 fix   origin partOf [#4]
      p : Prop
      proves ?g0: fun p hp => @?g2 p hp
    s3 assume   origin partOf [#4]
      f2: p   hyp hp
    s4 conclude   origin direct [#7]
      f5: p
      by hp
      proves ?g2: hp
English
  Theorem. For every proposition $p$, if $p$, then $p$.
  2: Let $p$ be a proposition.
  2: Suppose that $p$.
  3: Thus $p$ by `hp`.
Verification
  statement: identical to the original statement
  proof: the steps rebuild a proof of the presented statement
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
  proof of ?g0
    s1 untranslated `decide`   origin direct [#4]
      proves ?g0: of_decide_eq_true (id (Eq.refl true))
English
  1: Apply `decide`.
Verification
  statement: identical to the original statement
  proof: the steps rebuild a proof of the presented statement
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
    {α} : Type u_1
    A, B : Set α
  hypotheses
  conclusion
    f0: A ∩ B ⊆ A
  proof of ?g0
    s1 fix   origin direct [#4]
      x : α   with f2: x ∈ A ∩ B   hyp hx
      proves ?g0: fun x hx => @?g2 x hx
    s3 untranslated `sorry`   origin direct [#7]
      proves ?g2: sorry
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
  2: Let $x \in A \cap B$.
  3: Apply `sorry`.
Verification
  statement: identical to the original statement
  proof: incomplete (the proof uses `sorry`)
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
    {α} : Type u_1
    A, B : Set α
  hypotheses
  conclusion
    f0: A ∩ B ⊆ A
  proof of ?g0
    s1 fix   origin direct [#4]
      x : α   with f2: x ∈ A ∩ B   hyp hx
      proves ?g0: fun x hx => @?g2 x hx
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
  2: Let $x \in A \cap B$.
Verification
  statement: identical to the original statement
  proof: incomplete (no step proves ?g2)
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

/-! ## Code in text as markup

The fence is longer than any run of backticks in the code. -/
#guard (Text.code "exact hx").toMarkup == "`exact hx`"
#guard (Text.code "exact `a").toMarkup == "``exact `a``"
#guard (Text.code "``a").toMarkup == "``` ``a ```"

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
    {α} : Type u_1
    {A}, {B}, {C} : Set α
  hypotheses
    f2: A ⊆ B   hyp _hAB
    f1: C ⊆ B   hyp hCB
    f0: C ⊆ A   hyp hCA
  conclusion
    f3: C ⊆ A ∩ B
  proof of ?g0
    s4 conclude   origin direct [#4]
      f5: C ⊆ A ∩ B
      by subset_inter hCA hCB
      proves ?g0: subset_inter hCA hCB
English
  Theorem. Let $A$, $B$ and $C$ be sets. If $A \subseteq B$, $C \subseteq B$ and $C \subseteq A$, then $C \subseteq A \cap B$.
  2: Thus $C \subseteq A \cap B$ by `subset_inter hCA hCB`.
Verification
  statement: equivalent to the original statement (proof checked)
  proof: the steps rebuild a proof of the presented statement
  skipped Tests.failingPass: not applicable
  skipped Tests.dropLastHypothesis: _hAB is missing from the presented statement
-/
#guard_msgs in
#informalize
theorem with_passes {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) (_hAB : A ⊆ B) : C ⊆ A ∩ B := by
  exact subset_inter hCA hCB

/-! A tactic that fails alone in a bullet leaves its goal to Lean's `sorry`. The proof is
unfinished, not wrongly presented. -/
/--
error: Type mismatch
  hq
has type
  q
but is expected to have type
  p
---
info: PresentedDecl failing_bullet   role theorem
  objects
    p, q : Prop
  hypotheses
    f1: q   hyp hq
    f0: p   hyp hp
  conclusion
    f2: p ∧ q
  proof of ?g0
    s3 untranslated `constructor`   origin direct [#4]
      proves ?g0: ⟨?g1, ?g2⟩
    s4 conclude   origin direct [#14]
      f5: q
      by hq
      proves ?g2: hq
English
  Theorem. Let $p$ and $q$ be propositions. If $q$ and $p$, then $p$ and $q$.
  2: Apply `constructor`.
  4: Thus $q$ by `hq`.
Verification
  statement: equivalent to the original statement (proof checked)
  proof: incomplete (no step proves ?g1)
  skipped Tests.failingPass: not applicable
  skipped Tests.dropLastHypothesis: hq is missing from the presented statement
-/
#guard_msgs in
#informalize
theorem failing_bullet (p q : Prop) (hp : p) (hq : q) : p ∧ q := by
  constructor
  · exact hq
  · exact hq

/-! ## A presentation that does not verify

Only a presentation that `verify` accepts is rendered. If even the direct presentation is not
one, as for this Proof IR whose statement is not the theorem's, the proof is shown as the Lean it
is. -/

/-- `#informalize` for a Proof IR that claims to prove `True`. -/
elab "#informalize_wrong_ir " cmd:command : command =>
  elabAndDescribe cmd fun ir lineOffset =>
    report { ir with statement.conclusion := Lean.mkConst ``True } lineOffset

/--
info: PresentedDecl quoted   role theorem
  objects
    {α} : Type u_1
    A : Set α
    B : Set α
  hypotheses
  conclusion
    f0: True
  proof of ?g0
    s1 fix   origin direct [#4]
      x : α   with f2: x ∈ A ∩ B   hyp hx
      proves ?g0: fun x hx => @?g2 x hx
    s3 conclude   origin direct [#7]
      f4: x ∈ A
      by hx.left
      proves ?g2: hx.left
English
  Theorem. `∀ {α : Type u_1} (A B : Set α), A ∩ B ⊆ A`.
  2: Apply `intro x hx`.
  3: Apply `exact hx.left`.
Verification
  statement: NOT VERIFIED: the Proof IR does not have the statement of the declaration
  proof: NOT VERIFIED: the steps prove a different statement
-/
#guard_msgs in
#informalize_wrong_ir
theorem quoted (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  exact hx.left
