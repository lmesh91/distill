import Distill.Informalizer.Constants
import Distill.Informalizer.Frontend

/-! #89: the definitions and theorems each demo proof uses, direct or reached by unfolding.
Compare with `docs/informalization/demo-coverage.md` §1–2: the notation constants, `Set`,
`And`/`Eq` and their projections and constructor, `Set.ext` and the earlier levels are direct;
`Set.Subset`, `Set.Intersection` and the field `Set.mem` are reached only by unfolding, and only
in levels 1–4. Instances and the auto-bound `α` are left out. -/

open Lean Distill.Informalizer

unsafe def printConstants (path : System.FilePath) : IO Unit := do
  let (trees, _, _) ← Extract.elabSource (← IO.FS.readFile path) path.toString
  for tree in trees do
    let some ctx := commandContext? tree | continue
    for ir in ← Extract.extractProofs tree do
      IO.println s!"{ir.decl}"
      for c in ← ctx.runMetaM {} (referencedConstants ir) do
        IO.println s!"  {c.name}: {c.kind.describe}{if c.direct then "" else ", reached by unfolding"}"

/--
info: Distill.Levels.Demo.subset_rfl
  HasSubset.Subset: definition
  Distill.Set: type
  Membership.mem: definition
  Distill.Set.Subset: definition, reached by unfolding
Distill.Levels.Demo.inter_subset_left
  HasSubset.Subset: definition
  Distill.Set: type
  Inter.inter: definition
  Membership.mem: definition
  And: type
  And.left: theorem
  Distill.Set.Intersection: definition, reached by unfolding
  Distill.Set.Subset: definition, reached by unfolding
  Distill.Set.mem: definition, reached by unfolding
Distill.Levels.Demo.inter_subset_right
  HasSubset.Subset: definition
  Distill.Set: type
  Inter.inter: definition
  Membership.mem: definition
  And.right: theorem
  Distill.Set.Intersection: definition, reached by unfolding
  Distill.Set.Subset: definition, reached by unfolding
  Distill.Set.mem: definition, reached by unfolding
Distill.Levels.Demo.subset_inter
  HasSubset.Subset: definition
  Distill.Set: type
  Inter.inter: definition
  Membership.mem: definition
  And.intro: constructor
  Distill.Set.Intersection: definition, reached by unfolding
  Distill.Set.Subset: definition, reached by unfolding
  Distill.Set.mem: definition, reached by unfolding
Distill.Levels.Demo.inter_subset_inter_comm
  HasSubset.Subset: definition
  Distill.Set: type
  Inter.inter: definition
  Distill.Levels.Demo.inter_subset_left: theorem
  Distill.Levels.Demo.inter_subset_right: theorem
  Distill.Levels.Demo.subset_inter: theorem
Distill.Levels.Demo.inter_comm
  Eq: type
  Distill.Set: type
  Inter.inter: definition
  Distill.Set.ext: theorem
  HasSubset.Subset: definition
  Distill.Levels.Demo.inter_subset_inter_comm: theorem
-/
#guard_msgs in
#eval printConstants "Distill/Levels/Demo.lean"
