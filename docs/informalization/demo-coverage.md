# Demo Coverage

This file lists everything the informalizer has to support to translate the six demo levels in [`lean/Distill/Levels/Demo.lean`](../../lean/Distill/Levels/Demo.lean), which use the definitions in [`lean/Distill/Definitions/Sets.lean`](../../lean/Distill/Definitions/Sets.lean).

It was produced by elaborating `Demo.lean` and walking its `InfoTree`s: every tactic's goals and hypotheses, every elaborated term, and every final proof term. So it reflects what the informalizer actually receives, not what the source looks like. Regenerate it whenever the levels or definitions change.

The levels only use the tactics `intro`, `have`, `exact` and `ext`.

## 1. Constants that appear in `Expr`s

These occur in statements, goal targets, hypothesis types or proof terms.

| Group | Constants | Where |
|---|---|---|
| Logic | `And`, `And.intro`, `And.left`, `And.right`, `Eq` | `∧` in `have` types and unfolded goals. `And.intro` comes from `⟨ha, hb⟩` (level 4), `And.left` from `h.left` (level 2), `And.right` from `hx.right` (level 3). `Eq` is in level 6's statement. |
| Notation | `Membership.mem`, `HasSubset.Subset`, `Inter.inter` | Every `∈`, `⊆` and `∩`. |
| Distill types and instances | `Distill.Set`, `Distill.instMembershipSet`, `Distill.instHasSubsetSet`, `Distill.instInterSet` | The instance argument of each notation constant. |
| Distill lemma | `Distill.Set.ext` | Inserted by `ext` in level 6. |
| Earlier levels | `inter_subset_left`, `inter_subset_right`, `subset_inter`, `inter_subset_inter_comm` | Cited in levels 5 and 6. |

The classes `Membership`, `HasSubset` and `Inter`, and `outParam`, appear only inside those constants' own types, never in a goal or proof.

**Argument order:** `x ∈ A` elaborates to `Membership.mem A x`, with the set first. The informalizer must swap the arguments when it prints the statement.

## 2. Constants needed only to explain unfoldings

These never appear in any term, but the informalizer needs them to explain the "by definition" steps in section 3:

- `Distill.Set.Subset` (semireducible): `A ⊆ B` unfolds to `∀ x, x ∈ A → x ∈ B`.
- `Distill.Set.Intersection` (semireducible): `A ∩ B` unfolds to a set whose membership is `x ∈ A ∧ x ∈ B`.
- `Distill.Set.mk` and the projection `Distill.Set.mem`: the structure layer in between.
- The three instances are instance-reducible. Each one only forwards to the definition above it.

The chain for `x ∈ A ∩ B` is: `Membership.mem` → `instMembershipSet` → `Set.mem` → `Inter.inter` → `instInterSet` → `Set.Intersection` → `x ∈ A ∧ x ∈ B`.

## 3. Implicit unfoldings

Lean accepts each of these because the two types are definitionally equal. The proof term contains no step for the unfolding.

| Level | Source | What Lean silently does |
|---|---|---|
| 1–4 | `intro x hx` on a goal `A ⊆ B` | The goal isn't syntactically a `∀`, so `intro` unfolds `⊆` to `∀ x, x ∈ A → x ∈ B` first. The new hypothesis `hx` gets the type `x ∈ A`, with `∈` still folded. |
| 2 | `have h : x ∈ A ∧ x ∈ B := hx` | `hx : x ∈ A ∩ B` is accepted at type `x ∈ A ∧ x ∈ B` by unfolding `∩` and `∈`. |
| 3 | `hx.right` | To resolve `.right`, field notation unfolds `hx`'s type to `And`. The result is `@And.right (x ∈ A) (x ∈ B) hx`, with `hx` still typed `x ∈ A ∩ B`. |
| 4 | `hCA x hx` | `hCA : C ⊆ A` is applied as a function, so `⊆` unfolds to `∀`. |
| 4 | `exact ⟨ha, hb⟩` | The anonymous constructor unfolds the goal `x ∈ A ∩ B` to find `And`. It produces `And.intro ha hb`, whose type `x ∈ A ∧ x ∈ B` differs from the goal. |

Levels 5 and 6 have no unfoldings. Every type there matches exactly.

## 4. Other implicit elaboration

- **Auto-bound `α`:** every statement starts with `{α : Type u_1}`, which Lean adds through `autoImplicit`. It's a binder in `Statement.binders`, so the informalizer has to hide it or phrase it as "for any type α".
- **Implicit arguments solved by unification (level 5):** `subset_inter hB hA` elaborates to `@subset_inter α B A (A ∩ B) hB hA`. The lemma's `A` is the user's `B`, and its `C` is `A ∩ B`. Translation has to use the instantiated arguments, not the lemma's parameter names.
- **`have`:** this becomes a non-dependent `letE` whose type is the annotation (e.g. type `x ∈ A ∧ x ∈ B`, value `hx`). The annotation exists only in that `letE` type, so it's the only place the "by definition" step can be read from.
- **`ext`:** this looks up the lemma tagged `@[ext]` for `Set` and applies `Set.ext`. That leaves two goals tagged `h₁` and `h₂` with targets `A ∩ B ⊆ B ∩ A` and `B ∩ A ⊆ A ∩ B`.

## 5. Tactic nodes in the `InfoTree`

Using the node roles from the Proof IR:

- **Surface:** `Lean.Parser.Tactic.intro`, `Lean.Parser.Tactic.tacticHave__`, `Lean.Parser.Tactic.exact`, `Lean.Elab.Tactic.Ext.ext`.
- **Inner:** `intro x hx` produces one child node per name. `have` expands to `refine_lift` → `focus` → `paren` → `refine` / `;` / `rotate_right`.
- **Structural:** `by`, `byTactic`, `tacticSeq`.

## Not needed for the demo

- `Set.Union`, `instUnionSet` and `Or`.
- The set-builder syntax, `Set.mk` as written by users, and its unexpander.
- The internals of `Set.ext`'s proof (`propext`, `funext`, `congr`). Translation can treat `Set.ext` as a cited fact.
