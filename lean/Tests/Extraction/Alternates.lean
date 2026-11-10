import Distill.Informalizer.Extract.Frontend
import Distill.Levels.Demo

/-! Other sensible proofs of the demo levels, using the same tactics. -/

open Distill Distill.Levels.Demo

/-! Level 1, with the whole proof as a term. -/
/--
info: ProofIR subset_rfl'
  statement
    binders     [α, A]
    conclusion  A ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:43–2:22  ?g0 ⟶ —
      #1 structural [by]  1:43–1:45  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–2:22  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–2:22  ?g0 ⟶ —
            #4 surface `exact fun x hx => hx`  2:2–2:22  ?g0 ⟶ —   [exact fun x hx => hx]
  goals
    ?g0 ⊢ A ⊆ A   ctx [α, A]
        assigned by #4: fun x hx => hx
  hyps
    α : Type u_1   {implicit}
    A : Set α
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem subset_rfl' (A : Set α) : A ⊆ A := by
  exact fun x hx => hx

/-! Level 2, introducing one name at a time and projecting with `.1`. -/
/--
info: ProofIR inter_subset_left'
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:56–4:12  ?g0 ⟶ —
      #1 structural [by]  1:56–1:58  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–4:12  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–4:12  ?g0 ⟶ —
            #4 surface `intro x`  2:2–2:9  ?g0 ⟶ ?g1   [intro [x]]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
            #6 surface `intro hx`  3:2–3:10  ?g1 ⟶ ?g2   [intro [hx]]
              #7 inner `intro hx`  3:2–3:10  ?g1 ⟶ ?g2
            #8 surface `exact hx.1`  4:2–4:12  ?g2 ⟶ —   [exact hx.left]
  goals
    ?g0 ⊢ A ∩ B ⊆ A   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ A   ctx [α, A, B, x]   parent ?g0
        assigned by #7: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g1
        assigned by #8: hx.left
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
theorem inter_subset_left' (A B : Set α) : A ∩ B ⊆ A := by
  intro x
  intro hx
  exact hx.1

