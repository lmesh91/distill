import Distill.Informalizer.Frontend
import Distill.Definitions.Sets

/-! The English of statements made of the constructs of the demo levels, and how the presented
statement relates to the original one. The proofs do not matter here. -/

open Distill
open Distill.Informalizer

set_option warn.sorry false

/-! ## Introducing objects -/

/-! Objects of the same kind are introduced together. An implicit object that nothing names is
left out. -/

/--
info: Theorem. Let $A$ be a set. Then $A \subseteq A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem one_set (A : Set α) : A ⊆ A := sorry

/--
info: Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem three_sets {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B := sorry

/-! A membership hypothesis is stated where the element is introduced. -/

/--
info: Theorem. Let $A$ and $B$ be sets and let $x \in A \cap B$. Then $x \in A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem element (A B : Set α) (x : α) (hx : x ∈ A ∩ B) : x ∈ A := sorry

/--
info: Theorem. Let $A$ be a set and let $x, y \in A$. If $x = y$, then $y = x$.
  statement: equivalent to the original statement (proof checked)
-/
#guard_msgs in
#informalize_statement
theorem two_elements (A : Set α) (x y : α) (hx : x ∈ A) (hy : y ∈ A) (h : x = y) : y = x := sorry

/-! Elements of different sets are not grouped, and only the first membership of an element is
stated with it. -/

/--
info: Theorem. Let $A$ and $B$ be sets, let $x \in A$, and let $y \in B$. If $x \in B$, then $x \in A \cap B$.
  statement: equivalent to the original statement (proof checked)
-/
#guard_msgs in
#informalize_statement
theorem different_sets (A B : Set α) (x y : α) (hx : x ∈ A) (hy : y ∈ B) (hxB : x ∈ B) :
    x ∈ A ∩ B := sorry

/-! Objects are grouped across other binders, which changes the order of the statement: the
presented statement is then equivalent to the original, not identical. -/

/--
info: Theorem. Let $A$ and $B$ be sets and let $x, y \in A$. If $A \subseteq B$, then $x \in B$ and $y \in B$.
  statement: equivalent to the original statement (proof checked)
-/
#guard_msgs in
#informalize_statement
theorem apart (A : Set α) (x : α) (hx : x ∈ A) (B : Set α) (hAB : A ⊆ B) (y : α) (hy : y ∈ A) :
    x ∈ B ∧ y ∈ B := sorry

/-! An object joins a group only if what it is described with is introduced before the group:
`B` joins `A`, and `C`, an element of `T`, cannot. -/

/--
info: Theorem. Let $S$ and $T$ be sets of sets, let $A, B \in S$, let $x \in A$, and let $C \in T$. Then $x \in B$.
  statement: equivalent to the original statement (proof checked)
-/
#guard_msgs in
#informalize_statement
theorem dependent (S : Set (Set α)) (A : Set α) (hA : A ∈ S) (x : α) (hx : x ∈ A) (B : Set α)
    (hB : B ∈ S) (T : Set (Set α)) (C : Set α) (hC : C ∈ T) : x ∈ B := sorry

/-! An element that is bound before its set is introduced after it. -/

/--
info: Theorem. Let $A$ and $B$ be sets and let $x \in A \cap B$. Then $x \in B \cap A$.
  statement: equivalent to the original statement (proof checked)
-/
#guard_msgs in
#informalize_statement
theorem element_first (x : α) (A B : Set α) (hx : x ∈ A ∩ B) : x ∈ B ∩ A := sorry

/-! Hypotheses come after all the objects, so they do not keep it in place. An object that is
defined with it does. -/

/--
info: Theorem. Let $A$ and $B$ be sets and let $x \in B$. If $x = x$ and $\{y \mid y = x\} \subseteq A$, then $x \in A$.
  statement: equivalent to the original statement (proof checked)
-/
#guard_msgs in
#informalize_statement
theorem element_needed (x : α) (h : x = x) (A : Set α) (hxA : {y | y = x} ⊆ A) (B : Set α)
    (hx : x ∈ B) : x ∈ A := sorry

/--
info: Theorem. Let $\alpha$ be a type, let $x$ be an element of $\alpha$, let $S$ be a set of terms of type `{ y // y = x }`, and let $A$ be a set of elements of $\alpha$. If $x \in A$, then $x \in A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem element_needed' (x : α) (S : Set {y : α // y = x}) (A : Set α) (hx : x ∈ A) : x ∈ A := sorry

/-! A type that is named is introduced, whether it is explicit or not. -/

/--
info: Theorem. Let $\alpha$ be a type and let $A$ and $B$ be sets of elements of $\alpha$. Then $A \cap B \subseteq A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem explicit_type (α : Type) (A B : Set α) : A ∩ B ⊆ A := sorry

/--
info: Theorem. Let $\alpha$ be a type, let $A$ be a set of elements of $\alpha$, and let $x$ be an element of $\alpha$. If $A = A$, then $x \in A$ or $A = A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem named_type (A : Set α) (x : α) (h : A = A) : x ∈ A ∨ A = A := sorry

/-! Names: Greek letters, indices, primes and names of several letters. -/

/--
info: Theorem. Let $A_{1}$, $A_{2}$, $A'$ and $\mathit{Big}$ be sets. If $A_{1} \subseteq \mathit{Big}$, then $A_{1} \cap A_{2} \cap A' \subseteq \mathit{Big}$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem names (A₁ A2 A' : Set β) (Big : Set β) (h : A₁ ⊆ Big) : A₁ ∩ A2 ∩ A' ⊆ Big := sorry

/-! ## Hypotheses and conclusions -/

/-! Hypotheses that are formulas are stated with "if"; otherwise each gets its own clause. -/

/--
info: Theorem. Let $A$, $B$ and $C$ be sets. If $A \subseteq B$ and $B \subseteq C$, then $A \subseteq C$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem trans (A B C : Set α) (hAB : A ⊆ B) (hBC : B ⊆ C) : A ⊆ C := sorry

/--
info: Theorem. Let $A$ and $B$ be sets. Suppose that $A \subseteq B$. Then for every $x \in A$, $x \in B$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem forall_conclusion (A B : Set α) (h : A ⊆ B) : ∀ x, x ∈ A → x ∈ B := sorry

/--
info: Theorem. Let $A$ and $B$ be sets. Suppose that for every $x \in A$, $x \in B$ and that $B \subseteq A$. Then $A = B$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem forall_hypothesis (A B : Set α) (h : ∀ x, x ∈ A → x ∈ B) (h' : B ⊆ A) : A = B := sorry

/--
info: Theorem. Let $\alpha$ be a type, let $A$ and $B$ be sets of elements of $\alpha$, and let $x$ be an element of $\alpha$. If $x \in A$ and $x \in B$, then $x \in A \cap B$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem implication (A B : Set α) (x : α) : x ∈ A → x ∈ B → x ∈ A ∩ B := sorry

/--
info: Theorem. Let $A$ be a set. Then for all sets $S$ and $T$, if $S \subseteq A$ and $T \subseteq A$, then $S \cup T \subseteq A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem quantified_sets (A : Set α) : ∀ S T : Set α, S ⊆ A → T ⊆ A → S ∪ T ⊆ A := sorry

/--
info: Theorem. Let $\alpha$ be a type and let $A$ be a set of elements of $\alpha$. Suppose that for all elements $x$ and $y$ of $\alpha$, $x = y$. Then for every element $x$ of $\alpha$, $x \in A$ or $A = A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem quantified_elements (A : Set α) (h : ∀ x y : α, x = y) : ∀ x : α, x ∈ A ∨ A = A := sorry

/-! "and" and "or" in words, as long as they are not mixed. -/

/--
info: Theorem. Let $\alpha$ be a type, let $A$, $B$ and $C$ be sets of elements of $\alpha$, and let $x$ be an element of $\alpha$. If $x \in A$, $x \in B$ and $x \in C$, then $x \in A$ or $x \in B$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem connectives (A B C : Set α) (x : α) (h : x ∈ A ∧ x ∈ B ∧ x ∈ C) : x ∈ A ∨ x ∈ B := sorry

/--
info: Theorem. Let $\alpha$ be a type, let $A$, $B$ and $C$ be sets of elements of $\alpha$, and let $x$ be an element of $\alpha$. If $(x \in A \lor x \in B) \land x \in C$, then $x \in A \land x \in C \lor x \in B$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem mixed (A B C : Set α) (x : α) (h : (x ∈ A ∨ x ∈ B) ∧ x ∈ C) : x ∈ A ∧ x ∈ C ∨ x ∈ B := sorry

/-! Parentheses follow the precedence of the operators. -/

/--
info: Theorem. Let $A$, $B$ and $C$ be sets. Then $A \cap (B \cup C) \cap A = (A \cap (B \cap C)) \cup (A \cup B) \cup C$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem precedence (A B C : Set α) : A ∩ (B ∪ C) ∩ A = A ∩ (B ∩ C) ∪ (A ∪ B) ∪ C := sorry

/--
info: Theorem. Let $A$ and $B$ be sets. Then $\{x \mid x \in A \land x \in B\} = A \cap B$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem set_builder (A B : Set α) : {x | x ∈ A ∧ x ∈ B} = A ∩ B := sorry

/--
info: Theorem. For every set $A$ of terms of type `Nat`, $A \subseteq A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem no_binders : ∀ A : Set Nat, A ⊆ A := sorry

/-! A `∀` inside a formula stays a formula. -/

/--
info: Theorem. Let $\alpha$ be a type and let $A$ and $B$ be sets of elements of $\alpha$. If $(\forall x \in A,\ x \in B) \land (\forall x \in B,\ x \in A)$, then $(\forall x,\ x \in A) \to A = B$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem forall_in_formula (A B : Set α) (h : (∀ x, x ∈ A → x ∈ B) ∧ (∀ x, x ∈ B → x ∈ A)) :
    (∀ x : α, x ∈ A) → A = B := sorry

/-! "or" is not listed with "and", and `∩` is not mixed with `∪` without parentheses. -/

/--
info: Theorem. Let $\alpha$ be a type, let $A$, $B$ and $C$ be sets of elements of $\alpha$, and let $x$ be an element of $\alpha$. Then $x \in A \lor x \in B \to x \in C \to x \in C \cup (A \cap B)$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem or_and (A B C : Set α) (x : α) : x ∈ A ∨ x ∈ B → x ∈ C → x ∈ C ∪ A ∩ B := sorry

/--
info: Theorem. Let $A$, $B$ and $C$ be sets. Suppose that $A = B$ or $A = C$ and that $B = C$. Then $A \cup B \cup C = A \cap B \cap C$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem or_hypothesis (A B C : Set α) (h : A = B ∨ A = C) (h' : B = C) : A ∪ B ∪ C = A ∩ B ∩ C := sorry

/-! A conclusion that is an implication after hypotheses that are not plain formulas. -/

/--
info: Theorem. Let $A$ and $B$ be sets. Suppose that for every $x \in A$, $x \in B$. If $B \subseteq A$, then $A = B$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem then_if (A B : Set α) (h : ∀ x, x ∈ A → x ∈ B) : B ⊆ A → A = B := sorry

/-! An implicit object with a property is introduced, so that the property is stated. -/

/--
info: Theorem. Let $A$ and $B$ be sets and let $x \in A$. If $A \subseteq B$, then $A \cap B = A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem implicit_element {A B : Set α} {x : α} (hx : x ∈ A) : A ⊆ B → A ∩ B = A := sorry

/-! A hypothesis that a later binder is stated with stays before it. -/

def restrict (A : Set α) (_ : A ⊆ A) : Set α := A

/--
info: Theorem. Let $\alpha$ be a type, let $A$ be a set of elements of $\alpha$ such that $A \subseteq A$, let $y$ be an element of $\alpha$, and let $B$ be a set of elements of $\alpha$. If `y ∈ restrict A h`, then $y \in A$.
  statement: equivalent to the original statement (proof checked)
-/
#guard_msgs in
#informalize_statement
theorem needed_hypothesis (A : Set α) (h : A ⊆ A) (y : α) (hy : y ∈ restrict A h) (B : Set α) :
    y ∈ A := sorry

/-! Only propositions have a statement. -/

/--
info: (no statement)
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
def number (n : Nat) : Nat := by exact n + 1

/-! ## What has no English yet

Is shown as Lean code, whole: a formula is never half LaTeX. -/

/--
info: Theorem. Let $m$ be a term of type `Nat`, let $A$ be a set of terms of type `Nat`, and let $n \in A$. If `n + 1 = m`, then $m \in A$ or `n + 1 ≠ m`.
  statement: equivalent to the original statement (proof checked)
-/
#guard_msgs in
#informalize_statement
theorem numbers (n m : Nat) (A : Set Nat) (h : n + 1 = m) (hn : n ∈ A) : m ∈ A ∨ n + 1 ≠ m := sorry

/--
info: Theorem. Let $\alpha$ be a type, let $f$ be a term of type `α → α`, let $A$ be a set of elements of $\alpha$, and let $x$ be an element of $\alpha$. If `f x ∈ A`, then `∃ y, y ∈ A`.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem function (f : α → α) (A : Set α) (x : α) (hx : f x ∈ A) : ∃ y, y ∈ A := sorry

/--
info: Theorem. Let $\alpha$ be a type, fix an instance of `Inhabited α`, and let $A$ be a set of elements of $\alpha$. If `default ∈ A`, then $A = A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
theorem instance_binder [Inhabited α] (A : Set α) : default ∈ A → A = A := sorry

/--
info: Example. Let $A$ be a set. Then $A = A$.
  statement: identical to the original statement
-/
#guard_msgs in
#informalize_statement
example (A : Set α) : A = A := sorry
