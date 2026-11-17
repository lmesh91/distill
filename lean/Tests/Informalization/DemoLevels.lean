import Distill.Informalizer.Frontend
import Distill.Translate
import Distill.Levels.Demo

/-! The pipeline on the demo levels, as the web app will see them: the whole file, absolute
lines. -/

/--
info: PresentedDecl Distill.Levels.Demo.subset_rfl   role theorem
  objects
    {α} : Type u_1
    A : Set α
  hypotheses
  conclusion
    f0: A ⊆ A
  proof of ?g0
    s2 suffices   origin inferred [#4]
      f1: ∀ (x : α), x ∈ A → x ∈ A
      by definition Distill.Set.Subset
      proves ?g0: fun x => ?g1 x
    s3 fix   origin partOf [#4]
      x : α   with f4: x ∈ A   hyp hx
      proves ?g1: fun hx => ?g2 hx
    s7 conclude   origin partOf [#7]
      f6: x ∈ A
      by f4
      proves ?g2: hx
English
  Theorem. Let $A$ be a set. Then $A \subseteq A$.
  34: By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A$, $x \in A$.
  34: Let $x \in A$.
  37: We already know that $x \in A$, which is what we needed to show.
Verification
  statement: identical to the original statement
  proof: the steps rebuild a proof of the presented statement
PresentedDecl Distill.Levels.Demo.inter_subset_left   role theorem
  objects
    {α} : Type u_1
    A, B : Set α
  hypotheses
  conclusion
    f0: A ∩ B ⊆ A
  proof of ?g0
    s2 suffices   origin inferred [#4]
      f1: ∀ (x : α), x ∈ A ∩ B → x ∈ A
      by definition Distill.Set.Subset
      proves ?g0: fun x => ?g1 x
    s3 fix   origin partOf [#4]
      x : α   with f4: x ∈ A ∩ B   hyp hx
      proves ?g1: fun hx => ?g2 hx
    s7 derive   origin partOf [#7]
      f6: x ∈ A ∧ x ∈ B
      by f4
      by definition Distill.Set.Intersection
      by definition Distill.Set.mem
      proves ?g2: have h := hx; ?g3 h
    s9 conclude   origin partOf [#19]
      f8: x ∈ A
      by lemma And.left x ∈ A x ∈ B
      by f6
      proves ?g3: h.left
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
  41: By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$.
  41: Let $x \in A \cap B$.
  43: Then $x \in A$ and $x \in B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them).
  45: In particular, $x \in A$.
Verification
  statement: identical to the original statement
  proof: the steps rebuild a proof of the presented statement
PresentedDecl Distill.Levels.Demo.inter_subset_right   role theorem
  objects
    {α} : Type u_1
    A, B : Set α
  hypotheses
  conclusion
    f0: A ∩ B ⊆ B
  proof of ?g0
    s2 suffices   origin inferred [#4]
      f1: ∀ (x : α), x ∈ A ∩ B → x ∈ B
      by definition Distill.Set.Subset
      proves ?g0: fun x => ?g1 x
    s3 fix   origin partOf [#4]
      x : α   with f4: x ∈ A ∩ B   hyp hx
      proves ?g1: fun hx => ?g2 hx
    s7 derive   origin partOf [#7]
      f6: x ∈ A ∧ x ∈ B
      by f4
      by definition Distill.Set.Intersection
      by definition Distill.Set.mem
    s9 conclude   origin partOf [#7]
      f8: x ∈ B
      by lemma And.right x ∈ A x ∈ B
      by f6
      proves ?g2: hx.right
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B$.
  49: By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in B$.
  49: Let $x \in A \cap B$.
  52: Then $x \in A$ and $x \in B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them).
  52: In particular, $x \in B$.
Verification
  statement: identical to the original statement
  proof: the steps rebuild a proof of the presented statement
PresentedDecl Distill.Levels.Demo.subset_inter   role theorem
  objects
    {α} : Type u_1
    {A}, {B}, {C} : Set α
  hypotheses
    f0: C ⊆ A   hyp hCA
    f1: C ⊆ B   hyp hCB
  conclusion
    f2: C ⊆ A ∩ B
  proof of ?g0
    s4 suffices   origin inferred [#4]
      f3: ∀ (x : α), x ∈ C → x ∈ A ∩ B
      by definition Distill.Set.Subset
      proves ?g0: fun x => ?g1 x
    s5 fix   origin partOf [#4]
      x : α   with f6: x ∈ C   hyp hx
      proves ?g1: fun hx => ?g2 hx
    s9 derive   origin partOf [#7]
      f8: x ∈ A
      by f0
      by f6
      by definition Distill.Set.Subset
      proves ?g2: have ha := hCA x hx; ?g3 ha
    s11 derive   origin partOf [#19]
      f10: x ∈ B
      by f1
      by f6
      by definition Distill.Set.Subset
      proves ?g3: have hb := hCB x hx; ?g4 hb
    s13 conclude   origin partOf [#31]
      f12: x ∈ A ∩ B
      by lemma And.intro x ∈ A x ∈ B
      by f8
      by f10
      by definition Distill.Set.Intersection
      by definition Distill.Set.mem
      proves ?g4: ⟨ha, hb⟩
English
  Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
  56: By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in C$, $x \in A \cap B$.
  56: Let $x \in C$.
  61: Since $C \subseteq A$ and $x \in C$, we have $x \in A$ by the definition of subset.
  62: Since $C \subseteq B$ and $x \in C$, we have $x \in B$ by the definition of subset.
  64: Since $x \in A$ and $x \in B$, we conclude that $x \in A \cap B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them).
Verification
  statement: identical to the original statement
  proof: the steps rebuild a proof of the presented statement
PresentedDecl Distill.Levels.Demo.inter_subset_inter_comm   role theorem
  objects
    {α} : Type u_1
    A, B : Set α
  hypotheses
  conclusion
    f0: A ∩ B ⊆ B ∩ A
  proof of ?g0
    s2 derive   origin partOf [#4]
      f1: A ∩ B ⊆ A
      by lemma Distill.Levels.Demo.inter_subset_left α A B
      proves ?g0: have hA := inter_subset_left A B; ?g1 hA
    s4 derive   origin partOf [#16]
      f3: A ∩ B ⊆ B
      by lemma Distill.Levels.Demo.inter_subset_right α A B
      proves ?g1: have hB := inter_subset_right A B; ?g2 hB
    s6 conclude   origin partOf [#28]
      f5: A ∩ B ⊆ B ∩ A
      by lemma Distill.Levels.Demo.subset_inter α B A A ∩ B
      by f3
      by f1
      proves ?g2: subset_inter hB hA
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B \cap A$.
  69: We have $A \cap B \subseteq A$ by the earlier theorem that for all sets $A$ and $B$, $A \cap B \subseteq A$.
  70: We have $A \cap B \subseteq B$ by the earlier theorem that for all sets $A$ and $B$, $A \cap B \subseteq B$.
  73: Since $A \cap B \subseteq B$ and $A \cap B \subseteq A$, we conclude that $A \cap B \subseteq B \cap A$ by the earlier theorem that for all sets $A$, $B$ and $C$, if $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$, applied with $B$, $A$ and $A \cap B$ in place of $A$, $B$ and $C$.
Verification
  statement: identical to the original statement
  proof: the steps rebuild a proof of the presented statement
PresentedDecl Distill.Levels.Demo.inter_comm   role theorem
  objects
    {α} : Type u_1
    A, B : Set α
  hypotheses
  conclusion
    f0: A ∩ B = B ∩ A
  proof of ?g0
    s3 suffices   origin partOf [#4]
      f2: A ∩ B ⊆ B ∩ A ∧ B ∩ A ⊆ A ∩ B
      by lemma Distill.Set.ext α A ∩ B B ∩ A
      proves ?g0: Set.ext ?g1 ?g2
    s10 split   origin partOf [#4]
      branch f4: A ∩ B ⊆ B ∩ A
        s6 conclude   origin partOf [#5]
          f5: A ∩ B ⊆ B ∩ A
          by lemma Distill.Levels.Demo.inter_subset_inter_comm α A B
          proves ?g1: inter_subset_inter_comm A B
      branch f7: B ∩ A ⊆ A ∩ B
        s9 conclude   origin partOf [#6]
          f8: B ∩ A ⊆ A ∩ B
          by lemma Distill.Levels.Demo.inter_subset_inter_comm α B A
          proves ?g2: inter_subset_inter_comm B A
    s11 conclude   origin synthesized [#6]
      f1: A ∩ B = B ∩ A
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
  80: By extensionality for sets (two sets are equal if each is a subset of the other), it suffices to show that $A \cap B \subseteq B \cap A$ and $B \cap A \subseteq A \cap B$.
  82: First, we show that $A \cap B \subseteq B \cap A$.
  82: This holds by the earlier theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$.
  83: Next, we show that $B \cap A \subseteq A \cap B$.
  83: This holds by the earlier theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$, applied with $B$ and $A$ in place of $A$ and $B$.
  83: Therefore, $A \cap B = B \cap A$.
Verification
  statement: identical to the original statement
  proof: the steps rebuild a proof of the presented statement
-/
#guard_msgs in
#eval Distill.Informalizer.printFile "Distill/Levels/Demo.lean"

/-- What `Distill.translate` returns for a file: its English by (one-based) line. -/
unsafe def printTranslation (path : System.FilePath) : IO Unit := do
  let (trees, _, _) ← Distill.Informalizer.Extract.elabSource (← IO.FS.readFile path) path.toString
  for l in ← Distill.translateTrees trees do
    IO.println s!"{l.line + 1}: {l.english.toMarkup}"

/-! Over RPC the text is a list of parts, so that the page can lay out formulas and code. -/
/--
info: [{"text": "Apply ", "kind": "text"},
 {"text": "intro x hx", "kind": "code"},
 {"text": ".", "kind": "text"}]
-/
#guard_msgs in
#eval Lean.toJson ("Apply " ++ Distill.Informalizer.Text.code "intro x hx" ++ "." : Distill.Informalizer.Text)

/-! The level page shows this next to the editor. -/
/--
info: 31: Theorem. Let $A$ be a set. Then $A \subseteq A$.
34: By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A$, $x \in A$.
34: Let $x \in A$.
37: We already know that $x \in A$, which is what we needed to show.
40: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
41: By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$.
41: Let $x \in A \cap B$.
43: Then $x \in A$ and $x \in B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them).
45: In particular, $x \in A$.
48: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B$.
49: By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in B$.
49: Let $x \in A \cap B$.
52: Then $x \in A$ and $x \in B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them).
52: In particular, $x \in B$.
55: Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
56: By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in C$, $x \in A \cap B$.
56: Let $x \in C$.
61: Since $C \subseteq A$ and $x \in C$, we have $x \in A$ by the definition of subset.
62: Since $C \subseteq B$ and $x \in C$, we have $x \in B$ by the definition of subset.
64: Since $x \in A$ and $x \in B$, we conclude that $x \in A \cap B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them).
67: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B \cap A$.
69: We have $A \cap B \subseteq A$ by the earlier theorem that for all sets $A$ and $B$, $A \cap B \subseteq A$.
70: We have $A \cap B \subseteq B$ by the earlier theorem that for all sets $A$ and $B$, $A \cap B \subseteq B$.
73: Since $A \cap B \subseteq B$ and $A \cap B \subseteq A$, we conclude that $A \cap B \subseteq B \cap A$ by the earlier theorem that for all sets $A$, $B$ and $C$, if $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$, applied with $B$, $A$ and $A \cap B$ in place of $A$, $B$ and $C$.
76: Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
80: By extensionality for sets (two sets are equal if each is a subset of the other), it suffices to show that $A \cap B \subseteq B \cap A$ and $B \cap A \subseteq A \cap B$.
82: First, we show that $A \cap B \subseteq B \cap A$.
82: This holds by the earlier theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$.
83: Next, we show that $B \cap A \subseteq A \cap B$.
83: This holds by the earlier theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$, applied with $B$ and $A$ in place of $A$ and $B$.
83: Therefore, $A \cap B = B \cap A$.
-/
#guard_msgs in
#eval printTranslation "Distill/Levels/Demo.lean"
