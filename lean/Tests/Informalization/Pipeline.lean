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
    s4 suffices   origin inferred [#4]
      f3: ∀ (x : α), x ∈ C → x ∈ A ∩ B
      by definition Distill.Set.Subset
      proves ?g0: fun x => ?g1 x
    s5 fix   origin partOf [#4]
      x : α   with f6: x ∈ C   hyp hx
      proves ?g1: fun hx => ?g2 hx
    s11 claim   origin partOf [#7]
      f8: x ∈ A
      s10 conclude   origin partOf [#23 #7]
        f9: x ∈ A
        by f0
        by f6
        by definition Distill.Set.Subset
        proves ?g2: have ha := ?g3; ?g4 ha
        proves ?g3: hCA x hx
    s13 derive   origin partOf [#24]
      f12: x ∈ B
      by f1
      by f6
      by definition Distill.Set.Subset
    s15 conclude   origin partOf [#24]
      f14: x ∈ A ∩ B
      by lemma And.intro x ∈ A x ∈ B
      by f8
      by f12
      by definition Distill.Set.Intersection
      by definition Distill.Set.mem
      proves ?g4: ⟨ha, hCB x hx⟩
English
  Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
  2: By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in C$, $x \in A \cap B$.
  2: Let $x \in C$.
  3: We claim that $x \in A$.
  4: This follows from $C \subseteq A$ and $x \in C$ by the definition of subset.
  5: Since $C \subseteq B$ and $x \in C$, we have $x \in B$ by the definition of subset.
  5: Since $x \in A$ and $x \in B$, we conclude that $x \in A \cap B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them).
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
    s5 suffices   origin partOf [#0]
      f4: q
      by lemma And.intro p q
      by f0
      proves ?g0: ⟨hp, ?g1⟩
    s7 conclude   origin partOf [#5]
      f6: q
      by f1
      proves ?g1: hq
English
  Example. Let $p$ and $q$ be propositions. If $p$ and $q$, then $p$ and $q$.
  1: Since $p$, it suffices to show that $q$.
  1: We already know that $q$, which is what we needed to show.
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
      proves ?g0: fun p => ?g1 p
    s3 assume   origin partOf [#4]
      f2: p   hyp hp
      proves ?g1: fun hp => ?g2 hp
    s5 conclude   origin partOf [#7]
      f4: p
      by f2
      proves ?g2: hp
English
  Theorem. For every proposition $p$, if $p$, then $p$.
  2: Let $p$ be a proposition.
  2: Suppose that $p$.
  3: We already know that $p$, which is what we needed to show.
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
  1: Lean proves `1 > 0` here with the step `decide`, which is not translated into English yet.
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
    s2 suffices   origin inferred [#4]
      f1: ∀ (x : α), x ∈ A ∩ B → x ∈ A
      by definition Distill.Set.Subset
      proves ?g0: fun x => ?g1 x
    s3 fix   origin partOf [#4]
      x : α   with f4: x ∈ A ∩ B   hyp hx
      proves ?g1: fun hx => ?g2 hx
    s7 gap sorry   origin partOf [#7]
      f6: x ∈ A
      proves ?g2: sorry
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
  2: By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$.
  2: Let $x \in A \cap B$.
  3: It remains to show that $x \in A$: the Lean proof leaves this out with `sorry`.
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
    s2 suffices   origin inferred [#4]
      f1: ∀ (x : α), x ∈ A ∩ B → x ∈ A
      by definition Distill.Set.Subset
      proves ?g0: fun x => ?g1 x
    s3 fix   origin partOf [#4]
      x : α   with f4: x ∈ A ∩ B   hyp hx
      proves ?g1: fun hx => ?g2 hx
    s7 gap unfinished   origin partOf [#4]
      f6: x ∈ A
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
  2: By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$.
  2: Let $x \in A \cap B$.
  2: It remains to show that $x \in A$, which the Lean proof does not do yet.
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
    s5 conclude   origin partOf [#4]
      f4: C ⊆ A ∩ B
      by lemma Distill.Levels.Demo.subset_inter α A B C
      by f0
      by f1
      proves ?g0: subset_inter hCA hCB
English
  Theorem. Let $A$, $B$ and $C$ be sets. If $A \subseteq B$, $C \subseteq B$ and $C \subseteq A$, then $C \subseteq A \cap B$.
  2: Since $C \subseteq A$ and $C \subseteq B$, we conclude that $C \subseteq A \cap B$ by the earlier theorem that for all sets $A$, $B$ and $C$, if $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
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
    s10 split   origin partOf [#4]
      branch f4: p
        s6 gap error   origin partOf [#4]
          f5: p
          proves ?g0: ⟨?g1, ?g2⟩
          proves ?g1: sorry
      branch f7: q
        s9 conclude   origin partOf [#14]
          f8: q
          by f1
          proves ?g2: hq
English
  Theorem. Let $p$ and $q$ be propositions. If $q$ and $p$, then $p$ and $q$.
  2: First, we show that $p$.
  2: Lean reports an error here, so this is not proved yet.
  4: Next, we show that $q$.
  4: We already know this.
Verification
  statement: equivalent to the original statement (proof checked)
  proof: incomplete (the proof uses `sorry`)
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
    s1 untranslated `intro x hx`   origin direct [#4]
      proves ?g0: fun x => ?g1 x
      proves ?g1: fun hx => ?g2 hx
    s2 fix   origin partOf [#4]
      x : α
    s4 derive   origin partOf [#4]
      f3: x ∈ A ∩ B   hyp hx
      by automation #4
    s6 derive   origin partOf [#7]
      f5: x ∈ A ∧ x ∈ B
      by f3
      by definition Distill.Set.Intersection
      by definition Distill.Set.mem
    s8 conclude   origin partOf [#7]
      f7: x ∈ A
      by lemma And.left x ∈ A x ∈ B
      by f5
      proves ?g2: hx.left
English
  Theorem. `∀ {α : Type u_1} (A B : Set α), A ∩ B ⊆ A`.
  2: The Lean proof continues with `intro x hx`.
  3: The Lean proof continues with `exact hx.left`.
Verification
  statement: NOT VERIFIED: the Proof IR does not have the statement of the declaration
  proof: NOT VERIFIED: the steps prove a different statement
-/
#guard_msgs in
#informalize_wrong_ir
theorem quoted (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  exact hx.left
