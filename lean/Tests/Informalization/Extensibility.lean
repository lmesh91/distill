import Distill.Informalizer.Frontend
import Distill.Definitions.Sets

/-! What a library adds to the informalizer for its own definitions: translators for rendering,
and normalization passes, whose work `verify` checks. -/

open Lean Meta
open Distill
open Distill.Informalizer Distill.Informalizer.IR

set_option warn.sorry false

/-! ## Translators -/

def Distill.Set.compl (A : Set α) : Set α := {x | ¬ x ∈ A}

def Disjoint (A B : Set α) : Prop := ∀ x, x ∈ A → x ∈ B → False

/-! Without translators, the library's definitions are shown as Lean code. -/

/--
info: Theorem. Let $A$ and $B$ be sets of terms of type `Nat` and let $n \in A$. If `Disjoint A B.compl`, then $n \in B$.
  statement: equivalent to the original statement (proof checked)
-/
#guard_msgs in
#informalize_statement
theorem before (A B : Set Nat) (n : Nat) (h : Disjoint A B.compl) (hn : n ∈ A) : n ∈ B := sorry

section
/-- `A.compl` is `A^c`. -/
@[local distill_translator Distill.Set.compl] def mathCompl : Translator := .math fun r e => do
  unless e.isAppOfArity ``Set.compl 2 do return none
  let some a ← r.math e.appArg! | return none
  return some { tex := s!"{a.at 1024}^c", prec := 1023 }

@[local distill_translator Disjoint] def proseDisjoint : Translator := .prose fun r e => do
  unless e.isAppOfArity ``Disjoint 3 do return none
  let some a ← r.math (e.getArg! 1) | return none
  let some b ← r.math (e.getArg! 2) | return none
  return some { text := a.text ++ " and " ++ b.text ++ " are disjoint" }

@[local distill_translator Nat] def nounNat : Translator := .noun fun _ _ =>
  return some { singular := "natural number", plural := "natural numbers" }

/--
info: Theorem. Let $A$ and $B$ be sets of natural numbers and let $n \in A$. If $A$ and $B^c$ are disjoint, then $n \in B$.
  statement: equivalent to the original statement (proof checked)
-/
#guard_msgs in
#informalize_statement
theorem after (A B : Set Nat) (n : Nat) (h : Disjoint A B.compl) (hn : n ∈ A) : n ∈ B := sorry

/-! Translators compose with the built-in ones, and with each other. -/

/--
info: Theorem. Let $A$ and $B$ be sets of natural numbers. Then for every $n \in ((A \cap B)^c)^c$, if $A$ and $B$ are disjoint, then $n \in A^c \cup B$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem composed (A B : Set Nat) : ∀ n : Nat, n ∈ (A ∩ B).compl.compl → Disjoint A B → n ∈ A.compl ∪ B :=
  sorry

/-! A translator that throws or returns `none` leaves the expression to the next one. -/

@[local distill_translator Inter.inter] def mathInterNever : Translator := .math fun _ _ =>
  throwError "not applicable"

@[local distill_translator HasSubset.Subset] def proseSubsetNever : Translator := .prose fun _ _ =>
  return none

/--
info: Theorem. Let $A$ and $B$ be sets of natural numbers. Then $A \cap B \subseteq A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem next_translator (A B : Set Nat) : A ∩ B ⊆ A := sorry

end

/-! ## Adjectives and accessories

A property of an object can be said where the object is introduced. A pass says which
hypotheses are properties of which object, and translators say them as adjectives or
accessories. -/

def Small (_ : Set α) : Prop := True
def Tidy (_ : Set α) : Prop := True
def HasCorners (_ : Set α) : Prop := True
def Odd (_ : Set α) : Prop := True

/-- The object a predicate of one argument is about. -/
def predicateSubject? (e : Expr) : Option FVarId :=
  if [``Small, ``Tidy, ``HasCorners, ``Odd].any (e.isAppOfArity · 2) then e.appArg!.fvarId?
  else none

/-- The translators below must only speak about the object being described. -/
def aboutSubject (e : Expr) : RenderM Bool :=
  return predicateSubject? e == (← read).subject? && (← read).subject?.isSome

