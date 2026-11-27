import Distill.Informalizer.Extract.Frontend
import Distill.Levels.Demo

/-! Declaration bodies that are terms: one Proof IR per body, whose first node reads like a
top-level `exact`, or `refine` when `by` blocks fill in parts of it. -/

open Distill Distill.Levels.Demo

/-! A term with no tactics in it. -/
/--
info: ProofIR pure_term
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ B ∩ A
  nodes
    #0 surface `fun _ hx => ⟨hx.2, hx.1⟩`  1:51–1:75  ?g0 ⟶ —   [exact fun x hx => ⟨hx.right, hx.left⟩]
  goals
    ?g0 ⊢ A ∩ B ⊆ B ∩ A   ctx [α, A, B]
        assigned by #0: fun x hx => ⟨hx.right, hx.left⟩
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem pure_term (A B : Set α) : A ∩ B ⊆ B ∩ A := fun _ hx => ⟨hx.2, hx.1⟩

/-! The same theorem, with `by` blocks under binders and inside each other. -/
/--
info: ProofIR blocks_under_binders
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ B ∩ A
  nodes
    #0 surface `fun x hx => ⟨by exact hx.2, by exact (b…`  2:2–2:55  ?g0 ⟶ ?g1 ?g2   [refine fun x hx => ⟨?g1 x hx, ?g2 x hx⟩]
      #1 structural [Lean.Parser.Term.byTactic]  2:15–2:28  ?g1 ⟶ —
        #2 structural [by]  2:15–2:17  ?g1 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq]  2:18–2:28  ?g1 ⟶ —
            #4 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:18–2:28  ?g1 ⟶ —
              #5 surface `exact hx.2`  2:18–2:28  ?g1 ⟶ —   [exact hx.right]
      #6 structural [Lean.Parser.Term.byTactic]  2:30–2:54  ?g2 ⟶ —
        #7 structural [by]  2:30–2:32  ?g2 ⟶ —
          #8 structural [Lean.Parser.Tactic.tacticSeq]  2:33–2:54  ?g2 ⟶ —
            #9 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:33–2:54  ?g2 ⟶ —
              #10 surface `exact (by exact hx.1)`  2:33–2:54  ?g2 ⟶ —   [exact ?g3]
                #11 structural [Lean.Parser.Term.byTactic]  2:40–2:53  ?g3 ⟶ —
                  #12 structural [by]  2:40–2:42  ?g3 ⟶ —
                    #13 structural [Lean.Parser.Tactic.tacticSeq]  2:43–2:53  ?g3 ⟶ —
                      #14 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:43–2:53  ?g3 ⟶ —
                        #15 surface `exact hx.1`  2:43–2:53  ?g3 ⟶ —   [exact hx.left]
  goals
    ?g0 ⊢ A ∩ B ⊆ B ∩ A   ctx [α, A, B]
        assigned by #0: fun x hx => ⟨?g1 x hx, ?g2 x hx⟩
    ?g1 ⊢ x ∈ B   ctx [α, A, B, x, hx]   parent ?g0
        assigned by #5: hx.right
    ?g2 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g0
        assigned by #10: ?g3
    ?g3 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g2
        assigned by #15: hx.left
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
theorem blocks_under_binders (A B : Set α) : A ∩ B ⊆ B ∩ A :=
  fun x hx => ⟨by exact hx.2, by exact (by exact hx.1)⟩

/-! `have` and `show` in a term, which elaborate through macros. -/
/--
info: ProofIR have_in_term
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ B
  nodes
    #0 surface `fun x hx =>`  1:50–3:19  ?g0 ⟶ ?g1   [refine fun x hx => have h := ?g1 x hx; have this := h; this]
      #1 structural [Lean.Parser.Term.byTactic]  2:20–2:33  ?g1 ⟶ —
        #2 structural [by]  2:20–2:22  ?g1 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq]  2:23–2:33  ?g1 ⟶ —
            #4 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:23–2:33  ?g1 ⟶ —
              #5 surface `exact hx.2`  2:23–2:33  ?g1 ⟶ —   [exact hx.right]
  goals
    ?g0 ⊢ A ∩ B ⊆ B   ctx [α, A, B]
        assigned by #0: fun x hx => have h := ?g1 x hx; have this := h; this
    ?g1 ⊢ x ∈ B   ctx [α, A, B, x, hx]   parent ?g0
        assigned by #5: hx.right
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
theorem have_in_term (A B : Set α) : A ∩ B ⊆ B := fun x hx =>
  have h : x ∈ B := by exact hx.2
  show x ∈ B from h

