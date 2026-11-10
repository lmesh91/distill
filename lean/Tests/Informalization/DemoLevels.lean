import Distill.Informalizer.Frontend
import Distill.Translate
import Distill.Levels.Demo

/-! The pipeline on the demo levels, as the web app will see them: the whole file, absolute
lines. -/

/--
info: PresentedDecl Distill.Levels.Demo.subset_rfl   role theorem
  objects
    α : Type u_1
    A : Set α
  hypotheses
  conclusion
    f0: A ⊆ A
  proof
    s1 untranslated `intro x hx`   origin direct [#4]
    s2 untranslated `exact hx`   origin direct [#7]
English
  Theorem. Let `α : Type u_1` and `A : Set α`. Then `A ⊆ A`.
  34: Apply `intro x hx`.
  37: Apply `exact hx`.
PresentedDecl Distill.Levels.Demo.inter_subset_left   role theorem
  objects
    α : Type u_1
    A : Set α
    B : Set α
  hypotheses
  conclusion
    f0: A ∩ B ⊆ A
  proof
    s1 untranslated `intro x hx`   origin direct [#4]
    s2 untranslated `have h : x ∈ A ∧ x ∈ B := hx`   origin direct [#7]
    s3 untranslated `exact h.left`   origin direct [#19]
English
  Theorem. Let `α : Type u_1`, `A : Set α` and `B : Set α`. Then `A ∩ B ⊆ A`.
  41: Apply `intro x hx`.
  43: Apply `have h : x ∈ A ∧ x ∈ B := hx`.
  45: Apply `exact h.left`.
PresentedDecl Distill.Levels.Demo.inter_subset_right   role theorem
  objects
    α : Type u_1
    A : Set α
    B : Set α
  hypotheses
  conclusion
    f0: A ∩ B ⊆ B
  proof
    s1 untranslated `intro x hx`   origin direct [#4]
    s2 untranslated `exact hx.right`   origin direct [#7]
English
  Theorem. Let `α : Type u_1`, `A : Set α` and `B : Set α`. Then `A ∩ B ⊆ B`.
  49: Apply `intro x hx`.
  52: Apply `exact hx.right`.
PresentedDecl Distill.Levels.Demo.subset_inter   role theorem
  objects
    α : Type u_1
    A : Set α
    B : Set α
    C : Set α
  hypotheses
    f0: C ⊆ A   hyp hCA
    f1: C ⊆ B   hyp hCB
  conclusion
    f2: C ⊆ A ∩ B
  proof
    s3 untranslated `intro x hx`   origin direct [#4]
    s4 untranslated `have ha : x ∈ A := hCA x hx`   origin direct [#7]
    s5 untranslated `have hb : x ∈ B := hCB x hx`   origin direct [#19]
    s6 untranslated `exact ⟨ha, hb⟩`   origin direct [#31]
English
  Theorem. Let `α : Type u_1`, `A : Set α`, `B : Set α` and `C : Set α`. Assume `C ⊆ A` and `C ⊆ B`. Then `C ⊆ A ∩ B`.
  56: Apply `intro x hx`.
  61: Apply `have ha : x ∈ A := hCA x hx`.
  62: Apply `have hb : x ∈ B := hCB x hx`.
  64: Apply `exact ⟨ha, hb⟩`.
PresentedDecl Distill.Levels.Demo.inter_subset_inter_comm   role theorem
  objects
    α : Type u_1
    A : Set α
    B : Set α
  hypotheses
  conclusion
    f0: A ∩ B ⊆ B ∩ A
  proof
    s1 untranslated `have hA : A ∩ B ⊆ A := inter_subset_left A B`   origin direct [#4]
    s2 untranslated `have hB : A ∩ B ⊆ B := inter_subset_right A B`   origin direct [#16]
    s3 untranslated `exact subset_inter hB hA`   origin direct [#28]
English
  Theorem. Let `α : Type u_1`, `A : Set α` and `B : Set α`. Then `A ∩ B ⊆ B ∩ A`.
  69: Apply `have hA : A ∩ B ⊆ A := inter_subset_left A B`.
  70: Apply `have hB : A ∩ B ⊆ B := inter_subset_right A B`.
  73: Apply `exact subset_inter hB hA`.
PresentedDecl Distill.Levels.Demo.inter_comm   role theorem
  objects
    α : Type u_1
    A : Set α
    B : Set α
  hypotheses
  conclusion
    f0: A ∩ B = B ∩ A
  proof
    s1 untranslated `ext`   origin direct [#4]
    s2 untranslated `exact inter_subset_inter_comm A B`   origin direct [#5]
    s3 untranslated `exact inter_subset_inter_comm B A`   origin direct [#6]
English
  Theorem. Let `α : Type u_1`, `A : Set α` and `B : Set α`. Then `A ∩ B = B ∩ A`.
  80: Apply `ext`.
  82: Apply `exact inter_subset_inter_comm A B`.
  83: Apply `exact inter_subset_inter_comm B A`.
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
info: 31: Theorem. Let `α : Type u_1` and `A : Set α`. Then `A ⊆ A`.
34: Apply `intro x hx`.
37: Apply `exact hx`.
40: Theorem. Let `α : Type u_1`, `A : Set α` and `B : Set α`. Then `A ∩ B ⊆ A`.
41: Apply `intro x hx`.
43: Apply `have h : x ∈ A ∧ x ∈ B := hx`.
45: Apply `exact h.left`.
48: Theorem. Let `α : Type u_1`, `A : Set α` and `B : Set α`. Then `A ∩ B ⊆ B`.
49: Apply `intro x hx`.
52: Apply `exact hx.right`.
55: Theorem. Let `α : Type u_1`, `A : Set α`, `B : Set α` and `C : Set α`. Assume `C ⊆ A` and `C ⊆ B`. Then `C ⊆ A ∩ B`.
56: Apply `intro x hx`.
61: Apply `have ha : x ∈ A := hCA x hx`.
62: Apply `have hb : x ∈ B := hCB x hx`.
64: Apply `exact ⟨ha, hb⟩`.
67: Theorem. Let `α : Type u_1`, `A : Set α` and `B : Set α`. Then `A ∩ B ⊆ B ∩ A`.
69: Apply `have hA : A ∩ B ⊆ A := inter_subset_left A B`.
70: Apply `have hB : A ∩ B ⊆ B := inter_subset_right A B`.
73: Apply `exact subset_inter hB hA`.
76: Theorem. Let `α : Type u_1`, `A : Set α` and `B : Set α`. Then `A ∩ B = B ∩ A`.
80: Apply `ext`.
82: Apply `exact inter_subset_inter_comm A B`.
83: Apply `exact inter_subset_inter_comm B A`.
-/
#guard_msgs in
#eval printTranslation "Distill/Levels/Demo.lean"
