-- Definitions for Sets in Distill
-- Based on Lean's Mathlib library, with some simplifications

namespace Distill

/-- A set `A` is a collection of elements of some universal type `α`.
Membership is defined by a predicate that takes an element of type `α` and
returns a proposition indicating whether the element belongs to the set, i.e.
a proposition that `x ∈ A`.
-/
structure Set (α : Type u) where
  mem : α → Prop

-- Set builder notation, {x | p x}
syntax "{" ident " | " term "}" : term
syntax "{" ident " : " term " | " term "}" : term

macro_rules
  | `({ $x:ident | $p }) => `(Set.mk fun $x:ident => $p)
  | `({ $x:ident : $t | $p }) => `(Set.mk fun ($x:ident : $t) => $p)

-- Show `Set.mk fun x => p x` as `{x | p x}` in goals
@[app_unexpander Set.mk]
def Set.unexpandMk : Lean.PrettyPrinter.Unexpander
  | `($_ fun $x:ident => $p) => `({ $x:ident | $p })
  | `($_ fun ($x:ident : $t) => $p) => `({ $x:ident : $t | $p })
  | _ => throw ()

-- Set membership notation, x ∈ A
instance : Membership α (Set α) where
  mem A x := A.mem x

/-- We say that a set `A` is a subset of a set `B` (written `A ⊆ B`) if
every element of `A` is also an element of `B`.
-/
def Set.Subset (A B : Set α) : Prop :=
  ∀ x, x ∈ A → x ∈ B

-- Subset notation, A ⊆ B
instance : HasSubset (Set α) where
  Subset := Set.Subset

-- Set equality notation, A = B
-- `=` is Lean's built-in equality and can't be redefined, so instead we prove
-- that it agrees with the classical definition of set equality.
-- The `ext` tactic then turns a goal `A = B` into `A ⊆ B` and `B ⊆ A`.
@[ext (iff := false)]
theorem Set.ext {A B : Set α} (h₁ : A ⊆ B) (h₂ : B ⊆ A) : A = B := by
  cases A; cases B
  congr
  funext x
  exact propext ⟨h₁ x, h₂ x⟩

/-- We define the union of two sets `A` and `B` (written `A ∪ B`) to be
the set of all elements that belong to either `A` or `B`.
-/
def Set.Union (A B : Set α) : Set α where
  mem x := x ∈ A ∨ x ∈ B

-- Union notation, A ∪ B
instance : Union (Set α) where
  union := Set.Union

/-- We define the intersection of two sets `A` and `B` (written `A ∩ B`) to be
the set of all elements that belong to both `A` and `B`.
-/
def Set.Intersection (A B : Set α) : Set α where
  mem x := x ∈ A ∧ x ∈ B

-- Intersection notation, A ∩ B
instance : Inter (Set α) where
  inter := Set.Intersection