/-! A `by` block in a `match` alternative. -/
/--
info: ProofIR match_term
  statement
    binders     [p, q, h]
    conclusion  q ∧ p
  nodes
    #0 surface `match h with`  2:2–3:33  ?g0 ⟶ ?g1   [refine match h with | ⟨hp, hq⟩ => ⟨?g1 hp hq, hp⟩]
      #1 structural [Lean.Parser.Term.byTactic]  3:17–3:28  ?g1 ⟶ —
        #2 structural [by]  3:17–3:19  ?g1 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq]  3:20–3:28  ?g1 ⟶ —
            #4 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:20–3:28  ?g1 ⟶ —
              #5 surface `exact hq`  3:20–3:28  ?g1 ⟶ —   [exact hq]
  goals
    ?g0 ⊢ q ∧ p   ctx [p, q, h]
        assigned by #0: match h with | ⟨hp, hq⟩ => ⟨?g1 hp hq, hp⟩
    ?g1 ⊢ q   ctx [p, q, h, hp, hq]   parent ?g0
        assigned by #5: hq
  hyps
    p : Prop
    q : Prop
    h : p ∧ q
    hp : p
    hq : q
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem match_term (p q : Prop) (h : p ∧ q) : q ∧ p :=
  match h with
  | ⟨hp, hq⟩ => ⟨by exact hq, hp⟩

/-! A definition by equations. -/
/--
info: ProofIR by_equations
  statement
    binders     []
    conclusion  ∀ (p q : Prop), p ∧ q → p
  nodes
    #0 surface `@  fun  x  =>  @  fun  x  =>  @  fun  x…`  synthetic 2:2–2:32  ?g0 ⟶ ?g1   [refine fun x x_1 x_2 => match x, x_1, x_2 with | a, b, ⟨hp, right⟩ => ?g1 a b hp right]
      #1 structural [Lean.Parser.Term.byTactic]  2:21–2:32  ?g1 ⟶ —
        #2 structural [by]  2:21–2:23  ?g1 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq]  2:24–2:32  ?g1 ⟶ —
            #4 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:24–2:32  ?g1 ⟶ —
              #5 surface `exact hp`  2:24–2:32  ?g1 ⟶ —   [exact hp]
  goals
    ?g0 ⊢ ∀ (p q : Prop), p ∧ q → p   ctx []
        assigned by #0: fun x x_1 x_2 => match x, x_1, x_2 with | a, b, ⟨hp, right⟩ => ?g1 a b hp right
    ?g1 ⊢ a✝   ctx [a✝, b✝, hp, right✝]   parent ?g0
        assigned by #5: hp
  hyps
    a✝ : Prop
    b✝ : Prop
    hp : a✝
    right✝ : b✝
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem by_equations : (p q : Prop) → p ∧ q → p
  | _, _, ⟨hp, _⟩ => by exact hp

/-! A `by` block around the whole body. -/
/--
info: ProofIR parenthesized
  statement
    binders     [p, h]
    conclusion  p
  nodes
    #0 surface `(by exact h)`  1:48–1:60  ?g0 ⟶ ?g1   [refine ?g1]
      #1 structural [Lean.Parser.Term.byTactic]  1:49–1:59  ?g1 ⟶ —
        #2 structural [by]  1:49–1:51  ?g1 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq]  1:52–1:59  ?g1 ⟶ —
            #4 structural [Lean.Parser.Tactic.tacticSeq1Indented]  1:52–1:59  ?g1 ⟶ —
              #5 surface `exact h`  1:52–1:59  ?g1 ⟶ —   [exact h]
  goals
    ?g0 ⊢ p   ctx [p, h]
        assigned by #0: ?g1
    ?g1 ⊢ p   ctx [p, h]   parent ?g0
        assigned by #5: h
  hyps
    p : Prop
    h : p
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem parenthesized (p : Prop) (h : p) : p := (by exact h)

/-! A `where` clause proves its own statement, and an instance of a `Prop` class is a proof. -/
/--
info: ProofIR where_term.aux
  statement
    binders     [p, h]
    conclusion  p
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  2:17–2:27  ?g0 ⟶ —
      #1 structural [by]  2:17–2:19  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:20–2:27  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:20–2:27  ?g0 ⟶ —
            #4 surface `exact h`  2:20–2:27  ?g0 ⟶ —   [exact h]
  goals
    ?g0 ⊢ p   ctx [p, h]
        assigned by #4: h
  hyps
    p : Prop
    h : p
  proof term: rebuilds the declaration's proof term
