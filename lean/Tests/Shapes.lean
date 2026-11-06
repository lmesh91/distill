import Distill.Informalizer.Extract.Frontend
import Distill.Levels.Demo

/-! Proof shapes beyond the demo levels, each of which once gave a wrong or no Proof IR. -/

open Distill Distill.Levels.Demo

/-! A failed alternative is backtracked: its nodes are inner and its goals (`?✗`) are not in
the goal table. -/
/--
info: ProofIR backtracked
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ B ∩ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:53–3:60  ?g0 ⟶ —
      #1 structural [by]  1:53–1:55  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:60  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:60  ?g0 ⟶ —
            #4 surface `intro x hx`  2:2–2:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
              #6 inner `hx`  2:10–2:12  ?g1 ⟶ ?g2
            #7 surface `first | (refine ⟨?_, ?_⟩; exact hx.1) |…`  3:2–3:60  ?g2 ⟶ —   [unrecognized]
              #8 inner `(refine ⟨?_, ?_⟩; exact hx.1)`  3:10–3:39  ?g2 ⟶ ?✗ ?✗
                #9 inner `(refine ⟨?_, ?_⟩; exact hx.1)`  3:10–3:39  ?g2 ⟶ ?✗ ?✗
                  #10 inner `(refine ⟨?_, ?_⟩; exact hx.1)`  3:10–3:39  ?g2 ⟶ ?✗ ?✗
                    #11 inner `refine ⟨?_, ?_⟩; exact hx.1`  3:11–3:38  ?g2 ⟶ ?✗ ?✗
                      #12 inner `refine ⟨?_, ?_⟩; exact hx.1`  3:11–3:38  ?g2 ⟶ ?✗ ?✗
                        #13 inner `refine ⟨?_, ?_⟩`  3:11–3:26  ?g2 ⟶ ?✗ ?✗
                        #14 inner `;`  3:26–3:27  ?✗ ?✗ ⟶ ?✗ ?✗
                        #15 inner `exact hx.1`  3:28–3:38  ?✗ ?✗ ⟶ ?✗ ?✗
              #16 structural [Lean.Parser.Tactic.tacticSeq]  3:42–3:60  ?g2 ⟶ —
                #17 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:42–3:60  ?g2 ⟶ —
                  #18 surface `exact ⟨hx.2, hx.1⟩`  3:42–3:60  ?g2 ⟶ —   [exact ⟨hx.right, hx.left⟩]
  goals
    ?g0 ⊢ A ∩ B ⊆ B ∩ A   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ B ∩ A   ctx [α, A, B, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ B ∩ A   ctx [α, A, B, x, hx]   parent ?g1
        assigned by #18: ⟨hx.right, hx.left⟩
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
theorem backtracked (A B : Set α) : A ∩ B ⊆ B ∩ A := by
  intro x hx
  first | (refine ⟨?_, ?_⟩; exact hx.1) | exact ⟨hx.2, hx.1⟩

/-! The goal of the failed `exact hx.2` is assigned by the second alternative, not by it. -/
/--
info: ProofIR failed_alternative
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:56–3:33  ?g0 ⟶ —
      #1 structural [by]  1:56–1:58  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:33  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:33  ?g0 ⟶ —
            #4 surface `intro x hx`  2:2–2:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
              #6 inner `hx`  2:10–2:12  ?g1 ⟶ ?g2
            #7 surface `first | exact hx.2 | exact hx.1`  3:2–3:33  ?g2 ⟶ —   [unrecognized]
              #8 inner `exact hx.2`  3:10–3:20  ?g2 ⟶ ?g2
                #9 inner `exact hx.2`  3:10–3:20  ?g2 ⟶ ?g2
                  #10 inner `exact hx.2`  3:10–3:20  ?g2 ⟶ ?g2
              #11 structural [Lean.Parser.Tactic.tacticSeq]  3:23–3:33  ?g2 ⟶ —
                #12 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:23–3:33  ?g2 ⟶ —
                  #13 surface `exact hx.1`  3:23–3:33  ?g2 ⟶ —   [exact hx.left]
  goals
    ?g0 ⊢ A ∩ B ⊆ A   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ A   ctx [α, A, B, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g1
        assigned by #13: hx.left
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
theorem failed_alternative (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  first | exact hx.2 | exact hx.1

/-! `by` blocks nested in a term: their goals stay in the parent's proof as `?g3`, `?g4`. -/
/--
info: ProofIR nested_by
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ B ∩ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:51–3:38  ?g0 ⟶ —
      #1 structural [by]  1:51–1:53  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:38  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:38  ?g0 ⟶ —
            #4 surface `intro x hx`  2:2–2:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
              #6 inner `hx`  2:10–2:12  ?g1 ⟶ ?g2
            #7 surface `exact ⟨by exact hx.2, by exact hx.1⟩`  3:2–3:38  ?g2 ⟶ —   [exact ⟨?g3, ?g4⟩]
              #8 structural [Lean.Parser.Term.byTactic]  3:9–3:22  ?g3 ⟶ —
                #9 structural [by]  3:9–3:11  ?g3 ⟶ —
                  #10 structural [Lean.Parser.Tactic.tacticSeq]  3:12–3:22  ?g3 ⟶ —
                    #11 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:12–3:22  ?g3 ⟶ —
                      #12 surface `exact hx.2`  3:12–3:22  ?g3 ⟶ —   [exact hx.right]
              #13 structural [Lean.Parser.Term.byTactic]  3:24–3:37  ?g4 ⟶ —
                #14 structural [by]  3:24–3:26  ?g4 ⟶ —
                  #15 structural [Lean.Parser.Tactic.tacticSeq]  3:27–3:37  ?g4 ⟶ —
                    #16 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:27–3:37  ?g4 ⟶ —
                      #17 surface `exact hx.1`  3:27–3:37  ?g4 ⟶ —   [exact hx.left]
  goals
    ?g0 ⊢ A ∩ B ⊆ B ∩ A   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ B ∩ A   ctx [α, A, B, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ B ∩ A   ctx [α, A, B, x, hx]   parent ?g1
        assigned by #7: ⟨?g3, ?g4⟩
    ?g3 ⊢ x ∈ B   ctx [α, A, B, x, hx]   parent ?g2
        assigned by #12: hx.right
    ?g4 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g2
        assigned by #17: hx.left
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
theorem nested_by (A B : Set α) : A ∩ B ⊆ B ∩ A := by
  intro x hx
  exact ⟨by exact hx.2, by exact hx.1⟩

/-! The same under binders of the term. -/
/--
info: ProofIR nested_by_under_binders
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:61–2:33  ?g0 ⟶ —
      #1 structural [by]  1:61–1:63  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–2:33  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–2:33  ?g0 ⟶ —
            #4 surface `exact fun x hx => by exact hx.1`  2:2–2:33  ?g0 ⟶ —   [exact fun x hx => ?g1 x hx]
              #5 structural [Lean.Parser.Term.byTactic]  2:20–2:33  ?g1 ⟶ —
                #6 structural [by]  2:20–2:22  ?g1 ⟶ —
                  #7 structural [Lean.Parser.Tactic.tacticSeq]  2:23–2:33  ?g1 ⟶ —
                    #8 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:23–2:33  ?g1 ⟶ —
                      #9 surface `exact hx.1`  2:23–2:33  ?g1 ⟶ —   [exact hx.left]
  goals
    ?g0 ⊢ A ∩ B ⊆ A   ctx [α, A, B]
        assigned by #4: fun x hx => ?g1 x hx
    ?g1 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g0
        assigned by #9: hx.left
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
theorem nested_by_under_binders (A B : Set α) : A ∩ B ⊆ A := by
  exact fun x hx => by exact hx.1

/-! `rewrite … at h` replaces `h`: the subgoal is applied to the term the new `h` stands for. -/
/--
info: ProofIR rewrite_at
  statement
    binders     [a, b, h, h2]
    conclusion  a = 3
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:67–3:9  ?g0 ⟶ —
      #1 structural [by]  1:67–1:69  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:9  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:9  ?g0 ⟶ —
            #4 surface `rewrite [h2] at h`  2:2–2:19  ?g0 ⟶ ?g1   [unrecognized]
              #5 inner `rewrite [`  2:2–2:11  ?g0 ⟶ ?g0
              #6 inner `h2`  2:11–2:13  ?g0 ⟶ ?g1
            #7 surface `exact h`  3:2–3:9  ?g1 ⟶ —   [exact h]
  goals
    ?g0 ⊢ a = 3   ctx [a, b, h, h2]
        assigned by #6: ?g1 (Eq.mp (congrArg (fun _a => a = _a) h2) h) h2
    ?g1 ⊢ a = 3   ctx [a, b, h, h2]   parent ?g0
        assigned by #7: h
  hyps
    a : Nat
    b : Nat
    h : a = b
    h2 : b = 3
    h : a = 3   replaces h (inferred)
    h2 : b = 3   replaces h2
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem rewrite_at (a b : Nat) (h : a = b) (h2 : b = 3) : a = 3 := by
  rewrite [h2] at h
  exact h

/-! `intro` with a pattern also destructures, which `.intro` does not describe. -/
/--
info: ProofIR intro_pattern
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ B
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:51–3:10  ?g0 ⟶ —
      #1 structural [by]  1:51–1:53  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:10  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:10  ?g0 ⟶ —
            #4 surface `intro x ⟨ha, hb⟩`  2:2–2:18  ?g0 ⟶ ?g4   [unrecognized]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
              #6 inner `⟨ha, hb⟩`  2:10–2:18  ?g1 ⟶ ?g4
                #7 inner `intro  h  ;  match  @  h  with  | ⟨ha, …`  synthetic 2:10–2:18  ?g1 ⟶ ?g4
                  #8 inner `intro  h`  synthetic 2:10–2:18  ?g1 ⟶ ?g2   [intro [h✝]]
                    #9 inner `intro  h`  synthetic 2:10–2:18  ?g1 ⟶ ?g2
                  #10 inner `;`  synthetic 2:10–2:18  ?g2 ⟶ ?g2
                  #11 inner `match  @  h  with  | ⟨ha, hb⟩`  synthetic 2:10–2:18  ?g2 ⟶ ?g3
                    #12 inner `refine  no_implicit_lambda%  match  @  …`  synthetic 2:10–2:18  ?g2 ⟶ ?g3
                      #13 inner `refine  no_implicit_lambda%  match  @  …`  synthetic 2:10–2:18  ?g2 ⟶ ?g3   [refine match h✝ with | ⟨ha, hb⟩ => ?g3 ha hb]
                  #14 inner `;`  synthetic 2:10–2:18  ?g3 ⟶ ?g3
                  #15 inner `try  clear  h`  synthetic 2:10–2:18  ?g3 ⟶ ?g4
                    #16 inner `first  |  clear  h  |  skip`  synthetic 2:10–2:18  ?g3 ⟶ ?g4
                      #17 inner `clear  h`  synthetic 2:10–2:18  ?g3 ⟶ ?g4
                        #18 inner `clear  h`  synthetic 2:10–2:18  ?g3 ⟶ ?g4
                          #19 inner `clear  h`  synthetic 2:10–2:18  ?g3 ⟶ ?g4
            #20 surface `exact hb`  3:2–3:10  ?g4 ⟶ —   [exact hb]
  goals
    ?g0 ⊢ A ∩ B ⊆ B   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ B   ctx [α, A, B, x]   parent ?g0
        assigned by #9: fun h => ?g2 h
    ?g2 ⊢ x ∈ B   ctx [α, A, B, x, h✝]   parent ?g1
        assigned by #13: match h✝ with | ⟨ha, hb⟩ => ?g3 ha hb
    ?g3 ⊢ x ∈ B   ctx [α, A, B, x, h✝, ha, hb]   parent ?g2
        assigned by #19: ?g4
    ?g4 ⊢ x ∈ B   ctx [α, A, B, x, ha, hb]   parent ?g3
        assigned by #20: hb
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
    x : α
    h✝ : x ∈ A ∩ B
    ha : x ∈ A
    hb : x ∈ B
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem intro_pattern (A B : Set α) : A ∩ B ⊆ B := by
  intro x ⟨ha, hb⟩
  exact hb

/-! `by` blocks that are not the declaration's body each get a Proof IR of their own. -/
/--
info: ProofIR two_blocks   (a `by` block inside it)
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  2:3–2:28  ?g0 ⟶ —
      #1 structural [by]  2:3–2:5  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:6–2:28  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:6–2:28  ?g0 ⟶ —
            #4 surface `intro x hx`  2:6–2:16  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  2:6–2:13  ?g0 ⟶ ?g1
              #6 inner `hx`  2:14–2:16  ?g1 ⟶ ?g2
            #7 structural [«;»]  2:16–2:17  ?g2 ⟶ ?g2
            #8 surface `exact hx.1`  2:18–2:28  ?g2 ⟶ —   [exact hx.left]
  goals
    ?g0 ⊢ A ∩ B ⊆ A   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ A   ctx [α, A, B, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g1
        assigned by #8: hx.left
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
    x : α
    hx : x ∈ A ∩ B
  proof term: not compared (the `by` block is not the declaration's body)
---
info: ProofIR two_blocks   (a `by` block inside it)
  statement
    binders     [α, A, B, x, hx]
    conclusion  x ∈ B
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  2:42–2:55  ?g0 ⟶ —
      #1 structural [by]  2:42–2:44  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:45–2:55  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:45–2:55  ?g0 ⟶ —
            #4 surface `exact hx.2`  2:45–2:55  ?g0 ⟶ —   [exact hx.right]
  goals
    ?g0 ⊢ x ∈ B   ctx [α, A, B, x, hx]
        assigned by #4: hx.right
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
    x : α
    hx : x ∈ A ∩ B
  proof term: not compared (the `by` block is not the declaration's body)
-/
#guard_msgs in
#proof_ir
theorem two_blocks (A B : Set α) : A ∩ B ⊆ A ∧ A ∩ B ⊆ B :=
  ⟨by intro x hx; exact hx.1, fun x hx => by exact hx.2⟩

/-! `fail_if_success` always undoes its tactics, so they are inner and unrecognized. -/
/--
info: ProofIR rolled_back
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:49–4:12  ?g0 ⟶ —
      #1 structural [by]  1:49–1:51  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–4:12  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–4:12  ?g0 ⟶ —
            #4 surface `intro x hx`  2:2–2:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
              #6 inner `hx`  2:10–2:12  ?g1 ⟶ ?g2
            #7 surface `fail_if_success (refine ⟨?_, ?_⟩; exact…`  3:2–3:47  ?g2 ⟶ ?g2   [unrecognized]
              #8 inner `(refine ⟨?_, ?_⟩; exact hx.1)`  3:18–3:47  ?g2 ⟶ ?g2
                #9 inner `(refine ⟨?_, ?_⟩; exact hx.1)`  3:18–3:47  ?g2 ⟶ ?g2
                  #10 inner `(refine ⟨?_, ?_⟩; exact hx.1)`  3:18–3:47  ?g2 ⟶ ?g2
                    #11 inner `refine ⟨?_, ?_⟩; exact hx.1`  3:19–3:46  ?g2 ⟶ ?g2
                      #12 inner `refine ⟨?_, ?_⟩; exact hx.1`  3:19–3:46  ?g2 ⟶ ?g2
                        #13 inner `refine ⟨?_, ?_⟩`  3:19–3:34  ?g2 ⟶ ?g2
            #14 surface `exact hx.1`  4:2–4:12  ?g2 ⟶ —   [exact hx.left]
  goals
    ?g0 ⊢ A ∩ B ⊆ A   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ A   ctx [α, A, B, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g1
        assigned by #14: hx.left
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
theorem rolled_back (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  fail_if_success (refine ⟨?_, ?_⟩; exact hx.1)
  exact hx.1

/-! An iteration of `repeat` that fails is rolled back: its assignment is not in the final
state. -/
/--
info: ProofIR repeat_rollback
  statement
    binders     []
    conclusion  True ∨ True
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:41–3:22  ?g0 ⟶ —
      #1 structural [by]  1:41–1:43  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:22  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:22  ?g0 ⟶ —
            #4 surface `repeat (exact Or.inl trivial; fail)`  2:2–2:37  ?g0 ⟶ ?g0   [unrecognized]
              #5 inner `(exact Or.inl trivial; fail)`  2:9–2:37  ?g0 ⟶ —
                #6 inner `(exact Or.inl trivial; fail)`  2:9–2:37  ?g0 ⟶ —
                  #7 inner `(exact Or.inl trivial; fail)`  2:9–2:37  ?g0 ⟶ —
                    #8 inner `exact Or.inl trivial; fail`  2:10–2:36  ?g0 ⟶ —
                      #9 inner `exact Or.inl trivial; fail`  2:10–2:36  ?g0 ⟶ —
                        #10 inner `exact Or.inl trivial`  2:10–2:30  ?g0 ⟶ —
                        #11 inner `;`  2:30–2:31  — ⟶ —
                        #12 inner `fail`  2:32–2:36  — ⟶ —
            #13 surface `exact Or.inr trivial`  3:2–3:22  ?g0 ⟶ —   [exact Or.inr trivial]
  goals
    ?g0 ⊢ True ∨ True   ctx []
        assigned by #13: Or.inr trivial
  hyps
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem repeat_rollback : True ∨ True := by
  repeat (exact Or.inl trivial; fail)
  exact Or.inr trivial

/-! A nested `by` whose proof also appears elsewhere in the term: the subgoal stays where the
`by` was. -/
/--
info: ProofIR nested_by_duplicate
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ B ∩ B
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:61–3:29  ?g0 ⟶ —
      #1 structural [by]  1:61–1:63  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:29  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:29  ?g0 ⟶ —
            #4 surface `intro x hx`  2:2–2:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
              #6 inner `hx`  2:10–2:12  ?g1 ⟶ ?g2
            #7 surface `exact ⟨by exact hx.2, hx.2⟩`  3:2–3:29  ?g2 ⟶ —   [exact ⟨?g3, hx.right⟩]
              #8 structural [Lean.Parser.Term.byTactic]  3:9–3:22  ?g3 ⟶ —
                #9 structural [by]  3:9–3:11  ?g3 ⟶ —
                  #10 structural [Lean.Parser.Tactic.tacticSeq]  3:12–3:22  ?g3 ⟶ —
                    #11 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:12–3:22  ?g3 ⟶ —
                      #12 surface `exact hx.2`  3:12–3:22  ?g3 ⟶ —   [exact hx.right]
  goals
    ?g0 ⊢ A ∩ B ⊆ B ∩ B   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ B ∩ B   ctx [α, A, B, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ B ∩ B   ctx [α, A, B, x, hx]   parent ?g1
        assigned by #7: ⟨?g3, hx.right⟩
    ?g3 ⊢ x ∈ B   ctx [α, A, B, x, hx]   parent ?g2
        assigned by #12: hx.right
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
theorem nested_by_duplicate (A B : Set α) : A ∩ B ⊆ B ∩ B := by
  intro x hx
  exact ⟨by exact hx.2, hx.2⟩

/-! A `have … := by` inside a `by` inside a term: the `have` is recorded as the tactic assigned
it, before its subgoals were filled in. -/
/--
info: ProofIR have_in_nested_by
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ B ∩ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:59–4:40  ?g0 ⟶ —
      #1 structural [by]  1:59–1:61  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–4:40  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–4:40  ?g0 ⟶ —
            #4 surface `exact fun x hx => (⟨by`  2:2–4:40  ?g0 ⟶ —   [exact fun x hx => ⟨?g1 x hx, ?g4 x hx⟩]
              #5 structural [Lean.Parser.Term.byTactic]  2:22–4:11  ?g1 ⟶ —
                #6 structural [by]  2:22–2:24  ?g1 ⟶ —
                  #7 structural [Lean.Parser.Tactic.tacticSeq]  3:4–4:11  ?g1 ⟶ —
                    #8 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:4–4:11  ?g1 ⟶ —
                      #9 surface `have h : x ∈ B := by exact hx.2`  3:4–3:35  ?g1 ⟶ ?g3   [have h : x ∈ B := by ?g2]
                        #10 inner `focus  refine  no_implicit_lambda%  (  …`  synthetic 3:4–3:8  ?g1 ⟶ ?g3
                          #11 inner `focus`  synthetic 3:4–3:8  ?g1 ⟶ ?g1
                          #12 inner `refine  no_implicit_lambda%  (  [anonym…`  synthetic 3:4–3:8  ?g1 ⟶ ?g3
                            #13 inner `refine  no_implicit_lambda%  (  [anonym…`  synthetic 3:4–3:8  ?g1 ⟶ ?g3
                              #14 inner `refine  no_implicit_lambda%  (  [anonym…`  synthetic 3:4–3:8  ?g1 ⟶ ?g2 ?g3   [refine have h := ?g2; ?g3 h]
                              #15 inner ``  synthetic 3:4–3:8  ?g2 ?g3 ⟶ ?g2 ?g3
                              #16 inner `case  body  =>  with_annotate_state by …`  synthetic 3:22–3:24  ?g2 ?g3 ⟶ ?g3
                                #17 inner `case  =>`  synthetic 3:22–3:24  ?g2 ⟶ —
                                  #18 inner `with_annotate_state by  ( exact hx.2`  synthetic 3:4–3:35  ?g2 ⟶ —
                                    #19 inner `with_annotate_state by  ( exact hx.2`  synthetic 3:4–3:35  ?g2 ⟶ —
                                      #20 inner `with_annotate_state by  ( exact hx.2`  synthetic 3:22–3:24  ?g2 ⟶ —
                                        #21 structural [by]  3:22–3:24  ?g2 ⟶ —
                                          #22 inner `( exact hx.2`  synthetic 3:22–3:24  ?g2 ⟶ —
                                            #23 inner `exact hx.2`  synthetic 3:22–3:24  ?g2 ⟶ —
                                              #24 inner `exact hx.2`  synthetic 3:22–3:24  ?g2 ⟶ —
                                                #25 surface `exact hx.2`  3:25–3:35  ?g2 ⟶ —   [exact hx.right]
                      #26 surface `exact h`  4:4–4:11  ?g3 ⟶ —   [exact h]
              #27 structural [Lean.Parser.Term.byTactic]  4:13–4:26  ?g4 ⟶ —
                #28 structural [by]  4:13–4:15  ?g4 ⟶ —
                  #29 structural [Lean.Parser.Tactic.tacticSeq]  4:16–4:26  ?g4 ⟶ —
                    #30 structural [Lean.Parser.Tactic.tacticSeq1Indented]  4:16–4:26  ?g4 ⟶ —
                      #31 surface `exact hx.1`  4:16–4:26  ?g4 ⟶ —   [exact hx.left]
  goals
    ?g0 ⊢ A ∩ B ⊆ B ∩ A   ctx [α, A, B]
        assigned by #4: fun x hx => ⟨?g1 x hx, ?g4 x hx⟩
    ?g1 ⊢ x ∈ B   ctx [α, A, B, x, hx]   parent ?g0
        assigned by #14: have h := ?g2; ?g3 h
    ?g2 ⊢ x ∈ B   ctx [α, A, B, x, hx]   parent ?g1
        assigned by #25: hx.right
    ?g3 ⊢ x ∈ B   ctx [α, A, B, x, hx, h]   parent ?g1
        assigned by #26: h
    ?g4 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g0
        assigned by #31: hx.left
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
    x : α
    hx : x ∈ A ∩ B
    h : x ∈ B
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem have_in_nested_by (A B : Set α) : A ∩ B ⊆ B ∩ A := by
  exact fun x hx => (⟨by
    have h : x ∈ B := by exact hx.2
    exact h, by exact hx.1⟩ : x ∈ B ∩ A)

/-! The bodies of `where` definitions and of every declaration in a `mutual` block are
declaration bodies. -/
/--
info: ProofIR with_where.aux
  statement
    binders     []
    conclusion  True
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:53–1:63  ?g0 ⟶ —
      #1 structural [by]  1:53–1:55  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  1:56–1:63  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  1:56–1:63  ?g0 ⟶ —
            #4 surface `trivial`  1:56–1:63  ?g0 ⟶ —   [unrecognized]
              #5 inner `apply  True.intro`  synthetic 1:56–1:63  ?g0 ⟶ —   [apply True.intro]
  goals
    ?g0 ⊢ True   ctx []
        assigned by #5: True.intro
  hyps
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem with_where : True := aux where aux : True := by trivial

/--
info: ProofIR mutual_a
  statement
    binders     []
    conclusion  True
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  2:27–2:37  ?g0 ⟶ —
      #1 structural [by]  2:27–2:29  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:30–2:37  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:30–2:37  ?g0 ⟶ —
            #4 surface `trivial`  2:30–2:37  ?g0 ⟶ —   [unrecognized]
              #5 inner `apply  True.intro`  synthetic 2:30–2:37  ?g0 ⟶ —   [apply True.intro]
  goals
    ?g0 ⊢ True   ctx []
        assigned by #5: True.intro
  hyps
  proof term: rebuilds the declaration's proof term
---
info: ProofIR mutual_b
  statement
    binders     []
    conclusion  True
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  3:27–3:37  ?g0 ⟶ —
      #1 structural [by]  3:27–3:29  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  3:30–3:37  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:30–3:37  ?g0 ⟶ —
            #4 surface `trivial`  3:30–3:37  ?g0 ⟶ —   [unrecognized]
              #5 inner `apply  True.intro`  synthetic 3:30–3:37  ?g0 ⟶ —   [apply True.intro]
  goals
    ?g0 ⊢ True   ctx []
        assigned by #5: True.intro
  hyps
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
mutual
theorem mutual_a : True := by trivial
theorem mutual_b : True := by trivial
end

/-! `cases … with`: each branch's goal is applied to the hypotheses it adds, not to the
equations `cases` uses internally. -/
/--
info: ProofIR cases_or
  statement
    binders     [p, q, h]
    conclusion  q ∨ p
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:53–4:29  ?g0 ⟶ —
      #1 structural [by]  1:53–1:55  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–4:29  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–4:29  ?g0 ⟶ —
            #4 surface `cases h with`  2:2–4:29  ?g0 ⟶ —   [unrecognized]
              #5 inner `cases h with`  2:2–2:14  ?g0 ⟶ —
                #6 inner `| inl hp =>`  3:2–3:13  ?g1 ⟶ —
                  #7 structural [Lean.Parser.Tactic.tacticSeq]  3:14–3:29  ?g1 ⟶ —
                    #8 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:14–3:29  ?g1 ⟶ —
                      #9 surface `exact Or.inr hp`  3:14–3:29  ?g1 ⟶ —   [exact Or.inr hp]
                #10 inner `| inr hq =>`  4:2–4:13  ?g2 ⟶ —
                  #11 structural [Lean.Parser.Tactic.tacticSeq]  4:14–4:29  ?g2 ⟶ —
                    #12 structural [Lean.Parser.Tactic.tacticSeq1Indented]  4:14–4:29  ?g2 ⟶ —
                      #13 surface `exact Or.inl hq`  4:14–4:29  ?g2 ⟶ —   [exact Or.inl hq]
  goals
    ?g0 ⊢ q ∨ p   ctx [p, q, h]
        assigned by #5: Or.casesOn (motive := fun t => h = t → q ∨ p) h (fun hp h => ?g1 hp) (fun hq h => ?g2 hq) (Eq.refl h)
    ?g1 (inl) ⊢ q ∨ p   ctx [p, q, hp]   parent ?g0
        assigned by #9: Or.inr hp
    ?g2 (inr) ⊢ q ∨ p   ctx [p, q, hq]   parent ?g0
        assigned by #13: Or.inl hq
  hyps
    p : Prop
    q : Prop
    h : p ∨ q
    hp : p
    hq : q
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem cases_or (p q : Prop) (h : p ∨ q) : q ∨ p := by
  cases h with
  | inl hp => exact Or.inr hp
  | inr hq => exact Or.inl hq

/-! Rewriting two hypotheses at once. -/
/--
info: ProofIR rw_two_hyps
  statement
    binders     [a, b, e, h1, h2]
    conclusion  b = 1
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:81–3:10  ?g0 ⟶ —
      #1 structural [by]  1:81–1:83  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:10  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:10  ?g0 ⟶ —
            #4 surface `rw [e] at h1 h2`  2:2–2:17  ?g0 ⟶ ?g1   [unrecognized]
              #5 inner `(  rewrite  [ e ] at h1 h2`  synthetic 2:2–2:17  ?g0 ⟶ ?g1
                #6 inner `rewrite  [ e ] at h1 h2`  synthetic 2:2–2:17  ?g0 ⟶ ?g1
                  #7 inner `rewrite  [ e ] at h1 h2`  synthetic 2:2–2:17  ?g0 ⟶ ?g1
                    #8 inner `rewrite  [ e ] at h1 h2`  synthetic 2:2–2:17  ?g0 ⟶ ?g1
                      #9 inner `rewrite  [`  synthetic 2:2–2:17  ?g0 ⟶ ?g0
                      #10 inner `e`  2:6–2:7  ?g0 ⟶ ?g1
                    #11 inner `;`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                    #12 inner `with_annotate_state ]  (  try  (  with_…`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                      #13 inner `]`  2:7–2:8  ?g1 ⟶ ?g1
                        #14 inner `(  try  (  with_reducible  rfl  )  )`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                          #15 inner `try  (  with_reducible  rfl  )`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                            #16 inner `try  (  with_reducible  rfl  )`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                              #17 inner `try  (  with_reducible  rfl  )`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                #18 inner `first  |  (  with_reducible  rfl  )  | …`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                  #19 inner `(  with_reducible  rfl  )`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                    #20 inner `(  with_reducible  rfl  )`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                      #21 inner `(  with_reducible  rfl  )`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                        #22 inner `with_reducible  rfl`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                          #23 inner `with_reducible  rfl`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                            #24 inner `with_reducible  rfl`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                              #25 inner `rfl`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                                #26 inner `rfl`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                                  #27 inner `rfl`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                                    #28 inner `apply_rfl`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                  #29 inner `skip`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                    #30 inner `skip`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
                                      #31 inner `skip`  synthetic 2:2–2:17  ?g1 ⟶ ?g1
            #32 surface `exact h1`  3:2–3:10  ?g1 ⟶ —   [exact h1]
  goals
    ?g0 ⊢ b = 1   ctx [a, b, e, h1, h2]
        assigned by #10: ?g1 (Eq.mp (congrArg (fun _a => _a = 1) e) h1) (Eq.mp (congrArg (fun _a => _a = 2) e) h2)
    ?g1 ⊢ b = 1   ctx [a, b, e, h1, h2]   parent ?g0
        assigned by #32: h1
  hyps
    a : Nat
    b : Nat
    e : a = b
    h1 : a = 1
    h2 : a = 2
    h1 : b = 1   replaces h1 (inferred)
    h2 : b = 2   replaces h2 (inferred)
  proof term: rebuilds the declaration's proof term
---
warning: Variable name `h2` is not explicitly referenced.

Hint: The binding can be removed (if unused) or named `_` (if used implicitly). Alternatively, prefix the name with `_` to silence this warning:
  [apply] _h2

Note: This linter can be disabled with `set_option linter.unusedVariables false`
-/
#guard_msgs in
#proof_ir
theorem rw_two_hyps (a b : Nat) (e : a = b) (h1 : a = 1) (h2 : a = 2) : b = 1 := by
  rw [e] at h1 h2
  exact h1

/-! `calc` builds its term itself, so its steps' goals are found by their proofs. -/
/--
info: ProofIR calc_steps
  statement
    binders     [a, b, c, h1, h2]
    conclusion  a = c
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:70–3:23  ?g0 ⟶ —
      #1 structural [by]  1:70–1:72  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:23  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:23  ?g0 ⟶ —
            #4 surface `calc a = b := by rw [h1]`  2:2–3:23  ?g0 ⟶ —   [unrecognized]
              #5 inner `a = b := by rw [h1]`  2:7–3:23  — ⟶ —
                #6 structural [Lean.Parser.Term.byTactic]  2:16–2:26  ?g1 ⟶ —
                  #7 structural [by]  2:16–2:18  ?g1 ⟶ —
                    #8 structural [Lean.Parser.Tactic.tacticSeq]  2:19–2:26  ?g1 ⟶ —
                      #9 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:19–2:26  ?g1 ⟶ —
                        #10 surface `rw [h1]`  2:19–2:26  ?g1 ⟶ —   [unrecognized]
                          #11 inner `(  rewrite  [ h1 ]  ;  with_annotate_st…`  synthetic 2:19–2:26  ?g1 ⟶ —
                            #12 inner `rewrite  [ h1 ]  ;  with_annotate_state…`  synthetic 2:19–2:26  ?g1 ⟶ —
                              #13 inner `rewrite  [ h1 ]  ;  with_annotate_state…`  synthetic 2:19–2:26  ?g1 ⟶ —
                                #14 inner `rewrite  [ h1 ]`  synthetic 2:19–2:26  ?g1 ⟶ ?g2
                                  #15 inner `rewrite  [`  synthetic 2:19–2:26  ?g1 ⟶ ?g1
                                  #16 inner `h1`  2:23–2:25  ?g1 ⟶ ?g2
                                #17 inner `;`  synthetic 2:19–2:26  ?g2 ⟶ ?g2
                                #18 inner `with_annotate_state ]`  synthetic 2:19–2:26  ?g2 ⟶ —
                                  #19 inner `]`  2:25–2:26  ?g2 ⟶ —
                                    #20 inner `(  try  (  with_reducible  rfl  )  )`  synthetic 2:19–2:26  ?g2 ⟶ —
                                      #21 inner `try  (  with_reducible  rfl  )`  synthetic 2:19–2:26  ?g2 ⟶ —
                                        #22 inner `try  (  with_reducible  rfl  )`  synthetic 2:19–2:26  ?g2 ⟶ —
                                          #23 inner `try  (  with_reducible  rfl  )`  synthetic 2:19–2:26  ?g2 ⟶ —
                                            #24 inner `first  |  (  with_reducible  rfl  )  | …`  synthetic 2:19–2:26  ?g2 ⟶ —
                                              #25 inner `(  with_reducible  rfl  )`  synthetic 2:19–2:26  ?g2 ⟶ —
                                                #26 inner `(  with_reducible  rfl  )`  synthetic 2:19–2:26  ?g2 ⟶ —
                                                  #27 inner `(  with_reducible  rfl  )`  synthetic 2:19–2:26  ?g2 ⟶ —
                                                    #28 inner `with_reducible  rfl`  synthetic 2:19–2:26  ?g2 ⟶ —
                                                      #29 inner `with_reducible  rfl`  synthetic 2:19–2:26  ?g2 ⟶ —
                                                        #30 inner `with_reducible  rfl`  synthetic 2:19–2:26  ?g2 ⟶ —
                                                          #31 inner `rfl`  synthetic 2:19–2:26  ?g2 ⟶ —
                                                            #32 inner `rfl`  synthetic 2:19–2:26  ?g2 ⟶ —
                                                              #33 inner `rfl`  synthetic 2:19–2:26  ?g2 ⟶ —
                                                                #34 inner `eq_refl`  synthetic 2:19–2:26  ?g2 ⟶ —
                #35 structural [Lean.Parser.Term.byTactic]  3:13–3:23  ?g3 ⟶ —
                  #36 structural [by]  3:13–3:15  ?g3 ⟶ —
                    #37 structural [Lean.Parser.Tactic.tacticSeq]  3:16–3:23  ?g3 ⟶ —
                      #38 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:16–3:23  ?g3 ⟶ —
                        #39 surface `rw [h2]`  3:16–3:23  ?g3 ⟶ —   [unrecognized]
                          #40 inner `(  rewrite  [ h2 ]  ;  with_annotate_st…`  synthetic 3:16–3:23  ?g3 ⟶ —
                            #41 inner `rewrite  [ h2 ]  ;  with_annotate_state…`  synthetic 3:16–3:23  ?g3 ⟶ —
                              #42 inner `rewrite  [ h2 ]  ;  with_annotate_state…`  synthetic 3:16–3:23  ?g3 ⟶ —
                                #43 inner `rewrite  [ h2 ]`  synthetic 3:16–3:23  ?g3 ⟶ ?g4
                                  #44 inner `rewrite  [`  synthetic 3:16–3:23  ?g3 ⟶ ?g3
                                  #45 inner `h2`  3:20–3:22  ?g3 ⟶ ?g4
                                #46 inner `;`  synthetic 3:16–3:23  ?g4 ⟶ ?g4
                                #47 inner `with_annotate_state ]`  synthetic 3:16–3:23  ?g4 ⟶ —
                                  #48 inner `]`  3:22–3:23  ?g4 ⟶ —
                                    #49 inner `(  try  (  with_reducible  rfl  )  )`  synthetic 3:16–3:23  ?g4 ⟶ —
                                      #50 inner `try  (  with_reducible  rfl  )`  synthetic 3:16–3:23  ?g4 ⟶ —
                                        #51 inner `try  (  with_reducible  rfl  )`  synthetic 3:16–3:23  ?g4 ⟶ —
                                          #52 inner `try  (  with_reducible  rfl  )`  synthetic 3:16–3:23  ?g4 ⟶ —
                                            #53 inner `first  |  (  with_reducible  rfl  )  | …`  synthetic 3:16–3:23  ?g4 ⟶ —
                                              #54 inner `(  with_reducible  rfl  )`  synthetic 3:16–3:23  ?g4 ⟶ —
                                                #55 inner `(  with_reducible  rfl  )`  synthetic 3:16–3:23  ?g4 ⟶ —
                                                  #56 inner `(  with_reducible  rfl  )`  synthetic 3:16–3:23  ?g4 ⟶ —
                                                    #57 inner `with_reducible  rfl`  synthetic 3:16–3:23  ?g4 ⟶ —
                                                      #58 inner `with_reducible  rfl`  synthetic 3:16–3:23  ?g4 ⟶ —
                                                        #59 inner `with_reducible  rfl`  synthetic 3:16–3:23  ?g4 ⟶ —
                                                          #60 inner `rfl`  synthetic 3:16–3:23  ?g4 ⟶ —
                                                            #61 inner `rfl`  synthetic 3:16–3:23  ?g4 ⟶ —
                                                              #62 inner `rfl`  synthetic 3:16–3:23  ?g4 ⟶ —
                                                                #63 inner `eq_refl`  synthetic 3:16–3:23  ?g4 ⟶ —
  goals
    ?g0 ⊢ a = c   ctx [a, b, c, h1, h2]
        assigned by #4: trans ?g1 ?g3
    ?g1 ⊢ a = b   ctx [a, b, c, h1, h2]   parent ?g0
        assigned by #16: Eq.mpr (id (congrArg (fun _a => _a = b) h1)) ?g2
    ?g2 ⊢ b = b   ctx [a, b, c, h1, h2]   parent ?g1
        assigned by #34: Eq.refl b
    ?g3 ⊢ b = c   ctx [a, b, c, h1, h2]   parent ?g0
        assigned by #45: Eq.mpr (id (congrArg (fun _a => _a = c) h2)) ?g4
    ?g4 ⊢ c = c   ctx [a, b, c, h1, h2]   parent ?g3
        assigned by #63: Eq.refl c
  hyps
    a : Nat
    b : Nat
    c : Nat
    h1 : a = b
    h2 : b = c
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem calc_steps (a b c : Nat) (h1 : a = b) (h2 : b = c) : a = c := by
  calc a = b := by rw [h1]
    _ = c := by rw [h2]

/-! A `by` block as the whole term elaborates no term around it. -/
/--
info: ProofIR exact_by
  statement
    binders     [q, hq]
    conclusion  q
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:44–2:21  ?g0 ⟶ —
      #1 structural [by]  1:44–1:46  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–2:21  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–2:21  ?g0 ⟶ —
            #4 surface `exact (by exact hq)`  2:2–2:21  ?g0 ⟶ —   [exact ?g1]
              #5 structural [Lean.Parser.Term.byTactic]  2:9–2:20  ?g1 ⟶ —
                #6 structural [by]  2:9–2:11  ?g1 ⟶ —
                  #7 structural [Lean.Parser.Tactic.tacticSeq]  2:12–2:20  ?g1 ⟶ —
                    #8 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:12–2:20  ?g1 ⟶ —
                      #9 surface `exact hq`  2:12–2:20  ?g1 ⟶ —   [exact hq]
  goals
    ?g0 ⊢ q   ctx [q, hq]
        assigned by #4: ?g1
    ?g1 ⊢ q   ctx [q, hq]   parent ?g0
        assigned by #9: hq
  hyps
    q : Prop
    hq : q
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem exact_by (q : Prop) (hq : q) : q := by
  exact (by exact hq)

/-! Case tags are those the goals had when created; `case` and `next` clear them. -/
/--
info: ProofIR case_tags
  statement
    binders     [p, q, hp, hq]
    conclusion  p ∧ q
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:60–4:18  ?g0 ⟶ —
      #1 structural [by]  1:60–1:62  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–4:18  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–4:18  ?g0 ⟶ —
            #4 surface `apply And.intro`  2:2–2:17  ?g0 ⟶ ?g1 ?g2   [apply ⟨?g1, ?g2⟩]
            #5 structural [Lean.Parser.Tactic.case]  3:2–3:23  ?g1 ?g2 ⟶ ?g2
              #6 structural [null]  3:2–3:14  ?g1 ⟶ —
                #7 structural [Lean.Parser.Tactic.tacticSeq]  3:15–3:23  ?g1 ⟶ —
                  #8 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:15–3:23  ?g1 ⟶ —
                    #9 surface `exact hp`  3:15–3:23  ?g1 ⟶ —   [exact hp]
            #10 structural [Lean.Parser.Tactic.«tacticNext_=>_»]  4:2–4:18  ?g2 ⟶ —
              #11 structural [Lean.Parser.Tactic.case]  synthetic 4:7–4:9  ?g2 ⟶ —
                #12 structural [null]  synthetic 4:2–4:9  ?g2 ⟶ —
                  #13 structural [Lean.Parser.Tactic.tacticSeq]  4:10–4:18  ?g2 ⟶ —
                    #14 structural [Lean.Parser.Tactic.tacticSeq1Indented]  4:10–4:18  ?g2 ⟶ —
                      #15 surface `exact hq`  4:10–4:18  ?g2 ⟶ —   [exact hq]
  goals
    ?g0 ⊢ p ∧ q   ctx [p, q, hp, hq]
        assigned by #4: ⟨?g1, ?g2⟩
    ?g1 (left) ⊢ p   ctx [p, q, hp, hq]   parent ?g0
        assigned by #9: hp
    ?g2 (right) ⊢ q   ctx [p, q, hp, hq]   parent ?g0
        assigned by #15: hq
  hyps
    p : Prop
    q : Prop
    hp : p
    hq : q
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem case_tags (p q : Prop) (hp : p) (hq : q) : p ∧ q := by
  apply And.intro
  case left => exact hp
  next => exact hq

/-! A goal created by a tactic that then failed gets the goal of that tactic as its parent. -/
/--
error: Unknown identifier `x`
---
error: Tactic `assumption` failed

α : Type u_1
A B : Set α
x✝ : α
a✝ : x✝ ∈ A ∩ B
⊢ sorry ∈ A ∩ B
---
info: ProofIR failed_tactic_goal
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:56–3:21  ?g0 ⟶ ?g2
      #1 structural [by]  1:56–1:58  ?g0 ⟶ ?g2
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:21  ?g0 ⟶ ?g2
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:21  ?g0 ⟶ ?g2
            #4 surface `repeat intro _`  2:2–2:16  ?g0 ⟶ ?g2   [unrecognized]
              #5 structural [Lean.Parser.Tactic.tacticSeq]  2:9–2:16  ?g0 ⟶ ?g1
                #6 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:9–2:16  ?g0 ⟶ ?g1
                  #7 surface `intro _`  2:9–2:16  ?g0 ⟶ ?g1   [intro [x✝]]
                    #8 inner `intro _`  2:9–2:16  ?g0 ⟶ ?g1
              #9 structural [Lean.Parser.Tactic.tacticSeq]  2:9–2:16  ?g1 ⟶ ?g2
                #10 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:9–2:16  ?g1 ⟶ ?g2
                  #11 surface `intro _`  2:9–2:16  ?g1 ⟶ ?g2   [intro [a✝]]
                    #12 inner `intro _`  2:9–2:16  ?g1 ⟶ ?g2
              #13 inner `intro _`  2:9–2:16  ?g2 ⟶ ?g2
                #14 inner `intro _`  2:9–2:16  ?g2 ⟶ ?g2
                  #15 inner `intro _`  2:9–2:16  ?g2 ⟶ ?g2
                    #16 inner `intro _`  2:9–2:16  ?g2 ⟶ ?g2
            #17 surface `exact ‹x ∈ A ∩ B›.1`  3:2–3:21  ?g2 ⟶ ?g2   [unrecognized]
              #18 inner `by  assumption`  synthetic 3:8–3:19  ?g3 ⟶ ?g3
                #19 inner `by`  synthetic 3:8–3:19  ?g3 ⟶ ?g3
                  #20 inner `assumption`  synthetic 3:8–3:19  ?g3 ⟶ ?g3
                    #21 inner `assumption`  synthetic 3:8–3:19  ?g3 ⟶ ?g3
                      #22 inner `assumption`  synthetic 3:8–3:19  ?g3 ⟶ ?g3
  goals
    ?g0 ⊢ A ∩ B ⊆ A   ctx [α, A, B]
        assigned by #8: fun x => ?g1 x
    ?g1 ⊢ x✝ ∈ A ∩ B → x✝ ∈ A   ctx [α, A, B, x✝]   parent ?g0
        assigned by #12: fun a => ?g2 a
    ?g2 ⊢ x✝ ∈ A   ctx [α, A, B, x✝, a✝]   parent ?g1
        unassigned
    ?g3 ⊢ sorry ∈ A ∩ B   ctx [α, A, B, x✝, a✝]   parent ?g2
        assigned by #17: sorry
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
    x✝ : α
    a✝ : x✝ ∈ A ∩ B
  proof term: incomplete (a goal is unassigned)
-/
#guard_msgs in
#proof_ir
theorem failed_tactic_goal (A B : Set α) : A ∩ B ⊆ A := by
  repeat intro _
  exact ‹x ∈ A ∩ B›.1

/-! `induction` reuses names for new variables, which do not replace the old ones. -/
/--
info: ProofIR induction_names
  statement
    binders     [n]
    conclusion  0 + n = n
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:49–4:38  ?g0 ⟶ —
      #1 structural [by]  1:49–1:51  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–4:38  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–4:38  ?g0 ⟶ —
            #4 surface `induction n with`  2:2–4:38  ?g0 ⟶ —   [unrecognized]
              #5 inner `induction n with`  2:2–2:18  ?g0 ⟶ —
                #6 inner `| zero =>`  3:2–3:11  ?g1 ⟶ —
                  #7 structural [Lean.Parser.Tactic.tacticSeq]  3:12–3:15  ?g1 ⟶ —
                    #8 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:12–3:15  ?g1 ⟶ —
                      #9 surface `rfl`  3:12–3:15  ?g1 ⟶ —   [unrecognized]
                        #10 inner `eq_refl`  synthetic 3:12–3:15  ?g1 ⟶ —
                #11 inner `| succ n ih =>`  4:2–4:16  ?g2 ⟶ —
                  #12 structural [Lean.Parser.Tactic.tacticSeq]  4:17–4:38  ?g2 ⟶ —
                    #13 structural [Lean.Parser.Tactic.tacticSeq1Indented]  4:17–4:38  ?g2 ⟶ —
                      #14 surface `rw [Nat.add_succ, ih]`  4:17–4:38  ?g2 ⟶ —   [unrecognized]
                        #15 inner `(  rewrite  [ Nat.add_succ, ih ]  ;  wi…`  synthetic 4:17–4:38  ?g2 ⟶ —
                          #16 inner `rewrite  [ Nat.add_succ, ih ]  ;  with_…`  synthetic 4:17–4:38  ?g2 ⟶ —
                            #17 inner `rewrite  [ Nat.add_succ, ih ]  ;  with_…`  synthetic 4:17–4:38  ?g2 ⟶ —
                              #18 inner `rewrite  [ Nat.add_succ, ih ]`  synthetic 4:17–4:38  ?g2 ⟶ ?g4
                                #19 inner `rewrite  [`  synthetic 4:17–4:38  ?g2 ⟶ ?g2
                                #20 inner `Nat.add_succ,`  4:21–4:34  ?g2 ⟶ ?g3
                                #21 inner `ih`  4:35–4:37  ?g3 ⟶ ?g4
                              #22 inner `;`  synthetic 4:17–4:38  ?g4 ⟶ ?g4
                              #23 inner `with_annotate_state ]`  synthetic 4:17–4:38  ?g4 ⟶ —
                                #24 inner `]`  4:37–4:38  ?g4 ⟶ —
                                  #25 inner `(  try  (  with_reducible  rfl  )  )`  synthetic 4:17–4:38  ?g4 ⟶ —
                                    #26 inner `try  (  with_reducible  rfl  )`  synthetic 4:17–4:38  ?g4 ⟶ —
                                      #27 inner `try  (  with_reducible  rfl  )`  synthetic 4:17–4:38  ?g4 ⟶ —
                                        #28 inner `try  (  with_reducible  rfl  )`  synthetic 4:17–4:38  ?g4 ⟶ —
                                          #29 inner `first  |  (  with_reducible  rfl  )  | …`  synthetic 4:17–4:38  ?g4 ⟶ —
                                            #30 inner `(  with_reducible  rfl  )`  synthetic 4:17–4:38  ?g4 ⟶ —
                                              #31 inner `(  with_reducible  rfl  )`  synthetic 4:17–4:38  ?g4 ⟶ —
                                                #32 inner `(  with_reducible  rfl  )`  synthetic 4:17–4:38  ?g4 ⟶ —
                                                  #33 inner `with_reducible  rfl`  synthetic 4:17–4:38  ?g4 ⟶ —
                                                    #34 inner `with_reducible  rfl`  synthetic 4:17–4:38  ?g4 ⟶ —
                                                      #35 inner `with_reducible  rfl`  synthetic 4:17–4:38  ?g4 ⟶ —
                                                        #36 inner `rfl`  synthetic 4:17–4:38  ?g4 ⟶ —
                                                          #37 inner `rfl`  synthetic 4:17–4:38  ?g4 ⟶ —
                                                            #38 inner `rfl`  synthetic 4:17–4:38  ?g4 ⟶ —
                                                              #39 inner `eq_refl`  synthetic 4:17–4:38  ?g4 ⟶ —
  goals
    ?g0 ⊢ 0 + n = n   ctx [n]
        assigned by #5: Nat.recAux ?g1 (fun n ih => ?g2 n ih) n
    ?g1 (zero) ⊢ 0 + 0 = 0   ctx []   parent ?g0
        assigned by #10: Eq.refl (0 + 0)
    ?g2 (succ) ⊢ 0 + (n + 1) = n + 1   ctx [n, ih]   parent ?g0
        assigned by #20: Eq.mpr (id (congrArg (fun _a => _a = n + 1) (Nat.add_succ 0 n))) ?g3
    ?g3 (succ) ⊢ (0 + n).succ = n + 1   ctx [n, ih]   parent ?g2
        assigned by #21: Eq.mpr (id (congrArg (fun _a => _a.succ = n + 1) ih)) ?g4
    ?g4 (succ) ⊢ n.succ = n + 1   ctx [n, ih]   parent ?g3
        assigned by #39: Eq.refl n.succ
  hyps
    n : Nat
    n : Nat
    ih : 0 + n = n
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem induction_names (n : Nat) : 0 + n = n := by
  induction n with
  | zero => rfl
  | succ n ih => rw [Nat.add_succ, ih]
