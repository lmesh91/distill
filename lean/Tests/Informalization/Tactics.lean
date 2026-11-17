import Distill.Informalizer.Frontend
import Distill.Levels.Demo

/-! Tactic intent, independent of statement wording. Check that translating/splitting/nesting
steps preserves evidence and the source location of every surface node. DemoLevels also tests
the full RPC line/structured-text path for all six demo proofs. -/

open Lean Meta Elab Command
open Distill Distill.Informalizer Distill.Informalizer.IR

private partial def allSteps (b : Block) : Array ProofStep :=
  b.steps.flatMap fun s => #[s] ++ match s.kind with
    | .claim _ proof => allSteps proof
    | .split _ branches => branches.flatMap (allSteps ·.body)
    | _ => #[]

elab "#tactics " cmd:command : command =>
  elabAndDescribe cmd fun ir offset => do
    let r ← informalize ir
    let steps := allSteps r.presented.proof
    let ids := steps.map (·.id)
    unless ids.toList.eraseDups.length == ids.size do
      throwError "duplicate step ids"
    for n in ir.surfaceNodes do
      unless steps.any (·.origin.nodes.contains n.id) do
        throwError "surface node {n.id} lost"
    unless r.skipped.isEmpty do throwError "a normalization pass failed"
    let some v := r.verification? | throwError "verification did not run"
    unless v.ok do
      throwError "translation lost proof evidence: {v.proof.describe}"
    let mut out := ""
    for s in r.english.steps do
      let some line := stepLine? ir s | throwError "step lost source location"
      out := out ++ s!"{line - offset}: {s.text.toMarkup}\n"
    return out ++ s!"proof: {v.proof.describe}"

/-! Several hypotheses introduced by one tactic produce ordered assumptions, with only one
copy of the tactic's evidence. -/
/--
info: 2: Suppose that $p$.
2: Suppose that $q$.
3: Thus $p$ by `hp`.
proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#tactics
example (p q : Prop) : p → q → p := by
  intro hp hq
  exact hp

/-! Objects and hypotheses remain in binder order. -/
/--
info: 2: Let $p$ be a proposition.
2: Suppose that $p$.
3: Thus $p$ by `hp`.
proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#tactics
example : ∀ p : Prop, p → p := by
  intro p hp
  exact hp

/-! Nested claims keep their proofs inside the claim and render each child at its own line. -/
/--
info: 2: We claim that $p$.
3: We have that $p$ by `hp`.
4: Thus $p$ by `h'`.
5: Thus $p$ by `h`.
proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#tactics
example (p : Prop) (hp : p) : p := by
  have h : p := by
    have h' : p := hp
    exact h'
  exact h

/-! A proposition not covered by expression translation is still a meaningful tactic step,
with the complete proposition quoted as Lean. -/
/--
info: 2: We have that `n + 1 > 0` by `h`.
3: Thus `n + 1 > 0` by `hn`.
proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#tactics
example (n : Nat) (h : n + 1 > 0) : n + 1 > 0 := by
  have hn := h
  exact hn

/-! Unsupported tactics remain visible between translated steps. -/
/--
info: 2: Apply `constructor`.
3: Thus $p$ by `hp`.
4: Apply `apply hq`.
proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#tactics
example (p q : Prop) (hp : p) (hq : q) : p ∧ q := by
  constructor
  · exact hp
  · apply hq

/-! `ext` on functions uses a different lemma and must not claim mutual set inclusion. -/
/--
info: 2: Apply `ext n`.
3: Thus `f n = f n` by `rfl`.
proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#tactics
example (f : Nat → Nat) : f = f := by
  ext n
  exact rfl

/-! Pattern introduction has no supported detail; it must not invent assumptions. -/
/--
info: 2: Apply `intro ⟨hp, hq⟩`.
3: Thus $p$ by `hp`.
proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#tactics
theorem tactic_pattern (p q : Prop) : p ∧ q → p := by
  intro ⟨hp, hq⟩
  exact hp

/-! A data-valued `have` is not a proved proposition. -/
/--
info: 2: Apply `have n : Nat := 1`.
3: Thus `True` by `True.intro`.
proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#tactics
example : True := by
  have n : Nat := 1
  exact True.intro

/-! Neither an explicit nor a nested sorry may become a claim of having proved the goal. -/
/--
warning: declaration uses `sorry`
---
info: 2: Apply `exact sorry`.
proof: incomplete (the proof uses `sorry`)
-/
#guard_msgs in
#tactics
example (p : Prop) : p := by
  exact sorry

/--
warning: declaration uses `sorry`
---
info: 2: Apply `have hp : p := sorry`.
3: Thus $p$ by `hp`.
proof: incomplete (the proof uses `sorry`)
-/
#guard_msgs in
#tactics
example (p : Prop) : p := by
  have hp : p := sorry
  exact hp

/--
warning: declaration uses `sorry`
---
info: 2: We claim that $p$.
3: Apply `sorry`.
4: Thus $p$ by `hp`.
proof: incomplete (the proof uses `sorry`)
-/
#guard_msgs in
#tactics
example (p : Prop) : p := by
  have hp : p := by
    sorry
  exact hp
