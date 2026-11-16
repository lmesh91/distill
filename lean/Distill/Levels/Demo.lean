-- Levels included in the demo
-- TODO: figure out a way for levels to use previous levels' theorems
-- inside of the web application

import Distill.Definitions.Sets
namespace Distill.Levels.Demo
open Distill

/-!
A bit of background that needs to be given before any proofs are presented:

In Lean, everything is defined in terms of types. Natural numbers are a type,
and so are sets, propositions, functions, and anything else.

We define a set to be a collection of elements of a given type `α`.
The type `α` represents the universe of all possible elements that can be members of the set.
This collection is defined by the set's membership function, which takes in
an element of type `α` and returns a proposition indicating whether the element
is a member of the set.

We define `x ∈ A` to be the membership function applied to `x`.
We define `A ⊆ B` to mean that for every element `x`, if `x ∈ A` then `x ∈ B`.
We define `A ∩ B` to be the set of elements that are members of both `A` and `B`.

A proof in Lean is a program that demonstrates the truth of a proposition
by constructing a term of the corresponding type.
To do this we apply a series of steps called *tactics*.
-/

-- Level 1: For any set A, A ⊆ A (i.e. ⊆ is reflexive)
theorem subset_rfl (A : Set α) : A ⊆ A := by
  -- To prove `A ⊆ A`, we need to show that for any element `x`, if `x ∈ A` then `x ∈ A`.
  -- We introduce an arbitrary element `x` and assume `x ∈ A`.
  intro x hx
  -- Now `x` is our element, and `hx` is a proof that `x ∈ A`.
  -- We need to show that `x ∈ A`, which is exactly what `hx` provides.
  exact hx

-- Level 2: For any sets A and B, A ∩ B ⊆ A
theorem inter_subset_left (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  -- `hx` is a proof that `x ∈ A ∩ B`, which by definition means `x ∈ A ∧ x ∈ B`.
  have h : x ∈ A ∧ x ∈ B := hx
  -- We need to show that `x ∈ A`, which is the left part of the conjunction.
  exact h.left

-- Level 3: For any sets A and B, A ∩ B ⊆ B
theorem inter_subset_right (A B : Set α) : A ∩ B ⊆ B := by
  intro x hx
  -- Lean automatically substitutes `x ∈ A ∧ x ∈ B` for `x ∈ A ∩ B`,
  -- so we can directly access the right part of the conjunction to prove `x ∈ B`.
  exact hx.right

-- Level 4: If C ⊆ A and C ⊆ B, then C ⊆ A ∩ B
theorem subset_inter {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B := by
  intro x hx
  -- We want to show that `x ∈ A ∩ B`, which by definition means `x ∈ A ∧ x ∈ B`.
  -- Applying the definition of a subset to our hypotheses (e.g. `hCA`) yields a proof
  -- that for any `x`, `x ∈ C` implies `x ∈ A`. We can treat this proof as a function
  -- by passing `x` and `hx` (a proof that `x ∈ C`), yielding a proof of `x ∈ A`.
  have ha : x ∈ A := hCA x hx
  have hb : x ∈ B := hCB x hx
  -- `⟨ha, hb⟩` constructs a proof of `x ∈ A ∩ B` from proofs of `x ∈ A` and `x ∈ B`.
  exact ⟨ha, hb⟩

-- Level 5: For any sets A and B, A ∩ B ⊆ B ∩ A
theorem inter_subset_inter_comm (A B : Set α) : A ∩ B ⊆ B ∩ A := by
  -- We can use previous levels' theorems to build this proof
  have hA : A ∩ B ⊆ A := inter_subset_left A B
  have hB : A ∩ B ⊆ B := inter_subset_right A B
  -- `A`, `B`, and `C` are implicit arguments in `subset_inter`.
  -- Lean uses the types of `hB` and `hA` to infer the types of `A`, `B`, and `C`.
  exact subset_inter hB hA

-- Level 6: For any sets A and B, A ∩ B = B ∩ A (i.e. ∩ is commutative)
theorem inter_comm (A B : Set α) : A ∩ B = B ∩ A := by
  -- Two sets are equal when each is a subset of the other.
  -- The `ext` tactic applies the principle of extensionality for sets,
  -- reducing the goal to showing that `A ∩ B ⊆ B ∩ A` and `B ∩ A ⊆ A ∩ B`.
  ext
  -- Multiple goals are handled by providing separate proofs for each goal
  exact inter_subset_inter_comm A B
  exact inter_subset_inter_comm B A
