import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation

/-!
# Presentation: Proof IR ⟶ Presentation IR

`present` gives the first Presentation IR of a proof, which says no more than the Proof IR does:

* **Statement.** Every binder becomes an object in a group of its own, or a hypothesis if it is
  a proof of a proposition, in the order they were written. The conclusion is the goal of the
  proof. A hypothesis that a later binder is stated with (`(h : 0 < n) (i : Fin' n h)`) has to
  come before that binder, so it becomes a property of the object before it.
* **Proof.** Every surface node becomes an `untranslated` step, in execution order, with the
  part of the Lean proof it is responsible for as its `evidence`.

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

/-- The surface node each node was run for: itself if it is one, else the nearest one it is
nested in. -/
private def owners (ir : ProofIR) : Array (Option Nat) := Id.run do
  let mut owner : Array (Option Nat) := ir.nodes.map fun n =>
    if n.role == .surface then some n.id else none
  -- Parents come before their children.
  for n in ir.nodes do
    for c in n.children do
      if owner[c]!.isNone then owner := owner.set! c owner[n.id]!
  return owner

/--
The evidence of every surface node: the proofs of the goals that the node, and the nodes run
for it, assigned. The goals it left for other surface nodes (the body after a `have`, the
tactic block that proves it) stay metavariables.

A goal assigned by a node that no surface node encloses (`case` renaming a goal) is counted
with the first surface node nested in that node.
-/
private def nodeEvidence (ir : ProofIR) : Std.HashMap Nat (Array Evidence) := Id.run do
  let owner := owners ir
  let mut ownerOf : Std.HashMap MVarId Nat := {}
  for (g, gi) in ir.goals do
    let some a := gi.assignment? | continue
    let o? := (owner[a.node]?.getD none) <|> (ir.nestedSurface a.node)[0]?.map (·.id)
    if let some o := o? then ownerOf := ownerOf.insert g o
  let mut out : Std.HashMap Nat (Array Evidence) := {}
  for g in ir.goalOrder do
    let some o := ownerOf[g]? | continue
    -- Only the goals the node starts from: the others are part of their proofs.
    if (ir.goals[g]?.bind (·.parent?)).any (ownerOf[·]? == some o) then continue
    let own (g' : MVarId) : Option Expr :=
      if ownerOf[g']? == some o then (ir.goal? g' >>= (·.assignment?)).map (·.proof) else none
    if let some proof := ir.fillGoal own (strict := false) g then
      out := out.insert o ((out.getD o #[]).push { goal := g, proof })
  return out

/-- The Presentation IR of `ir` before normalization. Runs inside `ir.withContext`. -/
def present (ir : ProofIR) : MetaM PresentedDecl := do
  let mut nextId := 0
  let mut objects : Array ObjectGroup := #[]
  let mut hypotheses := #[]
  for h in ir.statement.binders do
    let some hi := ir.hyp? h | continue
    if ← isProp hi.type then
      let needed := ir.statement.binders.any fun b =>
        (ir.hyp? b).any fun bi => bi.type.containsFVar h || bi.value?.any (·.containsFVar h)
      if needed && !objects.isEmpty then
        let claim : Claim := { id := nextId, prop := { expr := hi.type }, hyp? := some h }
        nextId := nextId + 1
        objects := objects.modify (objects.size - 1) fun g =>
          { g with objects := g.objects.modify (g.objects.size - 1) fun o =>
              { o with properties := o.properties.push claim } }
        continue
      hypotheses := hypotheses.push { id := nextId, prop := { expr := hi.type }, hyp? := some h }
      nextId := nextId + 1
    else
      objects := objects.push { objects := #[{
        fvar := h, name := hi.userName, type := { expr := hi.type }
        value? := hi.value?.map ({ expr := · }), binderInfo := hi.binderInfo }] }
  let conclusion : Claim := { id := nextId, prop := { expr := ir.statement.conclusion } }
  nextId := nextId + 1
  let evidence := nodeEvidence ir
  let mut steps := #[]
  for n in ir.surfaceNodes do
    steps := steps.push {
      id := nextId, kind := .untranslated n.id
      origin := { relation := .direct, nodes := #[n.id] }
      evidence := evidence.getD n.id #[] }
    nextId := nextId + 1
  return {
    decl := ir.decl, role := declRole ir.decl, objects, hypotheses, conclusion
    rootGoal := ir.rootGoal, proof := { goal? := some conclusion, steps } }

end Distill.Informalizer