---
info: ProofIR where_term
  statement
    binders     [p, h]
    conclusion  p ∧ p
  nodes
    #0 surface `let  rec aux : p := by exact h`  synthetic 1:46–2:27  ?g0 ⟶ ?g1   [refine (fun aux => ⟨aux, ?g1⟩) (where_term.aux p h)]
      #1 structural [Lean.Parser.Term.byTactic]  1:55–1:65  ?g1 ⟶ —
        #2 structural [by]  1:55–1:57  ?g1 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq]  1:58–1:65  ?g1 ⟶ —
            #4 structural [Lean.Parser.Tactic.tacticSeq1Indented]  1:58–1:65  ?g1 ⟶ —
              #5 surface `exact h`  1:58–1:65  ?g1 ⟶ —   [exact h]
  goals
    ?g0 ⊢ p ∧ p   ctx [p, h]
        assigned by #0: (fun aux => ⟨aux, ?g1⟩) (where_term.aux p h)
    ?g1 ⊢ p   ctx [p, h]   parent ?g0
        assigned by #5: h
  hyps
    p : Prop
    h : p
  proof term: definitionally equal to the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem where_term (p : Prop) (h : p) : p ∧ p := ⟨aux, by exact h⟩
where aux : p := by exact h

/--
info: ProofIR prop_instance
  statement
    binders     []
    conclusion  Nonempty Nat
  nodes
    #0 surface `⟨by exact 0⟩`  1:41–1:53  ?g0 ⟶ ?g1   [refine Nonempty.intro ?g1]
      #1 structural [Lean.Parser.Term.byTactic]  1:42–1:52  ?g1 ⟶ —
        #2 structural [by]  1:42–1:44  ?g1 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq]  1:45–1:52  ?g1 ⟶ —
            #4 structural [Lean.Parser.Tactic.tacticSeq1Indented]  1:45–1:52  ?g1 ⟶ —
              #5 surface `exact 0`  1:45–1:52  ?g1 ⟶ —   [exact 0]
  goals
    ?g0 ⊢ Nonempty Nat   ctx []
        assigned by #0: Nonempty.intro ?g1
    ?g1 ⊢ Nat   ctx []   parent ?g0
        assigned by #5: 0
  hyps
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
instance prop_instance : Nonempty Nat := ⟨by exact 0⟩

