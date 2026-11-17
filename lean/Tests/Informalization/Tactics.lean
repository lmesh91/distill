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
3: We already know that $p$, which is what we needed to show.
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
3: We already know that $p$, which is what we needed to show.
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
4: We already know this.
5: We already know that $p$, which is what we needed to show.
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
info: 3: We already know that `n + 1 > 0`, which is what we needed to show.
proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#tactics
example (n : Nat) (h : n + 1 > 0) : n + 1 > 0 := by
  have hn := h
  exact hn

/-! Unsupported tactics remain visible between translated steps. -/
/--
info: 3: First, we show that $p$.
3: We already know this.
4: Next, we show that $q$.
4: We already know this.
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
info: 2: By function extensionality (two functions are equal if they agree at every argument), it suffices to show that for every term $x$ of type `Nat`, `f x = f x`.
2: Let $n$ be a term of type `Nat`.
3: We conclude that `f n = f n` by reflexivity of equality.
proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#tactics
example (f : Nat → Nat) : f = f := by
  ext n
  exact rfl

/-! Pattern introduction has no supported detail; it must not invent assumptions. -/
/--
info: 2: Suppose that $p$ and $q$.
3: In particular, $p$.
proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#tactics
theorem tactic_pattern (p q : Prop) : p ∧ q → p := by
  intro ⟨hp, hq⟩
  exact hp

/-! A data-valued `have` is not a proved proposition. -/
/--
info: 2: The Lean proof continues with the step `have n : Nat := 1`, which is not translated into English yet. After it, it remains to show that `True`.
2: Let $n$ be a term of type `Nat`.
3: We conclude that `True` by the fact that `True` always holds.
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
info: 2: It remains to show that $p$: the Lean proof leaves this out with `sorry`.
proof: incomplete (the proof uses `sorry`)
-/
#guard_msgs in
#tactics
example (p : Prop) : p := by
  exact sorry

/--
warning: declaration uses `sorry`
---
info: 2: We claim that $p$.
2: The Lean proof leaves this out with `sorry`.
2: We go on as if this were proved.
3: We already know that $p$, which is what we needed to show.
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
3: The Lean proof leaves this out with `sorry`.
2: We go on as if this were proved.
4: We already know that $p$, which is what we needed to show.
proof: incomplete (the proof uses `sorry`)
-/
#guard_msgs in
#tactics
example (p : Prop) : p := by
  have hp : p := by
    sorry
  exact hp
