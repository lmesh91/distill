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
    s1 untranslated `intro x hx`   origin direct [#4]
      proves ?g0: fun x hx => @?g2 x hx
    s2 untranslated `exact hx`   origin direct [#7]
      proves ?g2: hx
English
  Theorem. Let $A$ be a set. Then $A \subseteq A$.
  34: Apply `intro x hx`.
  37: Apply `exact hx`.
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
    s1 untranslated `intro x hx`   origin direct [#4]
      proves ?g0: fun x hx => @?g2 x hx
    s2 untranslated `have h : x ∈ A ∧ x ∈ B := hx`   origin direct [#7]
      proves ?g2: have h := hx; ?g3 h
    s3 untranslated `exact h.left`   origin direct [#19]
      proves ?g3: h.left
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
  41: Apply `intro x hx`.
  43: Apply `have h : x ∈ A ∧ x ∈ B := hx`.
  45: Apply `exact h.left`.
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
    s1 untranslated `intro x hx`   origin direct [#4]
      proves ?g0: fun x hx => @?g2 x hx
    s2 untranslated `exact hx.right`   origin direct [#7]
      proves ?g2: hx.right
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B$.
  49: Apply `intro x hx`.
  52: Apply `exact hx.right`.
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
    s3 untranslated `intro x hx`   origin direct [#4]
      proves ?g0: fun x hx => @?g2 x hx
    s4 untranslated `have ha : x ∈ A := hCA x hx`   origin direct [#7]
      proves ?g2: have ha := hCA x hx; ?g3 ha
    s5 untranslated `have hb : x ∈ B := hCB x hx`   origin direct [#19]
      proves ?g3: have hb := hCB x hx; ?g4 hb
    s6 untranslated `exact ⟨ha, hb⟩`   origin direct [#31]
      proves ?g4: ⟨ha, hb⟩
English
  Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
  56: Apply `intro x hx`.
  61: Apply `have ha : x ∈ A := hCA x hx`.
  62: Apply `have hb : x ∈ B := hCB x hx`.
  64: Apply `exact ⟨ha, hb⟩`.
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
    s1 untranslated `have hA : A ∩ B ⊆ A := inter_subset_left A B`   origin direct [#4]
      proves ?g0: have hA := inter_subset_left A B; ?g1 hA
    s2 untranslated `have hB : A ∩ B ⊆ B := inter_subset_right A B`   origin direct [#16]
      proves ?g1: have hB := inter_subset_right A B; ?g2 hB
    s3 untranslated `exact subset_inter hB hA`   origin direct [#28]
      proves ?g2: subset_inter hB hA
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B \cap A$.
  69: Apply `have hA : A ∩ B ⊆ A := inter_subset_left A B`.
  70: Apply `have hB : A ∩ B ⊆ B := inter_subset_right A B`.
  73: Apply `exact subset_inter hB hA`.
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
    s1 untranslated `ext`   origin direct [#4]
      proves ?g0: Set.ext ?g1 ?g2
    s2 untranslated `exact inter_subset_inter_comm A B`   origin direct [#5]
      proves ?g1: inter_subset_inter_comm A B
    s3 untranslated `exact inter_subset_inter_comm B A`   origin direct [#6]
      proves ?g2: inter_subset_inter_comm B A
English
  Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
  80: Apply `ext`.
  82: Apply `exact inter_subset_inter_comm A B`.
  83: Apply `exact inter_subset_inter_comm B A`.
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
    IO.println s!"{l.line + 1}: {l.english}"

/-! The level page shows this next to the editor. -/
/--
info: 31: Theorem. Let $A$ be a set. Then $A \subseteq A$.
34: Apply `intro x hx`.
37: Apply `exact hx`.
40: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
41: Apply `intro x hx`.
43: Apply `have h : x ∈ A ∧ x ∈ B := hx`.
45: Apply `exact h.left`.
48: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B$.
49: Apply `intro x hx`.
52: Apply `exact hx.right`.
55: Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
56: Apply `intro x hx`.
61: Apply `have ha : x ∈ A := hCA x hx`.
62: Apply `have hb : x ∈ B := hCB x hx`.
64: Apply `exact ⟨ha, hb⟩`.
67: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B \cap A$.
69: Apply `have hA : A ∩ B ⊆ A := inter_subset_left A B`.
70: Apply `have hB : A ∩ B ⊆ B := inter_subset_right A B`.
73: Apply `exact subset_inter hB hA`.
76: Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
80: Apply `ext`.
82: Apply `exact inter_subset_inter_comm A B`.
83: Apply `exact inter_subset_inter_comm B A`.
-/
#guard_msgs in
#eval printTranslation "Distill/Levels/Demo.lean"
