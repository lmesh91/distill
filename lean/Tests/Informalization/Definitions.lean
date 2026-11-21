import Distill.Informalizer.Render
import Distill.Definitions.Sets

/-! #94: the Distill definitions the demo levels unfold have an English name and definition.
The proofs use the name in "by the definition of …" and give the definition the first time
(see `DemoLevels.lean`). -/

open Lean Meta Distill.Informalizer

def printConcepts (decls : List Name) : MetaM Unit := do
  for d in decls do
    let c? ← (Render.renderer.phrase? Concept (mkConst d)).run {} |>.run' {}
    match c? with
    | some c => IO.println s!"{d}: {c.name}{if c.background then " (background)" else ""}: {c.definition.toMarkup}"
    | none => IO.println s!"{d}: no English definition"

/--
info: Distill.Set: set: a set is a collection of elements, given by the condition for an element to belong to it
Distill.Set.mem: set membership (background): an element belongs to a set if it satisfies the condition that defines the set
Distill.Set.Subset: subset: one set is a subset of another if every element of the first is an element of the second
Distill.Set.Intersection: intersection: the intersection of two sets consists of the elements that belong to both of them
Distill.Set.Union: union: the union of two sets consists of the elements that belong to at least one of them
-/
#guard_msgs in
#eval printConcepts [``Distill.Set, ``Distill.Set.mem, ``Distill.Set.Subset,
  ``Distill.Set.Intersection, ``Distill.Set.Union]
