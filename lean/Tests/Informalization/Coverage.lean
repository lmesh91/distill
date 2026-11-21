import Distill.Informalizer.Coverage
import Distill.Informalizer.Extract.Frontend

/-! #104: the coverage check. It finds nothing to report on the demo levels, and it does report
an untranslated tactic and a definition without English (the negative test below). -/

open Lean Distill.Informalizer

/-- The coverage gaps of every proof in a Lean source, or that there are none. -/
unsafe def printCoverage (source : String) (fileName : String := "<input>") : IO Unit := do
  let (trees, _, _) ← Extract.elabSource source fileName
  let mut total := 0
  for tree in trees do
    for (decl, gaps) in ← treeCoverageGaps tree do
      total := total + gaps.size
      for g in gaps do IO.println s!"{decl}: {g}"
  if total == 0 then IO.println "every construct has a translation"

/--
info: every construct has a translation
-/
#guard_msgs in
#eval do printCoverage (← IO.FS.readFile "Distill/Levels/Demo.lean") "Demo.lean"

/--
info: twice_subset: Lean code in the English: `x ∈ Twice A`
twice_subset: Lean code in the statement
twice_subset: no English for the definition `Twice`
by_trivial: Lean code in the English: `trivial`
-/
#guard_msgs in
#eval printCoverage "
import Distill.Levels.Demo
open Distill

def Twice (A : Set α) : Set α := A ∩ A

theorem twice_subset (A : Set α) : Twice A ⊆ A := by
  intro x hx
  exact hx.1

theorem by_trivial (A : Set α) (x : α) (h : x ∈ A) : x ∈ A := by
  trivial
"

/-! A `sorry`'s own arguments (`Lean.Name`, `Bool`, …) are not constants the proof uses. -/

/--
info: every construct has a translation
-/
#guard_msgs in
#eval printCoverage "
import Distill.Levels.Demo
open Distill

theorem with_sorry (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  sorry
"
