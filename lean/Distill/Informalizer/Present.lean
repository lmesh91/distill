import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation

/-!
# Presentation: Proof IR ⟶ Presentation IR

`present` gives the first Presentation IR of a proof, which says no more than the Proof IR does:

* **Statement.** Every binder becomes an object, or a hypothesis if it is a proof of a
  proposition, in the order they were written. The conclusion is the goal of the proof.
* **Proof.** Every surface node becomes an `untranslated` step, in execution order.

Normalization (`Distill.Informalizer.Normalize`) then makes it read like mathematics. Translating
a tactic (#92) means giving its node steps of other kinds here.
-/

namespace Distill.Informalizer

open Lean Meta
open Distill.Informalizer.IR

/-- How a declaration is labeled. Lean keeps no record of `lemma`, so everything named is a
theorem. -/
def declRole (decl : Name) : DeclRole :=
  if decl.components.getLast? == some `_example then .example else .theorem

/-- The Presentation IR of `ir` before normalization. Runs inside `ir.withContext`. -/
def present (ir : ProofIR) : MetaM PresentedDecl := do
  let mut nextId := 0
  let mut objects := #[]
  let mut hypotheses := #[]
  for h in ir.statement.binders do
    let some hi := ir.hyp? h | continue
    if ← isProp hi.type then
      hypotheses := hypotheses.push { id := nextId, prop := { expr := hi.type }, hyp? := some h }
      nextId := nextId + 1
    else
      objects := objects.push {
        fvar := h, name := hi.userName, type := { expr := hi.type }
        value? := hi.value?.map ({ expr := · }) }
  let conclusion : Claim := { id := nextId, prop := { expr := ir.statement.conclusion } }
  nextId := nextId + 1
  let mut steps := #[]
  for n in ir.surfaceNodes do
    steps := steps.push {
      id := nextId, kind := .untranslated n.id
      origin := { relation := .direct, nodes := #[n.id] } }
    nextId := nextId + 1
  return {
    decl := ir.decl, role := declRole ir.decl, objects, hypotheses, conclusion
    proof := { goal? := some conclusion, steps } }

end Distill.Informalizer
