import Distill.Informalizer.Extract.Frontend
import Distill.Levels.Demo

/-! Extraction on the demo levels, as the web app will see them: the whole file, absolute
positions. Every proof should rebuild its declaration's proof term. -/

/--
info: ProofIR Distill.Levels.Demo.subset_rfl
  statement
    binders     [α, A]
    conclusion  A ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  31:42–37:10  ?g0 ⟶ —
      #1 structural [by]  31:42–31:44  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  34:2–37:10  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  34:2–37:10  ?g0 ⟶ —
            #4 surface `intro x hx`  34:2–34:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  34:2–34:9  ?g0 ⟶ ?g1
              #6 inner `hx`  34:10–34:12  ?g1 ⟶ ?g2
            #7 surface `exact hx`  37:2–37:10  ?g2 ⟶ —   [exact hx]
  goals
    ?g0 ⊢ A ⊆ A   ctx [α, A]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A → x ∈ A   ctx [α, A, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A   ctx [α, A, x, hx]   parent ?g1
        assigned by #7: hx
  hyps
    α : Type u_1   {implicit}
    A : Distill.Set α
    x : α
    hx : x ∈ A
  proof term: rebuilds the declaration's proof term
ProofIR Distill.Levels.Demo.inter_subset_left
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  40:55–45:14  ?g0 ⟶ —
      #1 structural [by]  40:55–40:57  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  41:2–45:14  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  41:2–45:14  ?g0 ⟶ —
            #4 surface `intro x hx`  41:2–41:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  41:2–41:9  ?g0 ⟶ ?g1
              #6 inner `hx`  41:10–41:12  ?g1 ⟶ ?g2
            #7 surface `have h : x ∈ A ∧ x ∈ B := hx`  43:2–43:30  ?g2 ⟶ ?g3   [have h : x ∈ A ∧ x ∈ B := hx]
              #8 inner `refine_lift  have h : x ∈ A ∧ x ∈ B := …`  synthetic 43:2–43:30  ?g2 ⟶ ?g3
                #9 inner `focus  (  refine  no_implicit_lambda%  …`  synthetic 43:2–43:30  ?g2 ⟶ ?g3
                  #10 inner `focus`  synthetic 43:2–43:30  ?g2 ⟶ ?g2
                  #11 inner `(  refine  no_implicit_lambda%  have h …`  synthetic 43:2–43:30  ?g2 ⟶ ?g3
                    #12 inner `(  refine  no_implicit_lambda%  have h …`  synthetic 43:2–43:30  ?g2 ⟶ ?g3
                      #13 inner `(  refine  no_implicit_lambda%  have h …`  synthetic 43:2–43:30  ?g2 ⟶ ?g3
                        #14 inner `refine  no_implicit_lambda%  have h : x…`  synthetic 43:2–43:30  ?g2 ⟶ ?g3
                          #15 inner `refine  no_implicit_lambda%  have h : x…`  synthetic 43:2–43:30  ?g2 ⟶ ?g3
                            #16 inner `refine  no_implicit_lambda%  have h : x…`  synthetic 43:2–43:30  ?g2 ⟶ ?g3   [refine have h := hx; ?g3 h]
                            #17 inner `;`  synthetic 43:2–43:30  ?g3 ⟶ ?g3
                            #18 inner `rotate_right`  synthetic 43:2–43:30  ?g3 ⟶ ?g3
            #19 surface `exact h.left`  45:2–45:14  ?g3 ⟶ —   [exact h.left]
  goals
    ?g0 ⊢ A ∩ B ⊆ A   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ A   ctx [α, A, B, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A   ctx [α, A, B, x, hx]   parent ?g1
        assigned by #16: have h := hx; ?g3 h
    ?g3 ⊢ x ∈ A   ctx [α, A, B, x, hx, h]   parent ?g2
        assigned by #19: h.left
  hyps
    α : Type u_1   {implicit}
    A : Distill.Set α
    B : Distill.Set α
    x : α
    hx : x ∈ A ∩ B
    h : x ∈ A ∧ x ∈ B
  proof term: rebuilds the declaration's proof term
ProofIR Distill.Levels.Demo.inter_subset_right
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ B
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  48:56–52:16  ?g0 ⟶ —
      #1 structural [by]  48:56–48:58  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  49:2–52:16  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  49:2–52:16  ?g0 ⟶ —
            #4 surface `intro x hx`  49:2–49:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  49:2–49:9  ?g0 ⟶ ?g1
              #6 inner `hx`  49:10–49:12  ?g1 ⟶ ?g2
            #7 surface `exact hx.right`  52:2–52:16  ?g2 ⟶ —   [exact hx.right]
  goals
    ?g0 ⊢ A ∩ B ⊆ B   ctx [α, A, B]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ A ∩ B → x ∈ B   ctx [α, A, B, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ B   ctx [α, A, B, x, hx]   parent ?g1
        assigned by #7: hx.right
  hyps
    α : Type u_1   {implicit}
    A : Distill.Set α
    B : Distill.Set α
    x : α
    hx : x ∈ A ∩ B
  proof term: rebuilds the declaration's proof term
ProofIR Distill.Levels.Demo.subset_inter
  statement
    binders     [α, A, B, C, hCA, hCB]
    conclusion  C ⊆ A ∩ B
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  55:80–64:16  ?g0 ⟶ —
      #1 structural [by]  55:80–55:82  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  56:2–64:16  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  56:2–64:16  ?g0 ⟶ —
            #4 surface `intro x hx`  56:2–56:12  ?g0 ⟶ ?g2   [intro [x, hx]]
              #5 inner `intro x`  56:2–56:9  ?g0 ⟶ ?g1
              #6 inner `hx`  56:10–56:12  ?g1 ⟶ ?g2
            #7 surface `have ha : x ∈ A := hCA x hx`  61:2–61:29  ?g2 ⟶ ?g3   [have ha : x ∈ A := hCA x hx]
              #8 inner `refine_lift  have ha : x ∈ A := hCA x h…`  synthetic 61:2–61:29  ?g2 ⟶ ?g3
                #9 inner `focus  (  refine  no_implicit_lambda%  …`  synthetic 61:2–61:29  ?g2 ⟶ ?g3
                  #10 inner `focus`  synthetic 61:2–61:29  ?g2 ⟶ ?g2
                  #11 inner `(  refine  no_implicit_lambda%  have ha…`  synthetic 61:2–61:29  ?g2 ⟶ ?g3
                    #12 inner `(  refine  no_implicit_lambda%  have ha…`  synthetic 61:2–61:29  ?g2 ⟶ ?g3
                      #13 inner `(  refine  no_implicit_lambda%  have ha…`  synthetic 61:2–61:29  ?g2 ⟶ ?g3
                        #14 inner `refine  no_implicit_lambda%  have ha : …`  synthetic 61:2–61:29  ?g2 ⟶ ?g3
                          #15 inner `refine  no_implicit_lambda%  have ha : …`  synthetic 61:2–61:29  ?g2 ⟶ ?g3
                            #16 inner `refine  no_implicit_lambda%  have ha : …`  synthetic 61:2–61:29  ?g2 ⟶ ?g3   [refine have ha := hCA x hx; ?g3 ha]
                            #17 inner `;`  synthetic 61:2–61:29  ?g3 ⟶ ?g3
                            #18 inner `rotate_right`  synthetic 61:2–61:29  ?g3 ⟶ ?g3
            #19 surface `have hb : x ∈ B := hCB x hx`  62:2–62:29  ?g3 ⟶ ?g4   [have hb : x ∈ B := hCB x hx]
              #20 inner `refine_lift  have hb : x ∈ B := hCB x h…`  synthetic 62:2–62:29  ?g3 ⟶ ?g4
                #21 inner `focus  (  refine  no_implicit_lambda%  …`  synthetic 62:2–62:29  ?g3 ⟶ ?g4
                  #22 inner `focus`  synthetic 62:2–62:29  ?g3 ⟶ ?g3
                  #23 inner `(  refine  no_implicit_lambda%  have hb…`  synthetic 62:2–62:29  ?g3 ⟶ ?g4
                    #24 inner `(  refine  no_implicit_lambda%  have hb…`  synthetic 62:2–62:29  ?g3 ⟶ ?g4
                      #25 inner `(  refine  no_implicit_lambda%  have hb…`  synthetic 62:2–62:29  ?g3 ⟶ ?g4
                        #26 inner `refine  no_implicit_lambda%  have hb : …`  synthetic 62:2–62:29  ?g3 ⟶ ?g4
                          #27 inner `refine  no_implicit_lambda%  have hb : …`  synthetic 62:2–62:29  ?g3 ⟶ ?g4
                            #28 inner `refine  no_implicit_lambda%  have hb : …`  synthetic 62:2–62:29  ?g3 ⟶ ?g4   [refine have hb := hCB x hx; ?g4 hb]
                            #29 inner `;`  synthetic 62:2–62:29  ?g4 ⟶ ?g4
                            #30 inner `rotate_right`  synthetic 62:2–62:29  ?g4 ⟶ ?g4
            #31 surface `exact ⟨ha, hb⟩`  64:2–64:16  ?g4 ⟶ —   [exact ⟨ha, hb⟩]
  goals
    ?g0 ⊢ C ⊆ A ∩ B   ctx [α, A, B, C, hCA, hCB]
        assigned by #5: fun x => ?g1 x
    ?g1 ⊢ x ∈ C → x ∈ A ∩ B   ctx [α, A, B, C, hCA, hCB, x]   parent ?g0
        assigned by #6: fun hx => ?g2 hx
    ?g2 ⊢ x ∈ A ∩ B   ctx [α, A, B, C, hCA, hCB, x, hx]   parent ?g1
        assigned by #16: have ha := hCA x hx; ?g3 ha
    ?g3 ⊢ x ∈ A ∩ B   ctx [α, A, B, C, hCA, hCB, x, hx, ha]   parent ?g2
        assigned by #28: have hb := hCB x hx; ?g4 hb
    ?g4 ⊢ x ∈ A ∩ B   ctx [α, A, B, C, hCA, hCB, x, hx, ha, hb]   parent ?g3
        assigned by #31: ⟨ha, hb⟩
  hyps
    α : Type u_1   {implicit}
    A : Distill.Set α   {implicit}
    B : Distill.Set α   {implicit}
    C : Distill.Set α   {implicit}
    hCA : C ⊆ A
    hCB : C ⊆ B
    x : α
    hx : x ∈ C
    ha : x ∈ A
    hb : x ∈ B
  proof term: rebuilds the declaration's proof term
ProofIR Distill.Levels.Demo.inter_subset_inter_comm
  statement
    binders     [α, A, B]
    conclusion  A ∩ B ⊆ B ∩ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  67:65–73:26  ?g0 ⟶ —
      #1 structural [by]  67:65–67:67  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  69:2–73:26  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  69:2–73:26  ?g0 ⟶ —
            #4 surface `have hA : A ∩ B ⊆ A := inter_subset_lef…`  69:2–69:46  ?g0 ⟶ ?g1   [have hA : A ∩ B ⊆ A := Distill.Levels.Demo.inter_subset_left A B]
              #5 inner `refine_lift  have hA : A ∩ B ⊆ A := int…`  synthetic 69:2–69:46  ?g0 ⟶ ?g1
                #6 inner `focus  (  refine  no_implicit_lambda%  …`  synthetic 69:2–69:46  ?g0 ⟶ ?g1
                  #7 inner `focus`  synthetic 69:2–69:46  ?g0 ⟶ ?g0
                  #8 inner `(  refine  no_implicit_lambda%  have hA…`  synthetic 69:2–69:46  ?g0 ⟶ ?g1
                    #9 inner `(  refine  no_implicit_lambda%  have hA…`  synthetic 69:2–69:46  ?g0 ⟶ ?g1
                      #10 inner `(  refine  no_implicit_lambda%  have hA…`  synthetic 69:2–69:46  ?g0 ⟶ ?g1
                        #11 inner `refine  no_implicit_lambda%  have hA : …`  synthetic 69:2–69:46  ?g0 ⟶ ?g1
                          #12 inner `refine  no_implicit_lambda%  have hA : …`  synthetic 69:2–69:46  ?g0 ⟶ ?g1
                            #13 inner `refine  no_implicit_lambda%  have hA : …`  synthetic 69:2–69:46  ?g0 ⟶ ?g1   [refine have hA := Distill.Levels.Demo.inter_subset_left A B; ?g1 hA]
                            #14 inner `;`  synthetic 69:2–69:46  ?g1 ⟶ ?g1
                            #15 inner `rotate_right`  synthetic 69:2–69:46  ?g1 ⟶ ?g1
            #16 surface `have hB : A ∩ B ⊆ B := inter_subset_rig…`  70:2–70:47  ?g1 ⟶ ?g2   [have hB : A ∩ B ⊆ B := Distill.Levels.Demo.inter_subset_right A B]
              #17 inner `refine_lift  have hB : A ∩ B ⊆ B := int…`  synthetic 70:2–70:47  ?g1 ⟶ ?g2
                #18 inner `focus  (  refine  no_implicit_lambda%  …`  synthetic 70:2–70:47  ?g1 ⟶ ?g2
                  #19 inner `focus`  synthetic 70:2–70:47  ?g1 ⟶ ?g1
                  #20 inner `(  refine  no_implicit_lambda%  have hB…`  synthetic 70:2–70:47  ?g1 ⟶ ?g2
                    #21 inner `(  refine  no_implicit_lambda%  have hB…`  synthetic 70:2–70:47  ?g1 ⟶ ?g2
                      #22 inner `(  refine  no_implicit_lambda%  have hB…`  synthetic 70:2–70:47  ?g1 ⟶ ?g2
                        #23 inner `refine  no_implicit_lambda%  have hB : …`  synthetic 70:2–70:47  ?g1 ⟶ ?g2
                          #24 inner `refine  no_implicit_lambda%  have hB : …`  synthetic 70:2–70:47  ?g1 ⟶ ?g2
                            #25 inner `refine  no_implicit_lambda%  have hB : …`  synthetic 70:2–70:47  ?g1 ⟶ ?g2   [refine have hB := Distill.Levels.Demo.inter_subset_right A B; ?g2 hB]
                            #26 inner `;`  synthetic 70:2–70:47  ?g2 ⟶ ?g2
                            #27 inner `rotate_right`  synthetic 70:2–70:47  ?g2 ⟶ ?g2
            #28 surface `exact subset_inter hB hA`  73:2–73:26  ?g2 ⟶ —   [exact Distill.Levels.Demo.subset_inter hB hA]
  goals
    ?g0 ⊢ A ∩ B ⊆ B ∩ A   ctx [α, A, B]
        assigned by #13: have hA := Distill.Levels.Demo.inter_subset_left A B; ?g1 hA
    ?g1 ⊢ A ∩ B ⊆ B ∩ A   ctx [α, A, B, hA]   parent ?g0
        assigned by #25: have hB := Distill.Levels.Demo.inter_subset_right A B; ?g2 hB
    ?g2 ⊢ A ∩ B ⊆ B ∩ A   ctx [α, A, B, hA, hB]   parent ?g1
        assigned by #28: Distill.Levels.Demo.subset_inter hB hA
  hyps
    α : Type u_1   {implicit}
    A : Distill.Set α
    B : Distill.Set α
    hA : A ∩ B ⊆ A
    hB : A ∩ B ⊆ B
  proof term: rebuilds the declaration's proof term
ProofIR Distill.Levels.Demo.inter_comm
  statement
    binders     [α, A, B]
    conclusion  A ∩ B = B ∩ A
  nodes
    #0 structural [Lean.Parser.Term.byTactic]  76:52–83:35  ?g0 ⟶ —
      #1 structural [by]  76:52–76:54  ?g0 ⟶ —
        #2 structural [Lean.Parser.Tactic.tacticSeq]  80:2–83:35  ?g0 ⟶ —
          #3 structural [Lean.Parser.Tactic.tacticSeq1Indented]  80:2–83:35  ?g0 ⟶ —
            #4 surface `ext`  80:2–80:5  ?g0 ⟶ ?g1 ?g2   [apply Distill.Set.ext ?g1 ?g2]
            #5 surface `exact inter_subset_inter_comm A B`  82:2–82:35  ?g1 ?g2 ⟶ ?g2   [exact Distill.Levels.Demo.inter_subset_inter_comm A B]
            #6 surface `exact inter_subset_inter_comm B A`  83:2–83:35  ?g2 ⟶ —   [exact Distill.Levels.Demo.inter_subset_inter_comm B A]
  goals
    ?g0 ⊢ A ∩ B = B ∩ A   ctx [α, A, B]
        assigned by #4: Distill.Set.ext ?g1 ?g2
    ?g1 (h₁) ⊢ A ∩ B ⊆ B ∩ A   ctx [α, A, B]   parent ?g0
        assigned by #5: Distill.Levels.Demo.inter_subset_inter_comm A B
    ?g2 (h₂) ⊢ B ∩ A ⊆ A ∩ B   ctx [α, A, B]   parent ?g0
        assigned by #6: Distill.Levels.Demo.inter_subset_inter_comm B A
  hyps
    α : Type u_1   {implicit}
    A : Distill.Set α
    B : Distill.Set α
  proof term: rebuilds the declaration's proof term
-/
#guard_msgs in
#eval Distill.Informalizer.Extract.printFile "Distill/Levels/Demo.lean"
