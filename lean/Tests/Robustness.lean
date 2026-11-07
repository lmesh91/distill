import Distill.Informalizer.Extract.Frontend
import Distill.Levels.Demo

/-! Proofs that do not go through still give a Proof IR. -/

open Distill

/-! Unfinished: the last goal stays unassigned. -/
/--
error: unsolved goals
α : Type u_1
A B : Set α
x : α
hx : x ∈ A ∩ B
⊢ x ∈ A
---
info: ProofIR unfinished
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:48–2:12  ?g0 ⟶ ?g2
      #1 structural [by]  1:48–1:50  ?g0 ⟶ ?g2
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–2:12  ?g0 ⟶ ?g2
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–2:12  ?g0 ⟶ ?g2
            #4 surface `intro x hx`  2:2–2:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
              #6 inner `hx`  2:10–2:12  ?g1 ⟶ ?g2
  goals
    ?g0 ⊢ A ∩ B ⊆ A   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ A   ctx [α, A, B, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g1
        unassigned
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
    x : α
    hx : x ∈ A ∩ B
  proof term: incomplete (a goal is unassigned)
-/
#guard_msgs in
#proof_ir
theorem unfinished (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx

/-! `sorry` closes the goal with an error term. -/
/--
warning: declaration uses `sorry`
---
info: ProofIR with_sorry
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:48–3:7  ?g0 ⟶ —
      #1 structural [by]  1:48–1:50  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:7  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:7  ?g0 ⟶ —
            #4 surface `intro x hx`  2:2–2:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
              #6 inner `hx`  2:10–2:12  ?g1 ⟶ ?g2
            #7 surface `sorry`  3:2–3:7  ?g2 ⟶ —   [unrecognized]
              #8 inner `exact  sorry`  synthetic 3:2–3:7  ?g2 ⟶ —   [exact sorry]
  goals
    ?g0 ⊢ A ∩ B ⊆ A   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ A   ctx [α, A, B, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g1
        assigned by #8: sorry
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
    x : α
    hx : x ∈ A ∩ B
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem with_sorry (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  sorry

/-! An elaboration error. -/
/--
error: Unknown identifier `foo`
---
info: ProofIR with_error
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:48–3:11  ?g0 ⟶ —
      #1 structural [by]  1:48–1:50  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:11  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:11  ?g0 ⟶ —
            #4 surface `intro x hx`  2:2–2:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
              #6 inner `hx`  2:10–2:12  ?g1 ⟶ ?g2
            #7 surface `exact foo`  3:2–3:11  ?g2 ⟶ —   [exact sorry]
  goals
    ?g0 ⊢ A ∩ B ⊆ A   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ A   ctx [α, A, B, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g1
        assigned by #7: sorry
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
    x : α
    hx : x ∈ A ∩ B
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem with_error (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  exact foo

/-! A tactic without a recognizer. -/
/--
info: ProofIR with_constructor
  statement
    binders     [α, A]
    conclusion  A ⊆ A ∩ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:52–5:12  ?g0 ⟶ —
      #1 structural [by]  1:52–1:54  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–5:12  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–5:12  ?g0 ⟶ —
            #4 surface `intro x hx`  2:2–2:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
              #6 inner `hx`  2:10–2:12  ?g1 ⟶ ?g2
            #7 surface `constructor`  3:2–3:13  ?g2 ⟶ ?g3 ?g4   [unrecognized]
            #8 structural [Lean.cdot]  4:2–4:12  ?g3 ?g4 ⟶ ?g4
              #9 structural [Lean.cdotTk]  4:2–4:3  ?g3 ?g4 ⟶ ?g3
              #10 structural [Lean.Parser.Tactic.tacticSeq]  4:4–4:12  ?g3 ⟶ —
                #11 structural [Lean.Parser.Tactic.tacticSeq1Indented]  4:4–4:12  ?g3 ⟶ —
                  #12 surface `exact hx`  4:4–4:12  ?g3 ⟶ —   [exact hx]
            #13 structural [Lean.cdot]  5:2–5:12  ?g4 ⟶ —
              #14 structural [Lean.cdotTk]  5:2–5:3  ?g4 ⟶ ?g4
              #15 structural [Lean.Parser.Tactic.tacticSeq]  5:4–5:12  ?g4 ⟶ —
                #16 structural [Lean.Parser.Tactic.tacticSeq1Indented]  5:4–5:12  ?g4 ⟶ —
                  #17 surface `exact hx`  5:4–5:12  ?g4 ⟶ —   [exact hx]
  goals
    ?g0 ⊢ A ⊆ A ∩ A   ctx [α, A]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A → x ∈ A ∩ A   ctx [α, A, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A ∩ A   ctx [α, A, x, hx]   parent ?g1
        assigned by #7: ⟨?g3, ?g4⟩
    ?g3 (left) ⊢ x ∈ A   ctx [α, A, x, hx]   parent ?g2
        assigned by #12: hx
    ?g4 (right) ⊢ x ∈ A   ctx [α, A, x, hx]   parent ?g2
        assigned by #17: hx
  hyps
    α : Type u_1   {implicit}
    A : Set α
    x : α
    hx : x ∈ A
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem with_constructor (A : Set α) : A ⊆ A ∩ A := by
  intro x hx
  constructor
  · exact hx
  · exact hx

/-! An `example`, which has no declaration to compare with. -/
/--
info: ProofIR _example
  statement
    binders     [α, A]
    conclusion  A ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:31–3:10  ?g0 ⟶ —
      #1 structural [by]  1:31–1:33  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:10  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:10  ?g0 ⟶ —
            #4 surface `intro x hx`  2:2–2:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
              #6 inner `hx`  2:10–2:12  ?g1 ⟶ ?g2
            #7 surface `exact hx`  3:2–3:10  ?g2 ⟶ —   [exact hx]
  goals
    ?g0 ⊢ A ⊆ A   ctx [α, A]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A → x ∈ A   ctx [α, A, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A   ctx [α, A, x, hx]   parent ?g1
        assigned by #7: hx
  hyps
    α : Type u_1   {implicit}
    A : Set α
    x : α
    hx : x ∈ A
  proof term: no declaration to compare with
-/
#guard_msgs in
#proof_ir
example (A : Set α) : A ⊆ A := by
  intro x hx
  exact hx

/-! A command without tactic proofs. -/
/--
info: no tactic proofs
-/
#guard_msgs in
#proof_ir
theorem term_proof (A : Set α) : A ⊆ A := fun _ hx => hx
