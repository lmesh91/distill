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
    s1 fix   origin direct [#4]
      x : α   with f2: x ∈ A   hyp hx
      proves ?g0: fun x hx => @?g2 x hx
    s3 conclude   origin direct [#7]
      f4: x ∈ A
      by hx
      proves ?g2: hx
English
  Theorem. Let $A$ be a set. Then $A \subseteq A$.
  34: Let $x \in A$.
  37: Thus $x \in A$ by `hx`.
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
    s1 fix   origin direct [#4]
      x : α   with f2: x ∈ A ∩ B   hyp hx
      proves ?g0: fun x hx => @?g2 x hx
    s3 derive   origin direct [#7]
      f4: x ∈ A ∧ x ∈ B   hyp h
      by hx
      proves ?g2: have h := hx; ?g3 h
    s5 conclude   origin direct [#19]
      f6: x ∈ A
      by h.left
      proves ?g3: h.left
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
  41: Let $x \in A \cap B$.
  43: We have that $x \in A$ and $x \in B$ by `hx`.
  45: Thus $x \in A$ by `h.left`.
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
    s1 fix   origin direct [#4]
      x : α   with f2: x ∈ A ∩ B   hyp hx
      proves ?g0: fun x hx => @?g2 x hx
    s3 conclude   origin direct [#7]
      f4: x ∈ B
      by hx.right
      proves ?g2: hx.right
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B$.
  49: Let $x \in A \cap B$.
  52: Thus $x \in B$ by `hx.right`.
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
    s3 fix   origin direct [#4]
      x : α   with f4: x ∈ C   hyp hx
      proves ?g0: fun x hx => @?g2 x hx
    s5 derive   origin direct [#7]
      f6: x ∈ A   hyp ha
      by hCA x hx
      proves ?g2: have ha := hCA x hx; ?g3 ha
    s7 derive   origin direct [#19]
      f8: x ∈ B   hyp hb
      by hCB x hx
      proves ?g3: have hb := hCB x hx; ?g4 hb
    s9 conclude   origin direct [#31]
      f10: x ∈ A ∩ B
      by ⟨ha, hb⟩
      proves ?g4: ⟨ha, hb⟩
English
  Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
  56: Let $x \in C$.
  61: We have that $x \in A$ by `hCA x hx`.
  62: We have that $x \in B$ by `hCB x hx`.
  64: Thus $x \in A \cap B$ by `⟨ha, hb⟩`.
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
    s1 derive   origin direct [#4]
      f2: A ∩ B ⊆ A   hyp hA
      by inter_subset_left A B
      proves ?g0: have hA := inter_subset_left A B; ?g1 hA
    s3 derive   origin direct [#16]
      f4: A ∩ B ⊆ B   hyp hB
      by inter_subset_right A B
      proves ?g1: have hB := inter_subset_right A B; ?g2 hB
    s5 conclude   origin direct [#28]
      f6: A ∩ B ⊆ B ∩ A
      by subset_inter hB hA
      proves ?g2: subset_inter hB hA
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B \cap A$.
  69: We have that $A \cap B \subseteq A$ by `inter_subset_left A B`.
  70: We have that $A \cap B \subseteq B$ by `inter_subset_right A B`.
  73: Thus $A \cap B \subseteq B \cap A$ by `subset_inter hB hA`.
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
    s1 suffices   origin direct [#4]
      f2: A ∩ B ⊆ B ∩ A ∧ B ∩ A ⊆ A ∩ B
      by lemma Distill.Set.ext
      proves ?g0: Set.ext ?g1 ?g2
    s3 conclude   origin direct [#5]
      f4: A ∩ B ⊆ B ∩ A
      by inter_subset_inter_comm A B
      proves ?g1: inter_subset_inter_comm A B
    s5 conclude   origin direct [#6]
      f6: B ∩ A ⊆ A ∩ B
      by inter_subset_inter_comm B A
      proves ?g2: inter_subset_inter_comm B A
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
  80: By set extensionality, it suffices to show that $A \cap B \subseteq B \cap A$ and $B \cap A \subseteq A \cap B$.
  82: Thus $A \cap B \subseteq B \cap A$ by `inter_subset_inter_comm A B`.
  83: Thus $B \cap A \subseteq A \cap B$ by `inter_subset_inter_comm B A`.
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
34: Let $x \in A$.
37: Thus $x \in A$ by `hx`.
40: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
41: Let $x \in A \cap B$.
43: We have that $x \in A$ and $x \in B$ by `hx`.
45: Thus $x \in A$ by `h.left`.
48: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B$.
49: Let $x \in A \cap B$.
52: Thus $x \in B$ by `hx.right`.
55: Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
56: Let $x \in C$.
61: We have that $x \in A$ by `hCA x hx`.
62: We have that $x \in B$ by `hCB x hx`.
64: Thus $x \in A \cap B$ by `⟨ha, hb⟩`.
67: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B \cap A$.
69: We have that $A \cap B \subseteq A$ by `inter_subset_left A B`.
70: We have that $A \cap B \subseteq B$ by `inter_subset_right A B`.
73: Thus $A \cap B \subseteq B \cap A$ by `subset_inter hB hA`.
76: Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
80: By set extensionality, it suffices to show that $A \cap B \subseteq B \cap A$ and $B \cap A \subseteq A \cap B$.
82: Thus $A \cap B \subseteq B \cap A$ by `inter_subset_inter_comm A B`.
83: Thus $B \cap A \subseteq A \cap B$ by `inter_subset_inter_comm B A`.
-/
#guard_msgs in
#eval printTranslation "Distill/Levels/Demo.lean"
