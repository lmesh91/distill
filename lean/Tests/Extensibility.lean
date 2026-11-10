import Distill.Informalizer.Extract.Frontend
import Distill.Levels.Demo
import Tests.Extensibility.Library

/-! What a library adds needs no change to Distill: its combinators are told apart from its
automation by the InfoTree's shape, what they undo is found from the proof states, and it can
register a recognizer for its tactics. -/

open Lean Elab Tactic Meta
open Distill Distill.Levels.Demo
open Distill.Informalizer.Extract Distill.Informalizer.IR

/-- A combinator defined by a macro. -/
macro "my_focus " t:tacticSeq : tactic => `(tactic| focus $t)

/-- A combinator with an elaborator, which backtracks. -/
elab "my_first " a:tactic " or " b:tactic : tactic => do
  try evalTactic a catch _ => evalTactic b

/-- A combinator that undoes what it runs. -/
elab "my_dry_run " t:tactic : tactic => do
  let s ← saveState
  evalTactic t
  s.restore

/-- A combinator that undoes what it runs and closes the goal another way. -/
elab "my_redo " t:tactic " using " e:term : tactic => do
  let s ← saveState
  evalTactic t
  s.restore
  closeMainGoalUsing `my_redo fun type _ => elabTermEnsuringType e type

/-- Automation: the user wrote none of what it runs. -/
macro "my_auto" : tactic => `(tactic| first | assumption | trivial)

/-! The combinators are structural, the failed and undone tactics inner, and `my_auto` surface. -/
/--
info: ProofIR library_tactics
  statement
    binders     [p, q, hp, hq]
    conclusion  p ∧ q
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:66–5:20  ?g0 ⟶ —
      #1 structural [by]  1:66–1:68  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–5:20  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–5:20  ?g0 ⟶ —
            #4 surface `constructor`  2:2–2:13  ?g0 ⟶ ?g1 ?g2   [unrecognized]
            #5 structural [Lean.cdot]  3:2–4:33  ?g1 ?g2 ⟶ ?g2
              #6 structural [Lean.cdotTk]  3:2–3:3  ?g1 ?g2 ⟶ ?g1
              #7 structural [Lean.Parser.Tactic.tacticSeq]  3:4–4:33  ?g1 ⟶ —
                #8 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:4–4:33  ?g1 ⟶ —
                  #9 structural [tacticMy_dry_run_]  3:4–3:23  ?g1 ⟶ ?g1
                    #10 inner `exact hp`  3:15–3:23  ?g1 ⟶ —
                  #11 structural [tacticMy_first_Or_]  4:4–4:33  ?g1 ⟶ —
                    #12 inner `exact hq`  4:13–4:21  ?g1 ⟶ ?g1
                    #13 surface `exact hp`  4:25–4:33  ?g1 ⟶ —   [exact hp]
            #14 structural [Lean.cdot]  5:2–5:20  ?g2 ⟶ —
              #15 structural [Lean.cdotTk]  5:2–5:3  ?g2 ⟶ ?g2
              #16 structural [Lean.Parser.Tactic.tacticSeq]  5:4–5:20  ?g2 ⟶ —
                #17 structural [Lean.Parser.Tactic.tacticSeq1Indented]  5:4–5:20  ?g2 ⟶ —
                  #18 structural [tacticMy_focus_]  5:4–5:20  ?g2 ⟶ —
                    #19 structural [Lean.Parser.Tactic.focus]  synthetic 5:4–5:20  ?g2 ⟶ —
                      #20 structural [focus]  synthetic 5:4–5:20  ?g2 ⟶ ?g2
                      #21 structural [Lean.Parser.Tactic.tacticSeq]  5:13–5:20  ?g2 ⟶ —
                        #22 structural [Lean.Parser.Tactic.tacticSeq1Indented]  5:13–5:20  ?g2 ⟶ —
                          #23 surface `my_auto`  5:13–5:20  ?g2 ⟶ —   [unrecognized]
                            #24 inner `first  |  assumption  |  trivial`  synthetic 5:13–5:20  ?g2 ⟶ —
                              #25 inner `assumption`  synthetic 5:13–5:20  ?g2 ⟶ —
                                #26 inner `assumption`  synthetic 5:13–5:20  ?g2 ⟶ —
                                  #27 inner `assumption`  synthetic 5:13–5:20  ?g2 ⟶ —
  goals
    ?g0 ⊢ p ∧ q   ctx [p, q, hp, hq]
        assigned by #4: ⟨?g1, ?g2⟩
    ?g1 (left) ⊢ p   ctx [p, q, hp, hq]   parent ?g0
        assigned by #13: hp
    ?g2 (right) ⊢ q   ctx [p, q, hp, hq]   parent ?g0
        assigned by #27: hq
  hyps
    p : Prop
    q : Prop
    hp : p
    hq : q
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem library_tactics (p q : Prop) (hp : p) (hq : q) : p ∧ q := by
  constructor
  · my_dry_run exact hp
    my_first exact hq or exact hp
  · my_focus my_auto

/-- A recognizer that declines leaves the node to the next one, here the built-in one. -/
@[local distill_recognizer Lean.Parser.Tactic.exact] def declineExact : Recognizer := fun _ =>
  return none

/--
info: ProofIR registered_recognizer
  statement
    binders     [α, A]
    conclusion  A ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:53–4:10  ?g0 ⟶ —
      #1 structural [by]  1:53–1:55  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–4:10  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–4:10  ?g0 ⟶ —
            #4 surface `my_intro x`  2:2–2:12  ?g0 ⟶ ?g1   [intro [x]]
              #5 inner `intro x`  synthetic 2:2–2:12  ?g0 ⟶ ?g1   [intro [x]]
                #6 inner `intro x`  synthetic 2:2–2:12  ?g0 ⟶ ?g1
            #7 surface `my_intro hx`  3:2–3:13  ?g1 ⟶ ?g2   [intro [hx]]
              #8 inner `intro hx`  synthetic 3:2–3:13  ?g1 ⟶ ?g2   [intro [hx]]
                #9 inner `intro hx`  synthetic 3:2–3:13  ?g1 ⟶ ?g2
            #10 surface `exact hx`  4:2–4:10  ?g2 ⟶ —   [exact hx]
  goals
    ?g0 ⊢ A ⊆ A   ctx [α, A]
        assigned by #6: fun x => ?g1 x
    ?g1 ⊢ x ∈ A → x ∈ A   ctx [α, A, x]   parent ?g0
        assigned by #9: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A   ctx [α, A, x, hx]   parent ?g1
        assigned by #10: hx
  hyps
    α : Type u_1   {implicit}
    A : Set α
    x : α
    hx : x ∈ A
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem registered_recognizer (A : Set α) : A ⊆ A := by
  my_intro x
  my_intro hx
  exact hx

/-! The first `exact` is credited with nothing: the proof is the one `my_redo` put in place. -/
/--
info: ProofIR redone
  statement
    binders     [p, hp, hp']
    conclusion  p
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:46–2:28  ?g0 ⟶ —
      #1 structural [by]  1:46–1:48  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–2:28  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–2:28  ?g0 ⟶ —
            #4 surface `my_redo exact hp using hp'`  2:2–2:28  ?g0 ⟶ —   [unrecognized]
              #5 inner `exact hp`  2:10–2:18  ?g0 ⟶ —
  goals
    ?g0 ⊢ p   ctx [p, hp, hp']
        assigned by #4: hp'
  hyps
    p : Prop
    hp : p
    hp' : p
  proof term: rebuilds the declaration's proof term
---
warning: Variable name `hp` is not explicitly referenced.

Hint: The binding can be removed (if unused) or named `_` (if used implicitly). Alternatively, prefix the name with `_` to silence this warning:
  [apply] _hp

Note: This linter can be disabled with `set_option linter.unusedVariables false`
-/
#guard_msgs in
#proof_ir
theorem redone (p : Prop) (hp hp' : p) : p := by
  my_redo exact hp using hp'

/-! `first` backtracks over an alternative that only got as far as its `by` blocks. -/
/--
info: ProofIR failed_with_blocks
  statement
    binders     [p, q, hp, hq]
    conclusion  q
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:65–2:65  ?g0 ⟶ —
      #1 structural [by]  1:65–1:67  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–2:65  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–2:65  ?g0 ⟶ —
            #4 structural [Lean.Parser.Tactic.first]  2:2–2:65  ?g0 ⟶ —
              #5 inner `exact (⟨by exact hp, by exact hp⟩ : p ∧…`  2:10–2:54  ?g0 ⟶ ?g0
                #6 inner `exact (⟨by exact hp, by exact hp⟩ : p ∧…`  2:10–2:54  ?g0 ⟶ ?g0
                  #7 inner `exact (⟨by exact hp, by exact hp⟩ : p ∧…`  2:10–2:54  ?g0 ⟶ ?g0
                    #8 inner `by exact hp`  2:18–2:29  ?✗ ⟶ —
                      #9 inner `by`  2:18–2:20  ?✗ ⟶ —
                        #10 inner `exact hp`  2:21–2:29  ?✗ ⟶ —
                          #11 inner `exact hp`  2:21–2:29  ?✗ ⟶ —
                            #12 inner `exact hp`  2:21–2:29  ?✗ ⟶ —
                    #13 inner `by exact hp`  2:31–2:42  ?✗ ⟶ —
                      #14 inner `by`  2:31–2:33  ?✗ ⟶ —
                        #15 inner `exact hp`  2:34–2:42  ?✗ ⟶ —
                          #16 inner `exact hp`  2:34–2:42  ?✗ ⟶ —
                            #17 inner `exact hp`  2:34–2:42  ?✗ ⟶ —
              #18 structural [Lean.Parser.Tactic.tacticSeq]  2:57–2:65  ?g0 ⟶ —
                #19 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:57–2:65  ?g0 ⟶ —
                  #20 surface `exact hq`  2:57–2:65  ?g0 ⟶ —   [exact hq]
  goals
    ?g0 ⊢ q   ctx [p, q, hp, hq]
        assigned by #20: hq
  hyps
    p : Prop
    q : Prop
    hp : p
    hq : q
  proof term: rebuilds the declaration's proof term
---
warning: Variable name `hp` is not explicitly referenced.

Hint: The binding can be removed (if unused) or named `_` (if used implicitly). Alternatively, prefix the name with `_` to silence this warning:
  [apply] _hp

Note: This linter can be disabled with `set_option linter.unusedVariables false`
-/
#guard_msgs in
#proof_ir
theorem failed_with_blocks (p q : Prop) (hp : p) (hq : q) : q := by
  first | exact (⟨by exact hp, by exact hp⟩ : p ∧ p).1 | exact hq

/-! A recognizer registered in another module applies to files elaborated from source too. -/
private unsafe def detailOfSource : IO String := do
  let source := "import Tests.Extensibility.Library
theorem t (p : Prop) : p → p := by
  my_intro h
  exact h
"
  let (proofs, _, env) ← extractSource source
  proofs.foldlM (init := "") fun s ir => return s ++ (← formatProof env ir)

#eval show IO Unit from do
  let text ← unsafe detailOfSource
  unless (text.splitOn "[intro [h]]").length > 2 do
    throw <| .userError s!"the registered recognizer did not run:\n{text}"