/-! A definition is not a proof: `by` blocks in it are proofs on their own. -/
/--
info: ProofIR data_with_proof   (a `by` block inside it)
  statement
    binders     []
    conclusion  0 = 0
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:50–1:56  ?g0 ⟶ —
      #1 structural [by]  1:50–1:52  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  1:53–1:56  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  1:53–1:56  ?g0 ⟶ —
            #4 surface `rfl`  1:53–1:56  ?g0 ⟶ —   [unrecognized]
              #5 inner `eq_refl`  synthetic 1:53–1:56  ?g0 ⟶ —
  goals
    ?g0 ⊢ 0 = 0   ctx []
        assigned by #5: Eq.refl 0
  hyps
  proof term: not compared (the `by` block is not the declaration's body)
-/
#guard_msgs in
#proof_ir
def data_with_proof : { n : Nat // n = 0 } := ⟨0, by rfl⟩

/--
info: no proofs
-/
#guard_msgs in
#proof_ir
def plain_data : Nat := 5

/-! An auto-param `by` in a signature is syntax until it is used. The body is a proof. -/
/--
info: ProofIR in_signature
  statement
    binders     [n, h]
    conclusion  n = n
  nodes
    #0 surface `h`  1:64–1:65  ?g0 ⟶ —   [exact h]
  goals
    ?g0 ⊢ n = n   ctx [n, h]
        assigned by #0: h
  hyps
    n : Nat
    h : n = n
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem in_signature (n : Nat) (h : n = n := by rfl) : n = n := h

/-! A recursive call in a term or a `by` block refers to the declaration being defined. -/
/--
info: ProofIR recursive_term
  statement
    binders     []
    conclusion  ∀ (n : Nat), 0 ≤ n
  nodes
    #0 surface `@  fun  x  =>  match  @  x  with | 0 =>…`  synthetic 2:2–3:49  ?g0 ⟶ —   [exact fun x => match x with | 0 => Nat.le_refl 0 | n.succ => Nat.le_succ_of_le (recursive_term n)]
  goals
    ?g0 ⊢ ∀ (n : Nat), 0 ≤ n   ctx []
        assigned by #0: fun x => match x with | 0 => Nat.le_refl 0 | n.succ => Nat.le_succ_of_le (recursive_term n)
  hyps
    recursive_term : ∀ (n : Nat), 0 ≤ n   [recursive]
  proof term: type-checks (not compared: the proof is recursive)
-/
#guard_msgs in
#proof_ir
theorem recursive_term : (n : Nat) → 0 ≤ n
  | 0 => Nat.le_refl 0
  | n + 1 => Nat.le_succ_of_le (recursive_term n)

/--
info: ProofIR recursive_block
  statement
    binders     []
    conclusion  ∀ (n : Nat), 0 ≤ n
  nodes
    #0 surface `@  fun  x  =>  match  @  x  with | 0 =>…`  synthetic 2:2–3:59  ?g0 ⟶ ?g1 ?g2   [refine fun x => match x with | 0 => ?g1 | n.succ => ?g2 n]
      #1 structural [Lean.Parser.Term.byTactic]  2:9–2:31  ?g1 ⟶ —
        #2 structural [by]  2:9–2:11  ?g1 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq]  2:12–2:31  ?g1 ⟶ —
            #4 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:12–2:31  ?g1 ⟶ —
              #5 surface `exact Nat.le_refl 0`  2:12–2:31  ?g1 ⟶ —   [exact Nat.le_refl 0]
      #6 structural [Lean.Parser.Term.byTactic]  3:13–3:59  ?g2 ⟶ —
        #7 structural [by]  3:13–3:15  ?g2 ⟶ —
          #8 structural [Lean.Parser.Tactic.tacticSeq]  3:16–3:59  ?g2 ⟶ —
            #9 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:16–3:59  ?g2 ⟶ —
              #10 surface `exact Nat.le_succ_of_le (recursive_bloc…`  3:16–3:59  ?g2 ⟶ —   [exact Nat.le_succ_of_le (recursive_block n)]
  goals
    ?g0 ⊢ ∀ (n : Nat), 0 ≤ n   ctx []
        assigned by #0: fun x => match x with | 0 => ?g1 | n.succ => ?g2 n
    ?g1 ⊢ 0 ≤ 0   ctx []   parent ?g0
        assigned by #5: Nat.le_refl 0
    ?g2 ⊢ 0 ≤ n + 1   ctx [n]   parent ?g0
        assigned by #10: Nat.le_succ_of_le (recursive_block n)
  hyps
    n : Nat
    recursive_block : ∀ (n : Nat), 0 ≤ n   [recursive]
  proof term: type-checks (not compared: the proof is recursive)
-/
#guard_msgs in
#proof_ir
theorem recursive_block : (n : Nat) → 0 ≤ n
  | 0 => by exact Nat.le_refl 0
  | n + 1 => by exact Nat.le_succ_of_le (recursive_block n)

/-! A `where` helper whose type mentions the statement's variables. -/
/--
info: ProofIR where_from_block.aux
  statement
    binders     [p, hp]
    conclusion  p
  nodes
    #0 surface `hp`  3:17–3:19  ?g0 ⟶ —   [exact hp]
  goals
    ?g0 ⊢ p   ctx [p, hp]
        assigned by #0: hp
  hyps
    p : Prop
    hp : p
  proof term: rebuilds the declaration's proof term
---
info: ProofIR where_from_block
  statement
    binders     [p, hp]
    conclusion  p ∧ p
  nodes
    #0 surface `let  rec aux : p := hp`  synthetic 1:53–3:19  ?g0 ⟶ ?g1   [refine (fun aux => ?g1) (where_from_block.aux p hp)]
      #1 structural [Lean.Parser.Term.byTactic]  1:56–2:18  ?g1 ⟶ —
        #2 structural [by]  1:56–1:58  ?g1 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq]  2:2–2:18  ?g1 ⟶ —
            #4 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–2:18  ?g1 ⟶ —
              #5 surface `exact ⟨aux, aux⟩`  2:2–2:18  ?g1 ⟶ —   [exact ⟨aux, aux⟩]
  goals
    ?g0 ⊢ p ∧ p   ctx [p, hp]
        assigned by #0: (fun aux => ?g1) (where_from_block.aux p hp)
    ?g1 ⊢ p ∧ p   ctx [p, hp]   parent ?g0
        assigned by #5: ⟨aux, aux⟩
  hyps
    p : Prop
    hp : p
    aux : p   [recursive]
  proof term: type-checks (not compared: the proof is recursive)
-/
#guard_msgs in
#proof_ir
theorem where_from_block (p : Prop) (hp : p) : p ∧ p := by
  exact ⟨aux, aux⟩
where aux : p := hp

/-! Unfinished terms. -/
/--
warning: declaration uses `sorry`
---
info: ProofIR term_with_sorry
  statement
    binders     [p, q, h]
    conclusion  p ∧ q
  nodes
    #0 surface `⟨by exact h, sorry⟩`  1:56–1:75  ?g0 ⟶ ?g1   [refine ⟨?g1, sorry⟩]
      #1 structural [Lean.Parser.Term.byTactic]  1:57–1:67  ?g1 ⟶ —
        #2 structural [by]  1:57–1:59  ?g1 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq]  1:60–1:67  ?g1 ⟶ —
            #4 structural [Lean.Parser.Tactic.tacticSeq1Indented]  1:60–1:67  ?g1 ⟶ —
              #5 surface `exact h`  1:60–1:67  ?g1 ⟶ —   [exact h]
  goals
    ?g0 ⊢ p ∧ q   ctx [p, q, h]
        assigned by #0: ⟨?g1, sorry⟩
    ?g1 ⊢ p   ctx [p, q, h]   parent ?g0
        assigned by #5: h
  hyps
    p : Prop
    q : Prop
    h : p
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem term_with_sorry (p q : Prop) (h : p) : p ∧ q := ⟨by exact h, sorry⟩

/--
error: Type mismatch
  h
has type
  p
but is expected to have type
  q
---
info: ProofIR term_with_failing_block
  statement
    binders     [p, q, h]
    conclusion  p ∧ q
  nodes
    #0 surface `⟨by exact h, by exact h⟩`  1:64–1:88  ?g0 ⟶ ?g1 ?g2   [refine ⟨?g1, ?g2⟩]
      #1 structural [Lean.Parser.Term.byTactic]  1:65–1:75  ?g1 ⟶ —
        #2 structural [by]  1:65–1:67  ?g1 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq]  1:68–1:75  ?g1 ⟶ —
            #4 structural [Lean.Parser.Tactic.tacticSeq1Indented]  1:68–1:75  ?g1 ⟶ —
              #5 surface `exact h`  1:68–1:75  ?g1 ⟶ —   [exact h]
      #6 structural [Lean.Parser.Term.byTactic]  1:77–1:87  ?g2 ⟶ ?g2
        #7 inner `by`  1:77–1:79  ?g2 ⟶ ?g2
          #8 inner `exact h`  1:80–1:87  ?g2 ⟶ ?g2
            #9 inner `exact h`  1:80–1:87  ?g2 ⟶ ?g2
              #10 inner `exact h`  1:80–1:87  ?g2 ⟶ ?g2
  goals
    ?g0 ⊢ p ∧ q   ctx [p, q, h]
        assigned by #0: ⟨?g1, ?g2⟩
    ?g1 ⊢ p   ctx [p, q, h]   parent ?g0
        assigned by #5: h
    ?g2 ⊢ q   ctx [p, q, h]   parent ?g0
        unassigned
  hyps
    p : Prop
    q : Prop
    h : p
  proof term: incomplete (a goal is unassigned)
-/
#guard_msgs in
#proof_ir
theorem term_with_failing_block (p q : Prop) (h : p) : p ∧ q := ⟨by exact h, by exact h⟩

/--
error: don't know how to synthesize placeholder
context:
p : Prop
hp : p
⊢ p
---
info: ProofIR term_with_hole
  statement
    binders     [p, hp]
    conclusion  p
  nodes
    #0 surface `_`  1:50–1:51  ?g0 ⟶ —   [exact @?_mvar.1739 p hp]
  goals
    ?g0 ⊢ p   ctx [p, hp]
        assigned by #0: @?_mvar.1739 p hp
  hyps
    p : Prop
    hp : p
  proof term: incomplete (a hole is unfilled)
-/
#guard_msgs in
#proof_ir
theorem term_with_hole (p : Prop) (hp : p) : p := _
