import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation
import Distill.Informalizer.Present.Term

/-!
# Presentation: Proof IR ⟶ Presentation IR

`present` gives the first Presentation IR of a proof, which says no more than the Proof IR does:

* **Statement.** Every binder becomes an object in a group of its own, or a hypothesis if it is
  a proof of a proposition, in the order they were written. The conclusion is the goal of the
  proof. A hypothesis that a later binder is stated with (`(h : 0 < n) (i : Fin' n h)`) has to
  come before that binder, so it becomes a property of the object before it.
* **Proof.** The proof terms the tactics built are read as mathematical steps
  (`Distill.Informalizer.Present.Term`), each with the part of the Lean proof it is responsible
  for as its `evidence`. The term of a tactic that is not known to say everything in it, and a
  term that cannot be read, stay `untranslated`; a goal nothing proves is a `gap`.

Normalization (`Distill.Informalizer.Normalize`) then makes it read like mathematics.
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

/-- The presentation of last resort: every surface node as the Lean it is, in source order. -/
private def quotedSteps (ir : ProofIR) (nextId : Nat) : Array ProofStep :=
  let evidence := nodeEvidence ir
  ir.surfaceNodes.mapIdx fun i n => {
    id := nextId + i, kind := .untranslated n.id
    origin := { relation := .direct, nodes := #[n.id] }
    evidence := evidence.getD n.id #[] }

/-- The steps of the proof of `ir`, and the variables only they have. `facts` are the
hypotheses of the statement. -/
private def proofSteps (ir : ProofIR) (nextId : Nat) (facts : Array Claim) :
    MetaM (Array ProofStep × Array LocalDecl) := do
  let init : Present.State := {
    nextId
    facts := facts.foldl (init := {}) fun m c => match c.hyp? with
      | some h => m.insert h { id := c.id, prop := c.prop.expr }
      | none => m }
  let run : Present.PresentM (Array ProofStep) := do
    let mut steps ← Present.goalSteps ir.rootGoal ir.statement.conclusion
    -- A tactic that proved nothing the steps account for (it ran after the proof was over, or
    -- on a goal another step swallowed) is still shown.
    let s ← get
    for n in ir.surfaceNodes do
      unless s.used.contains n.id || s.reported.contains n.id do
        if n.goalsBefore.isEmpty then
          steps := steps.push {
            id := ← Present.freshId, kind := .untranslated n.id
            origin := { relation := .direct, nodes := #[n.id] } }
    -- Evidence no step took: the proof ended in a goal that needed no words.
    let pending := (← get).pending
    let waiting := (← get).pendingNodes.filter fun n => !steps.any (·.origin.nodes.contains n)
    unless pending.isEmpty && waiting.isEmpty do
      match steps.back? with
      | some last => steps := steps.pop.push { last with
          evidence := last.evidence ++ pending
          origin := { last.origin with nodes := last.origin.nodes ++ waiting } }
      | none =>
        steps := #[{
          id := ← Present.freshId, kind := .untranslated 0
          origin := { relation := .direct, nodes := if ir.nodes.isEmpty then #[] else #[0] }
          evidence := pending }]
    return steps
  let (steps, s) ← (run.run { ir, owner := owners ir }).run init
  return (steps, s.locals)

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
  let facts := hypotheses ++ objects.flatMap (·.objects.flatMap (·.properties))
  let (steps, locals) ← tryCatchRuntimeEx (proofSteps ir nextId facts) fun _ =>
    pure (quotedSteps ir nextId, #[])
  return {
    decl := ir.decl, role := declRole ir.decl, objects, hypotheses, conclusion
    rootGoal := ir.rootGoal, proof := { goal? := some conclusion, steps }, locals }

end Distill.Informalizer
