import Distill.Informalizer.Extract.Frontend

/-! The example proof of `docs/informalization/ir.md`. -/

/--
info: ProofIR intersection_subset
  statement
    binders     [α, A, B, C, hAB]
    conclusion  ∀ (x : α), A x ∧ C x → B x ∧ C x
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  4:38–7:19  ?g0 ⟶ —
      #1 structural [by]  4:38–4:40  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  5:2–7:19  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  5:2–7:19  ?g0 ⟶ —
            #4 surface `intro x hx`  5:2–5:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  5:2–5:9  ?g0 ⟶ ?g1
              #6 inner `hx`  5:10–5:12  ?g1 ⟶ ?g2
            #7 surface `have hBx : B x := hAB x hx.1`  6:2–6:30  ?g2 ⟶ ?g3   [have hBx : B x := hAB x hx.left]
              #8 inner `refine_lift  have hBx : B x := hAB x hx…`  synthetic 6:2–6:30  ?g2 ⟶ ?g3
                #9 inner `focus  (  refine  no_implicit_lambda%  …`  synthetic 6:2–6:30  ?g2 ⟶ ?g3
                  #10 inner `focus`  synthetic 6:2–6:30  ?g2 ⟶ ?g2
                  #11 inner `(  refine  no_implicit_lambda%  have hB…`  synthetic 6:2–6:30  ?g2 ⟶ ?g3
                    #12 inner `(  refine  no_implicit_lambda%  have hB…`  synthetic 6:2–6:30  ?g2 ⟶ ?g3
                      #13 inner `(  refine  no_implicit_lambda%  have hB…`  synthetic 6:2–6:30  ?g2 ⟶ ?g3
                        #14 inner `refine  no_implicit_lambda%  have hBx :…`  synthetic 6:2–6:30  ?g2 ⟶ ?g3
                          #15 inner `refine  no_implicit_lambda%  have hBx :…`  synthetic 6:2–6:30  ?g2 ⟶ ?g3
                            #16 inner `refine  no_implicit_lambda%  have hBx :…`  synthetic 6:2–6:30  ?g2 ⟶ ?g3   [refine have hBx := hAB x hx.left; ?g3 hBx]
                            #17 inner `;`  synthetic 6:2–6:30  ?g3 ⟶ ?g3
                            #18 inner `rotate_right`  synthetic 6:2–6:30  ?g3 ⟶ ?g3
            #19 surface `exact ⟨hBx, hx.2⟩`  7:2–7:19  ?g3 ⟶ —   [exact ⟨hBx, hx.right⟩]
  goals
    ?g0 ⊢ ∀ (x : α), A x ∧ C x → B x ∧ C x   ctx [α, A, B, C, hAB]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ A x ∧ C x → B x ∧ C x   ctx [α, A, B, C, hAB, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ B x ∧ C x   ctx [α, A, B, C, hAB, x, hx]   parent ?g1
        assigned by #16: have hBx := hAB x hx.left; ?g3 hBx
    ?g3 ⊢ B x ∧ C x   ctx [α, A, B, C, hAB, x, hx, hBx]   parent ?g2
        assigned by #19: ⟨hBx, hx.right⟩
  hyps
    α : Type   {implicit}
    A : α → Prop
    B : α → Prop
    C : α → Prop
    hAB : ∀ (x : α), A x → B x
    x : α
    hx : A x ∧ C x
    hBx : B x
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#proof_ir
theorem intersection_subset {α : Type}
    (A B C : α → Prop)
    (hAB : ∀ x, A x → B x) :
    ∀ x, (A x ∧ C x) → (B x ∧ C x) := by
  intro x hx
  have hBx : B x := hAB x hx.1
  exact ⟨hBx, hx.2⟩
