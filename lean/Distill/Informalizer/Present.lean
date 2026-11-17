import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation
import Distill.Definitions.Sets

/-!
# Presentation: Proof IR ⟶ Presentation IR

`present` gives the first Presentation IR of a proof, which says no more than the Proof IR does:

* **Statement.** Every binder becomes an object in a group of its own, or a hypothesis if it is
  a proof of a proposition, in the order they were written. The conclusion is the goal of the
  proof. A hypothesis that a later binder is stated with (`(h : 0 < n) (i : Fin' n h)`) has to
  come before that binder, so it becomes a property of the object before it.
* **Proof.** Supported tactic details become mathematical steps, with the part of the Lean
  proof they are responsible for as their `evidence`. Other nodes stay `untranslated`.

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

private structure StepState where
  nextId : Nat
  visited : Std.HashSet Nat := {}

private abbrev PresentM := StateT StepState MetaM

private def freshId : PresentM Nat := do
  let id := (← get).nextId
  modify fun s => { s with nextId := id + 1 }
  return id

private def hypClaim (ir : ProofIR) (h : FVarId) : PresentM Claim := do
  let some hi := ir.hyp? h | throwError "missing hypothesis"
  return { id := ← freshId, prop := { expr := hi.type }, hyp? := some h }

private def mathObject (ir : ProofIR) (h : FVarId) : MetaM MathObject := do
  let some hi := ir.hyp? h | throwError "missing object"
  return {
    fvar := h, name := hi.userName, type := { expr := hi.type }
    value? := hi.value?.map ({ expr := · }), binderInfo := hi.binderInfo }

/-- Tactic intent comes from resolved details and goals, never from parsing tactic text.
An unsupported shape keeps its source. Every surface node's evidence is used exactly once,
including when an introduction becomes several steps or a `have` contains a nested proof. -/
private partial def presentNode (ir : ProofIR) (evidence : Std.HashMap Nat (Array Evidence))
    (n : TacticNode) : PresentM (Array ProofStep) := do
  if (← get).visited.contains n.id then return #[]
  modify fun s => { s with visited := s.visited.insert n.id }
  let id ← freshId
  let base : ProofStep := {
    id, kind := .untranslated n.id
    origin := { relation := .direct, nodes := #[n.id] }
    evidence := evidence.getD n.id #[] }
  -- Restore state as well as content if a handler cannot describe the whole node.
  let saved ← get
  try
    match n.detail with
    | .intro hyps =>
      if hyps.isEmpty then return #[base]
      let mut kinds : Array StepKind := #[]
      for h in hyps do
        let some hi := ir.hyp? h | throwError "missing introduced hypothesis"
        if ← isProp hi.type then
          let c ← hypClaim ir h
          -- Keep a newly introduced element and its membership together: "Let x ∈ A".
          if let some (set, .fvar x) := membership? hi.type then
            if let some (.fix os) := kinds.back? then
              if let some o := os.back? then
                if o.fvar == x && !set.containsFVar x then
                  kinds := kinds.set! (kinds.size - 1)
                    (.fix (os.set! (os.size - 1) { o with properties := o.properties.push c }))
                  continue
          kinds := kinds.push (.assume #[c] .forImplication)
        else
          kinds := kinds.push (.fix #[← mathObject ir h])
      let mut steps := #[]
      for i in [:kinds.size] do
        let stepId ← if i == 0 then pure id else freshId
        steps := steps.push { base with
          id := stepId
          kind := kinds[i]!
          origin := { base.origin with
            relation := if kinds.size == 1 then .direct else .partOf, hyps }
          evidence := if i == 0 then base.evidence else #[] }
      return steps
    | .have h term? proofGoal? =>
      let some hi := ir.hyp? h | return #[base]
      unless ← isProp hi.type do return #[base]
      let fact ← hypClaim ir h
      if let some g := proofGoal? then
        let some gi := ir.goal? g | return #[base]
        unless ← isDefEq gi.target hi.type do return #[base]
        let mut steps := #[]
        for child in ir.nestedSurface n.id do
          steps := steps ++ (← presentNode ir evidence child)
        return #[{ base with kind := .claim fact { goal? := some fact, steps } }]
      if let some term := term? then
        -- A term with a nested `by` or a sorry has not yet established the claim.
        if term.hasExprMVar || term.hasSorry then return #[base]
        return #[{ base with kind := .derive #[fact], reasons := #[.term { expr := term }] }]
      return #[base]
    | .term mode term =>
      let some g := n.goalsBefore[0]? >>= ir.goal? | return #[base]
      unless ← isProp g.target do return #[base]
      if term.hasSorry then return #[base]
      if mode == .exact && !term.hasExprMVar then
        let goal : Claim := { id := ← freshId, prop := { expr := g.target } }
        return #[{ base with kind := .conclude goal, reasons := #[.term { expr := term }] }]
      -- The demo's extensionality lemma reduces set equality to mutual inclusion.
      -- Inspect the resolved lemma, so other `ext` lemmas are not mislabeled.
      if mode == .apply && term.isAppOfArity ``Distill.Set.ext 5 then
        let goals := n.goalsAfter.filter (!n.goalsBefore.contains ·)
        if let #[g₁, g₂] := goals then
          let some a := ir.goal? g₁ | return #[base]
          let some b := ir.goal? g₂ | return #[base]
          unless a.context == g.context && b.context == g.context do return #[base]
          let goal : Claim := {
            id := ← freshId, prop := { expr := mkApp2 (mkConst ``And) a.target b.target } }
          return #[{ base with kind := .suffices goal, reasons := #[.lemma ``Distill.Set.ext] }]
      return #[base]
    | _ => return #[base]
  catch _ =>
    set saved
    return #[base]

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
  let (steps, _) ← (do
    let mut steps := #[]
    for n in ir.surfaceNodes do
      steps := steps ++ (← presentNode ir evidence n)
    pure steps : PresentM (Array ProofStep)).run { nextId }
  return {
    decl := ir.decl, role := declRole ir.decl, objects, hypotheses, conclusion
    rootGoal := ir.rootGoal, proof := { goal? := some conclusion, steps } }

end Distill.Informalizer
