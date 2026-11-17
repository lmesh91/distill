# Demo Coverage

This file lists everything the informalizer has to support to translate the six demo levels in [`lean/Distill/Levels/Demo.lean`](../../lean/Distill/Levels/Demo.lean), which use the definitions in [`lean/Distill/Definitions/Sets.lean`](../../lean/Distill/Definitions/Sets.lean).

It was produced by elaborating `Demo.lean` and walking its `InfoTree`s: every tactic's goals and hypotheses, every elaborated term, and every final proof term. So it reflects what the informalizer actually receives, not what the source looks like. Regenerate it whenever the levels or definitions change.

The levels only use the tactics `intro`, `have`, `exact` and `ext`.

## 1. Constants that appear in `Expr`s

These occur in statements, goal targets, hypothesis types or proof terms.

| Group                       | Constants                                                                                      | Where                                                                                                                                                                                           |
| --------------------------- | ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Logic                       | `And`, `And.intro`, `And.left`, `And.right`, `Eq`                                              | `∧` in `have` types and unfolded goals. `And.intro` comes from `⟨ha, hb⟩` (level 4), `And.left` from `h.left` (level 2), `And.right` from `hx.right` (level 3). `Eq` is in level 6's statement. |
| Notation                    | `Membership.mem`, `HasSubset.Subset`, `Inter.inter`                                            | Every `∈`, `⊆` and `∩`.                                                                                                                                                                         |
| Distill types and instances | `Distill.Set`, `Distill.instMembershipSet`, `Distill.instHasSubsetSet`, `Distill.instInterSet` | The instance argument of each notation constant.                                                                                                                                                |
| Distill lemma               | `Distill.Set.ext`                                                                              | Inserted by `ext` in level 6.                                                                                                                                                                   |
| Earlier levels              | `inter_subset_left`, `inter_subset_right`, `subset_inter`, `inter_subset_inter_comm`           | Cited in levels 5 and 6.                                                                                                                                                                        |

The classes `Membership`, `HasSubset` and `Inter`, and `outParam`, appear only inside those constants' own types, never in a goal or proof.

**Argument order:** `x ∈ A` elaborates to `Membership.mem A x`, with the set first. The informalizer must swap the arguments when it prints the statement.

## 2. Constants needed only to explain unfoldings

These never appear in any term, but the informalizer needs them to explain the "by definition" steps in section 3:

- `Distill.Set.Subset` (semireducible): `A ⊆ B` unfolds to `∀ x, x ∈ A → x ∈ B`.
- `Distill.Set.Intersection` (semireducible): `A ∩ B` unfolds to a set whose membership is `x ∈ A ∧ x ∈ B`.
- `Distill.Set.mk` and the projection `Distill.Set.mem`: the structure layer in between.
- The three instances are instance-reducible. Each one only forwards to the definition above it.

The chain for `x ∈ A ∩ B` is: `Membership.mem` → `instMembershipSet` → `Set.mem` → `Inter.inter` → `instInterSet` → `Set.Intersection` → `x ∈ A ∧ x ∈ B`.

### Checked by `referencedConstants` (#89)

`Distill.Informalizer.referencedConstants` (`lean/Distill/Informalizer/Constants.lean`) computes
§1–2 per proof, and `lean/Tests/Informalization/Constants.lean` prints it for the demo levels.
It agrees with the tables above, with these refinements:

- Instances (`instMembershipSet`, …) and binder annotations (`outParam`) are left out, as is the
  auto-bound `α`, which is not a constant.
- `Set.Subset`, `Set.Intersection` and `Set.mem` are reported as _reached by unfolding_, in
  levels 1–4 only (level 1 needs only `Set.Subset`). `Set.mk` is not reported: Lean never
  unfolds it, it only reduces the projection `Set.mem` applied to it.
- `And` is direct only where an `∧` is written or shown (level 2's `have`); in level 3 it occurs
  only inside `And.right`'s own type.

## 3. Implicit unfoldings

Lean accepts each of these because the two types are definitionally equal. The proof term contains no step for the unfolding.

| Level | Source                         | What Lean silently does                                                                                                                                         |
| ----- | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1–4   | `intro x hx` on a goal `A ⊆ B` | The goal isn't syntactically a `∀`, so `intro` unfolds `⊆` to `∀ x, x ∈ A → x ∈ B` first. The new hypothesis `hx` gets the type `x ∈ A`, with `∈` still folded. |
| 2     | `have h : x ∈ A ∧ x ∈ B := hx` | `hx : x ∈ A ∩ B` is accepted at type `x ∈ A ∧ x ∈ B` by unfolding `∩` and `∈`.                                                                                  |
| 3     | `hx.right`                     | To resolve `.right`, field notation unfolds `hx`'s type to `And`. The result is `@And.right (x ∈ A) (x ∈ B) hx`, with `hx` still typed `x ∈ A ∩ B`.             |
| 4     | `hCA x hx`                     | `hCA : C ⊆ A` is applied as a function, so `⊆` unfolds to `∀`.                                                                                                  |
| 4     | `exact ⟨ha, hb⟩`               | The anonymous constructor unfolds the goal `x ∈ A ∩ B` to find `And`. It produces `And.intro ha hb`, whose type `x ∈ A ∧ x ∈ B` differs from the goal.          |

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

## How the translator handles these

- **Unfoldings (§3).** Each one becomes an explicit "by definition" reason, read from the
  constants in §2: `intro` on `A ⊆ B` says what being a subset means the first time it is used,
  and a `have` whose annotation unfolds `∩` gives "by the definition of intersection". The
  definitions' English is registered as concepts in `Distill/Informalizer/Render/Expr.lean`
  (#94), and each is written out once per proof.
- **Auto-bound `α` (§4).** Left out of the statement ("Let $A$ be a set"), and out of
  `referencedConstants`.
- **Unification (§4).** Citations use the instantiated arguments. Where they differ from the
  theorem's own parameters, the English says so: "applied with $B$, $A$ and $A \cap B$ in place
  of $A$, $B$ and $C$" (#95).
- **`have` (§4).** The annotation from the `letE` type is the stated fact; a `have` without a
  value (`have h : P` followed by its proof) is read the same way.
- **`ext` (§4).** `Set.ext` is cited with its English description, and the two goals become
  "it suffices to show … and …", followed by one paragraph per goal ("Next, we show that …").
- **Tactic nodes (§5).** Translation is term-driven (see [pipeline.md](pipeline.md)): the
  surface tactics only supply the source lines and the order, and the inner and structural nodes
  are not translated on their own. `lean/Tests/Informalization/Coverage.lean` (#104) fails if
  a construct the levels use has no translation.

The expected English for every level is in `lean/Tests/Informalization/DemoLevels.lean`.

## Not needed for the demo

- `Set.Union`, `instUnionSet` and `Or`.
- The set-builder syntax, `Set.mk` as written by users, and its unexpander.
- The internals of `Set.ext`'s proof (`propext`, `funext`, `congr`). Translation can treat `Set.ext` as a cited fact.