/-! Level 4, without the `have`s. -/
/--
info: ProofIR subset_inter'
  statement
    binders     [α, A, B, C, hCA, hCB]
    conclusion  C ⊆ A ∩ B
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:81–3:28  ?g0 ⟶ —
      #1 structural [by]  1:81–1:83  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–3:28  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–3:28  ?g0 ⟶ —
            #4 surface `intro x hx`  2:2–2:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  2:2–2:9  ?g0 ⟶ ?g1
              #6 inner `hx`  2:10–2:12  ?g1 ⟶ ?g2
            #7 surface `exact ⟨hCA x hx, hCB x hx⟩`  3:2–3:28  ?g2 ⟶ —   [exact ⟨hCA x hx, hCB x hx⟩]
  goals
    ?g0 ⊢ C ⊆ A ∩ B   ctx [α, A, B, C, hCA, hCB]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ C → x ∈ A ∩ B   ctx [α, A, B, C, hCA, hCB, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A ∩ B   ctx [α, A, B, C, hCA, hCB, x, hx]   parent ?g1
        assigned by #7: ⟨hCA x hx, hCB x hx⟩
  hyps
    α : Type u_1   {implicit}
    A : Set α   {implicit}
    B : Set α   {implicit}
    C : Set α   {implicit}
    hCA : C ⊆ A
    hCB : C ⊆ B
    x : α
    hx : x ∈ C
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem subset_inter' {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B := by
  intro x hx
  exact ⟨hCA x hx, hCB x hx⟩

/-! Level 5 with the earlier levels given as one term, which leaves the implicit arguments of
`subset_inter` to unification; shown explicitly. -/
set_option pp.explicit true in
/--
info: ProofIR inter_subset_inter_comm'
  statement
    binders     [α, A, B]
    conclusion  @Subset (Set α) (@instHasSubsetSet α) (@Inter.inter (Set α) (@instInterSet α) A B) (@Inter.inter (Set α) (@instInterSet α) B A)
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:66–2:69  ?g0 ⟶ —
      #1 structural [by]  1:66–1:68  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–2:69  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–2:69  ?g0 ⟶ —
            #4 surface `exact subset_inter (inter_subset_right …`  2:2–2:69  ?g0 ⟶ —   [exact @subset_inter α B A (@Inter.inter (Set α) (@instInterSet α) A B) (@inter_subset_right α A B) (@inter_subset_left α A B)]
  goals
    ?g0 ⊢ @Subset (Set α) (@instHasSubsetSet α) (@Inter.inter (Set α) (@instInterSet α) A B) (@Inter.inter (Set α) (@instInterSet α) B A)   ctx [α, A, B]
        assigned by #4: @subset_inter α B A (@Inter.inter (Set α) (@instInterSet α) A B) (@inter_subset_right α A B) (@inter_subset_left α A B)
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem inter_subset_inter_comm' (A B : Set α) : A ∩ B ⊆ B ∩ A := by
  exact subset_inter (inter_subset_right A B) (inter_subset_left A B)

/-! Level 5 elementwise, with a `have` proved by a nested tactic block. -/
/--
info: ProofIR inter_subset_inter_comm''
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ B ∩ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:67–5:46  ?g0 ⟶ —
      #1 structural [by]  1:67–1:69  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–5:46  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–5:46  ?g0 ⟶ —
            #4 surface `have h : A ∩ B ⊆ B := by`  2:2–4:14  ?g0 ⟶ ?g2   [have h : A ∩ B ⊆ B := by ?g1]
              #5 inner `focus  refine  no_implicit_lambda%  (  …`  synthetic 2:2–2:6  ?g0 ⟶ ?g2
                #6 inner `focus`  synthetic 2:2–2:6  ?g0 ⟶ ?g0
                #7 inner `refine  no_implicit_lambda%  (  [anonym…`  synthetic 2:2–2:6  ?g0 ⟶ ?g2
                  #8 inner `refine  no_implicit_lambda%  (  [anonym…`  synthetic 2:2–2:6  ?g0 ⟶ ?g2
                    #9 inner `refine  no_implicit_lambda%  (  [anonym…`  synthetic 2:2–2:6  ?g0 ⟶ ?g1 ?g2   [refine have h := ?g1; ?g2 h]
                    #10 inner ``  synthetic 2:2–2:6  ?g1 ?g2 ⟶ ?g1 ?g2
                    #11 inner `case  body  =>  with_annotate_state by`  synthetic 2:24–2:26  ?g1 ?g2 ⟶ ?g2
                      #12 inner `case  =>`  synthetic 2:24–2:26  ?g1 ⟶ —
                        #13 inner `with_annotate_state by`  synthetic 2:2–4:14  ?g1 ⟶ —
                          #14 inner `with_annotate_state by`  synthetic 2:2–4:14  ?g1 ⟶ —
                            #15 inner `with_annotate_state by`  synthetic 2:24–2:26  ?g1 ⟶ —
                              #16 structural [by]  2:24–2:26  ?g1 ⟶ —
                                #17 inner `( intro x hx`  synthetic 2:24–2:26  ?g1 ⟶ —
                                  #18 inner `intro x hx`  synthetic 2:24–2:26  ?g1 ⟶ —
                                    #19 inner `intro x hx`  synthetic 2:24–2:26  ?g1 ⟶ —
                                      #20 surface `intro x hx`  3:4–3:14  ?g1 ⟶ ?g4   [intro [x, hx]]
                                        #21 inner `intro x`  3:4–3:11  ?g1 ⟶ ?g3
                                        #22 inner `hx`  3:12–3:14  ?g3 ⟶ ?g4
                                      #23 surface `exact hx.2`  4:4–4:14  ?g4 ⟶ —   [exact hx.right]
            #24 surface `exact subset_inter h (inter_subset_left…`  5:2–5:46  ?g2 ⟶ —   [exact subset_inter h (inter_subset_left A B)]
  goals
    ?g0 ⊢ A ∩ B ⊆ B ∩ A   ctx [α, A, B]
        assigned by #9: have h := ?g1; ?g2 h
    ?g1 ⊢ A ∩ B ⊆ B   ctx [α, A, B]   parent ?g0
        assigned by #21: fun x => ?g3 x
    ?g2 ⊢ A ∩ B ⊆ B ∩ A   ctx [α, A, B, h]   parent ?g0
        assigned by #24: subset_inter h (inter_subset_left A B)
    ?g3 ⊢ x ∈ A ∩ B → x ∈ B   ctx [α, A, B, x]   parent ?g1
        assigned by #22: fun hx => ?g4 hx
    ?g4 ⊢ x ∈ B   ctx [α, A, B, x, hx]   parent ?g3
        assigned by #23: hx.right
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
    h : A ∩ B ⊆ B
    x : α
    hx : x ∈ A ∩ B
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem inter_subset_inter_comm'' (A B : Set α) : A ∩ B ⊆ B ∩ A := by
  have h : A ∩ B ⊆ B := by
    intro x hx
    exact hx.2
  exact subset_inter h (inter_subset_left A B)

/-! Level 6 with bullets, proving both inclusions in place. -/
/--
info: ProofIR inter_comm'
  statement
    binders     [α, A, B]
    conclusion  A ∩ B = B ∩ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:53–7:27  ?g0 ⟶ —
      #1 structural [by]  1:53–1:55  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–7:27  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–7:27  ?g0 ⟶ —
            #4 surface `ext`  2:2–2:5  ?g0 ⟶ ?g1 ?g2   [apply Set.ext ?g1 ?g2]
            #5 structural [Lean.cdot]  3:2–4:22  ?g1 ?g2 ⟶ ?g2
              #6 structural [Lean.cdotTk]  3:2–3:3  ?g1 ?g2 ⟶ ?g1
              #7 structural [Lean.Parser.Tactic.tacticSeq]  3:4–4:22  ?g1 ⟶ —
                #8 structural [Lean.Parser.Tactic.tacticSeq1Indented]  3:4–4:22  ?g1 ⟶ —
                  #9 surface `intro x hx`  3:4–3:14  ?g1 ⟶ ?g4   [intro [x, hx]]
                    #10 inner `intro x`  3:4–3:11  ?g1 ⟶ ?g3
                    #11 inner `hx`  3:12–3:14  ?g3 ⟶ ?g4
                  #12 surface `exact ⟨hx.2, hx.1⟩`  4:4–4:22  ?g4 ⟶ —   [exact ⟨hx.right, hx.left⟩]
            #13 structural [Lean.cdot]  5:2–7:27  ?g2 ⟶ —
              #14 structural [Lean.cdotTk]  5:2–5:3  ?g2 ⟶ ?g2
              #15 structural [Lean.Parser.Tactic.tacticSeq]  5:4–7:27  ?g2 ⟶ —
                #16 structural [Lean.Parser.Tactic.tacticSeq1Indented]  5:4–7:27  ?g2 ⟶ —
                  #17 surface `intro x hx`  5:4–5:14  ?g2 ⟶ ?g6   [intro [x, hx]]
                    #18 inner `intro x`  5:4–5:11  ?g2 ⟶ ?g5
                    #19 inner `hx`  5:12–5:14  ?g5 ⟶ ?g6
                  #20 surface `have h : x ∈ B ∧ x ∈ A := hx`  6:4–6:32  ?g6 ⟶ ?g7   [have h : x ∈ B ∧ x ∈ A := hx]
                    #21 inner `refine_lift  have h : x ∈ B ∧ x ∈ A := …`  synthetic 6:4–6:32  ?g6 ⟶ ?g7
                      #22 inner `focus  (  refine  no_implicit_lambda%  …`  synthetic 6:4–6:32  ?g6 ⟶ ?g7
                        #23 inner `focus`  synthetic 6:4–6:32  ?g6 ⟶ ?g6
                        #24 inner `(  refine  no_implicit_lambda%  have h …`  synthetic 6:4–6:32  ?g6 ⟶ ?g7
                          #25 inner `(  refine  no_implicit_lambda%  have h …`  synthetic 6:4–6:32  ?g6 ⟶ ?g7
                            #26 inner `(  refine  no_implicit_lambda%  have h …`  synthetic 6:4–6:32  ?g6 ⟶ ?g7
                              #27 inner `refine  no_implicit_lambda%  have h : x…`  synthetic 6:4–6:32  ?g6 ⟶ ?g7
                                #28 inner `refine  no_implicit_lambda%  have h : x…`  synthetic 6:4–6:32  ?g6 ⟶ ?g7
                                  #29 inner `refine  no_implicit_lambda%  have h : x…`  synthetic 6:4–6:32  ?g6 ⟶ ?g7   [refine have h := hx; ?g7 h]
                                  #30 inner `;`  synthetic 6:4–6:32  ?g7 ⟶ ?g7
                                  #31 inner `rotate_right`  synthetic 6:4–6:32  ?g7 ⟶ ?g7
                  #32 surface `exact ⟨h.right, h.left⟩`  7:4–7:27  ?g7 ⟶ —   [exact ⟨h.right, h.left⟩]
  goals
    ?g0 ⊢ A ∩ B = B ∩ A   ctx [α, A, B]
        assigned by #4: Set.ext ?g1 ?g2
    ?g1 (h₁) ⊢ A ∩ B ⊆ B ∩ A   ctx [α, A, B]   parent ?g0
        assigned by #10: fun x => ?g3 x
    ?g2 (h₂) ⊢ B ∩ A ⊆ A ∩ B   ctx [α, A, B]   parent ?g0
        assigned by #18: fun x => ?g5 x
    ?g3 (h₁) ⊢ x ∈ A ∩ B → x ∈ B ∩ A   ctx [α, A, B, x]   parent ?g1
        assigned by #11: fun hx => ?g4 hx
    ?g4 (h₁) ⊢ x ∈ B ∩ A   ctx [α, A, B, x, hx]   parent ?g3
        assigned by #12: ⟨hx.right, hx.left⟩
    ?g5 (h₂) ⊢ x ∈ B ∩ A → x ∈ A ∩ B   ctx [α, A, B, x]   parent ?g2
        assigned by #19: fun hx => ?g6 hx
    ?g6 (h₂) ⊢ x ∈ A ∩ B   ctx [α, A, B, x, hx]   parent ?g5
        assigned by #29: have h := hx; ?g7 h
    ?g7 (h₂) ⊢ x ∈ A ∩ B   ctx [α, A, B, x, hx, h]   parent ?g6
        assigned by #32: ⟨h.right, h.left⟩
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
    x : α
    hx : x ∈ A ∩ B
    x : α
    hx : x ∈ B ∩ A
    h : x ∈ B ∧ x ∈ A
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem inter_comm' (A B : Set α) : A ∩ B = B ∩ A := by
  ext
  · intro x hx
    exact ⟨hx.2, hx.1⟩
  · intro x hx
    have h : x ∈ B ∧ x ∈ A := hx
    exact ⟨h.right, h.left⟩

/-! Level 6 without `ext`. -/
/--
info: ProofIR inter_comm''
  statement
    binders     [α, A, B]
    conclusion  A ∩ B = B ∩ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  1:54–2:75  ?g0 ⟶ —
      #1 structural [by]  1:54–1:56  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  2:2–2:75  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  2:2–2:75  ?g0 ⟶ —
            #4 surface `exact Set.ext (inter_subset_inter_comm …`  2:2–2:75  ?g0 ⟶ —   [exact Set.ext (inter_subset_inter_comm A B) (inter_subset_inter_comm B A)]
  goals
    ?g0 ⊢ A ∩ B = B ∩ A   ctx [α, A, B]
        assigned by #4: Set.ext (inter_subset_inter_comm A B) (inter_subset_inter_comm B A)
  hyps
    α : Type u_1   {implicit}
    A : Set α
    B : Set α
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem inter_comm'' (A B : Set α) : A ∩ B = B ∩ A := by
  exact Set.ext (inter_subset_inter_comm A B) (inter_subset_inter_comm B A)