section
@[local distill_normalizer] def predicatesAsProperties : Pass where
  name := `Tests.predicatesAsProperties
  order := 200
  run d := Normalize.hypothesesAsProperties d predicateSubject?

@[local distill_translator Small] def adjectiveSmall : Translator := .adjective fun _ e => do
  unless ← aboutSubject e do return none
  return some { text := "small" }

@[local distill_translator Tidy] def adjectiveTidy : Translator := .adjective fun _ e => do
  unless ← aboutSubject e do return none
  return some { text := "tidy" }

@[local distill_translator HasCorners] def accessoryCorners : Translator := .accessory fun _ e => do
  unless ← aboutSubject e do return none
  return some { text := "corners" }

/--
info: Theorem. Let $A$ and $B$ be small tidy sets and let $C$ be a set with corners. If $A \subseteq B$, then $A \subseteq C$.
  statement: equivalent to the original statement (proof checked)
-/
#guard_msgs in
#informalize_statement
theorem described (A B C : Set α) (hA : Small A) (hA' : Tidy A) (hB : Small B) (hB' : Tidy B)
    (hC : HasCorners C) (h : A ⊆ B) : A ⊆ C := sorry

/-! A hypothesis that is not a property of one object is stated as before, and a property
without words follows "such that". -/

/--
info: Theorem. Let $\alpha$ be a type, let $A$ be a small set of elements of $\alpha$, and let $B$ be a set of elements of $\alpha$ such that `Odd B`. If `Small (A ∩ B)`, then $A \subseteq B$.
  statement: equivalent to the original statement (proof checked)
-/
#guard_msgs in
#informalize_statement
theorem undescribed (A B : Set α) (hA : Small A) (hB : Small (A ∩ B)) (hB' : Odd B) : A ⊆ B := sorry
end

/-! ## New kinds of phrases

The kinds above are the ones the built-in renderer asks for, not the only ones there can be. A
library defines a kind as a type, registers translators for it like any other, and asks for
such phrases where it writes prose. -/

/-- "do not meet", in "$A$ and $B$ do not meet". -/
structure Verb where
  plural : String
  deriving TypeName

section
@[local distill_translator Disjoint] def verbDisjoint : Translator := .of fun _ _ =>
  return some ({ plural := "do not meet" } : Verb)

/-- "$A$ and $B$ `verb`", for a relation between two things that has a verb. -/
@[local distill_translator Disjoint] def proseVerb : Translator := .prose fun r e => do
  let some verb ← r.phrase? Verb e | return none
  let some a ← r.math (e.getArg! 1) | return none
  let some b ← r.math (e.getArg! 2) | return none
  return some { text := a.text ++ " and " ++ b.text ++ s!" {verb.plural}" }

/--
info: Theorem. Let $A$ and $B$ be sets. If $A$ and $B$ do not meet, then $A \subseteq A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem verbs (A B : Set α) (h : Disjoint A B) : A ⊆ A := sorry
end

/-! ## Passes that restate

A pass that replaces an expression records the old one in `MathExpr.history`. Without a proof,
the two have to be definitionally equal. -/

/-- Restates `expr` as `new`, by the proof `proof?` of `expr ↔ new` if there is one. -/
def restate (m : MathExpr) (rule : Name) (new : Expr) (proof? : Option Expr := none) : MathExpr :=
  { expr := new, history := m.history.push { before := m.expr, rule, proof? } }

/-- `∀ x, x ∈ A → x ∈ B`, as `(A, B)`. -/
def unfoldedSubset? (e : Expr) : Option (Expr × Expr) := do
  let .forallE _ _ (.forallE _ p q _) _ := e | none
  let (a, .bvar 0) ← membership? p | none
  let (b, .bvar 1) ← membership? q | none
  guard (!a.hasLooseBVars && !b.hasLooseBVars)
  return (a, b)

section
/-- A hypothesis `∀ x, x ∈ A → x ∈ B` is stated as `A ⊆ B`. -/
@[local distill_normalizer] def foldSubset : Pass where
  name := `Tests.foldSubset
  run d := do
    let hypotheses ← d.hypotheses.mapM fun h => do
      let some (a, b) := unfoldedSubset? h.prop.expr | return h
      return { h with prop := restate h.prop `Tests.foldSubset (← mkAppM ``HasSubset.Subset #[a, b]) }
    return { d with hypotheses }

/--
info: PresentedDecl folded   role theorem
  objects
    {α} : Type u_1
    A, B : Set α
    x : α   with f1: x ∈ A   hyp hx
  hypotheses
    f0: A ⊆ B  ⟸ ∀ (x : α), x ∈ A → x ∈ B  [Tests.foldSubset, defeq]   hyp h
  conclusion
    f2: x ∈ B
  proof of ?g0
    s3 untranslated `exact h x hx`   origin direct [#4]
      proves ?g0: h x hx
English
  Theorem. Let $A$ and $B$ be sets and let $x \in A$. If $A \subseteq B$, then $x \in B$.
  2: Apply `exact h x hx`.
Verification
  statement: equivalent to the original statement (proof checked)
  proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#informalize
theorem folded (A B : Set α) (h : ∀ x, x ∈ A → x ∈ B) (x : α) (hx : x ∈ A) : x ∈ B := by
  exact h x hx
end

/-! With a proof, the statements are equivalent, and the proof of the original statement is
carried over to the presented one. -/

section
/-- Equations are written the other way around. -/
@[local distill_normalizer] def flipEquations : Pass where
  name := `Tests.flipEquations
  run d := do
    let flip (c : Claim) : NormalizeM Claim := do
      let some (_, a, b) := c.prop.expr.eq? | return c
      let proof ← mkAppOptM ``eq_comm #[none, a, b]
      return { c with prop := restate c.prop `Tests.flipEquations (← mkEq b a) proof }
    return { d with hypotheses := ← d.hypotheses.mapM flip, conclusion := ← flip d.conclusion }

/--
info: PresentedDecl flipped   role theorem
  objects
    {α} : Type u_1
    A, B, C : Set α
  hypotheses
    f0: B = A  ⟸ A = B  [Tests.flipEquations, proved]   hyp hAB
    f1: B = C  ⟸ C = B  [Tests.flipEquations, proved]   hyp hBC
  conclusion
    f2: C = A  ⟸ A = C  [Tests.flipEquations, proved]
  proof of ?g0
    s3 untranslated `rw [hAB, hBC]`   origin direct [#4]
      proves ?g0: Eq.mpr (id (congrArg (fun _a => _a = C) hAB)) (Eq.mpr (id (congrArg (fun _a => B = _a) hBC)) (Eq.refl B))
English
  Theorem. Let $A$, $B$ and $C$ be sets. If $B = A$ and $B = C$, then $C = A$.
  2: Apply `rw [hAB, hBC]`.
Verification
  statement: equivalent to the original statement (proof checked)
  proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#informalize
theorem flipped (A B C : Set α) (hAB : A = B) (hBC : C = B) : A = C := by
  rw [hAB, hBC]
end

/-! ## Passes that are wrong

`verify` does not accept a presentation that says something else than the proof, so the pipeline
leaves out the pass that made it. -/

section
/-- Claims that `A ⊆ B` can be read as `B ⊆ A`. -/
@[local distill_normalizer] def swapSubset : Pass where
  name := `Tests.swapSubset
  run d := do
    let e := d.conclusion.prop.expr
    unless e.isAppOfArity ``HasSubset.Subset 4 do return d
    let new ← mkAppM ``HasSubset.Subset #[e.getArg! 3, e.getArg! 2]
    return { d with conclusion.prop := restate d.conclusion.prop `Tests.swapSubset new }

/--
info: PresentedDecl swapped   role theorem
  objects
    {α} : Type u_1
    A, B : Set α
  hypotheses
  conclusion
    f0: A ∩ B ⊆ A
  proof of ?g0
    s1 untranslated `intro x hx`   origin direct [#4]
      proves ?g0: fun x hx => @?g2 x hx
    s2 untranslated `exact hx.left`   origin direct [#7]
      proves ?g2: hx.left
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
  2: Apply `intro x hx`.
  3: Apply `exact hx.left`.
Verification
  statement: identical to the original statement
  proof: the steps rebuild a proof of the presented statement
  skipped Tests.swapSubset: Tests.swapSubset restated A ∩ B ⊆ A as A ⊆ A ∩ B, which is not definitionally equal, without a proof
-/
#guard_msgs in
#informalize
theorem swapped (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  exact hx.left
end

section
@[local distill_normalizer] def dropHypotheses : Pass where
  name := `Tests.dropHypotheses
  run d := return { d with hypotheses := #[] }

/--
info: Theorem. Let $A$ and $B$ be sets. If $A \subseteq B$, then $A \cap B = A$.
  statement: identical to the original statement
  skipped Tests.dropHypotheses: h is missing from the presented statement
-/
#guard_msgs in
#informalize_statement
theorem dropped (A B : Set α) (h : A ⊆ B) : A ∩ B = A := sorry
end

section
/-- Forgets the evidence of the last step. -/
@[local distill_normalizer] def dropEvidence : Pass where
  name := `Tests.dropEvidence
  run d := do
    let steps := d.proof.steps.modify (d.proof.steps.size - 1) ({ · with evidence := #[] })
    return { d with proof.steps := steps }

/--
info: PresentedDecl unsupported   role theorem
  objects
    {α} : Type u_1
    A, B : Set α
  hypotheses
  conclusion
    f0: A ∩ B ⊆ A
  proof of ?g0
    s1 untranslated `intro x hx`   origin direct [#4]
      proves ?g0: fun x hx => @?g2 x hx
    s2 untranslated `exact hx.left`   origin direct [#7]
      proves ?g2: hx.left
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
  2: Apply `intro x hx`.
  3: Apply `exact hx.left`.
Verification
  statement: identical to the original statement
  proof: the steps rebuild a proof of the presented statement
  skipped Tests.dropEvidence: no step proves ?g2, which the Lean proof does
-/
#guard_msgs in
#informalize
theorem unsupported (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  exact hx.left
end

/-! ## Names in LaTeX -/

#guard nameTex `x == "x"
#guard nameTex `α == "\\alpha"
#guard nameTex `h₁ == "h_{1}"
#guard nameTex `x12 == "x_{12}"
#guard nameTex `A' == "A'"
#guard nameTex `x₀'' == "x_{0}''"
#guard nameTex `hAB == "\\mathit{hAB}"
#guard nameTex `my_set == "\\mathit{my\\_set}"
#guard nameTex `εδ == "\\mathit{\\varepsilon \\delta}"
