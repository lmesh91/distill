import Distill.Informalizer.IR.Common
import Lean.Elab.Term

/-!
# Walking the InfoTree

Collects the `TacticInfo` nodes of a command's InfoTree, grouped by proof, with the context,
path and nesting extraction needs. Nothing here interprets the tactics.
-/

namespace Distill.Informalizer.Extract

open Lean Elab Meta

/-- A `TacticInfo` node together with what the walk knows about its position. -/
structure RawNode where
  ctx : ContextInfo
  info : TacticInfo
  /-- Child indices from the root of the command's InfoTree. `context` wrappers do not count. -/
  path : Array Nat
  /-- Index (in the proof's node array) of the nearest enclosing tactic node. -/
  parent? : Option Nat
  /-- Indices of the tactic nodes directly nested in this one, in execution order. -/
  children : Array Nat := #[]
  /-- The terms elaborated directly by this node (not by a nested tactic node), in pre-order,
  as they were before later metavariable assignments. Binders are left out. -/
  terms : Array Expr := #[]

/-- The nodes of one proof: a declaration body that proves a proposition, or a `by` block in
some other term. -/
structure RawProof where
  /-- Pre-order, so execution order. `nodes[0]` is the `by` block, or `termProofRoot?`'s node. -/
  nodes : Array RawNode
  aliases : Array FVarAliasInfo
  /-- Whether the proof is the whole body of a declaration (also of a `where` clause or
  `let rec`), as opposed to a `by` block in a term that is not a proof, in a signature, …. -/
  isDeclBody : Bool
  /-- Whether the body is a term, so that `nodes[0]` was made up by `termProofRoot?`. -/
  isTermProof : Bool := false

private structure WalkState where
  proofs : Array RawProof := #[]
  /-- The proof being collected, if the walk is inside one. -/
  current? : Option RawProof := none

private abbrev WalkM := StateT WalkState IO

/-- Changes the proof being collected, if any. It is taken out of the state first, so that its
arrays are changed in place rather than copied. -/
private def modifyCurrent (f : RawProof → RawProof) : WalkM Unit := do
  if let some proof ← modifyGet fun s => (s.current?, { s with current? := none }) then
    modify ({ · with current? := some (f proof) })

private def sameRange (a b : Syntax) : Bool :=
  a.getPos?.isSome && a.getPos? == b.getPos? && a.getTailPos? == b.getTailPos?

/-- The goal of a term proof. Lean has no metavariable for a declaration's body, so this one is
made up; its name cannot clash with Lean's, which are numbered. -/
def termProofGoal : MVarId := ⟨`_distill_term_proof⟩

private partial def firstTerm? : InfoTree → Option TermInfo
  | .context _ t => firstTerm? t
  | .hole _ => none
  | .node (.ofTermInfo ti) _ => some ti
  | .node _ children => children.toList.findSome? firstTerm?

/--
The node for the declaration body `stx`, if it is a term that proves a proposition. It is made to
look like a tactic that assigned the whole body to `termProofGoal`, so the `by` blocks in the body
are found the same way as those in `exact ⟨by …, by …⟩`. `value` is the elaborated body.
-/
private def termProofRoot? (ctx : ContextInfo) (stx : Syntax) (value : Expr)
    (children : PersistentArray InfoTree) : IO (Option TacticInfo) := do
  if stx.isOfKind ``Lean.Parser.Term.byTactic then return none
  let some ti := children.toList.findSome? firstTerm? | return none
  let type? ← ctx.runMetaM ti.lctx do
    let type ← instantiateMVars (← ti.expectedType?.getDM (inferType ti.expr))
    return if ← isProp type then some type else none
  let some type := type? | return none
  let mctx := ctx.mctx.addExprMVarDecl termProofGoal .anonymous ti.lctx #[] type .syntheticOpaque 0
  return some {
    stx, elaborator := .anonymous, goalsBefore := [termProofGoal]
    -- Set once the body's `by` blocks are known.
    goalsAfter := []
    mctxBefore := mctx
    mctxAfter := { mctx with eAssignment := mctx.eAssignment.insert termProofGoal value } }

/-- A term proof leaves the goals of its `by` blocks, like `refine ⟨?_, ?_⟩`. -/
private def finishProof (proof : RawProof) : RawProof :=
  if !proof.isTermProof then proof else
  let blocks := proof.nodes[0]?.map (·.children.toList) |>.getD []
  let goalsAfter := blocks.filterMap fun i => proof.nodes[i]? >>= (·.info.goalsBefore.head?)
  { proof with nodes := proof.nodes.modify 0 fun n => { n with info.goalsAfter := goalsAfter } }

/-- `body?` is the innermost declaration body. Subtrees that elaboration left as `.hole`s
(postponed, asynchronous) are skipped: callers must pass a tree with them substituted. -/
private partial def walk (ctx? : Option ContextInfo) (body? : Option Syntax) (path : Array Nat)
    (parent? : Option Nat) : InfoTree → WalkM Unit
  | .context i t => walk (i.mergeIntoOuter? ctx?) body? path parent? t
  | .hole _ => pure ()
  | .node info children => do
    let mut parent? := parent?
    let mut body? := body?
    let isBody := (Term.getBodyInfo? info).isSome
    -- Only kept for bodies: holding on to the proof being collected would copy it on every change.
    let outer ← if isBody then pure (← get).current? else pure none
    match info, ctx? with
    | .ofCustomInfo _, some ctx =>
      if let some body := Term.getBodyInfo? info then
        -- A `where` or `let rec` body inside another body is a proof of its own.
        modify ({ · with current? := none })
        body? := some info.stx
        parent? := none
        if let some value := body.value? then
          if let some root ← termProofRoot? ctx info.stx value children then
            parent? := some 0
            modify ({ · with current? := some {
              nodes := #[{ ctx, info := root, path, parent? := none }], aliases := #[]
              isDeclBody := true, isTermProof := true } })
    | .ofTacticInfo ti, some ctx =>
      if (← get).current?.isNone then
        -- Only `by` blocks start a proof. Other tactic infos outside one (e.g. from `decreasing_by`
        -- machinery) are ignored.
        if ti.stx.getKind == ``Lean.Parser.Term.byTactic then
          let isDeclBody := body?.any (sameRange · ti.stx)
          modify ({ · with current? := some { nodes := #[], aliases := #[], isDeclBody } })
      if let some idx := (← get).current?.map (·.nodes.size) then
        modifyCurrent fun proof =>
          let nodes := proof.nodes.push { ctx, info := ti, path, parent? }
          { proof with nodes := match parent? with
            | some p => nodes.modify p fun n => { n with children := n.children.push idx }
            | none => nodes }
        parent? := some idx
    | .ofTermInfo ti, _ =>
      if let (some p, false) := (parent?, ti.isBinder) then
        modifyCurrent fun proof =>
          { proof with nodes := proof.nodes.modify p fun n => { n with terms := n.terms.push ti.expr } }
    | .ofFVarAliasInfo a, _ =>
      modifyCurrent fun proof => { proof with aliases := proof.aliases.push a }
    | _, _ => pure ()
    let mut i := 0
    for c in children do
      walk ctx? body? (path.push i) parent? c
      i := i + 1
    -- Leaving the node that started the current proof finishes it.
    if let some proof := (← get).current? then
      if proof.nodes[0]?.any (·.path == path) then
        modify fun s => { s with proofs := s.proofs.push (finishProof proof), current? := none }
    if isBody then modify ({ · with current? := outer })

/-- The proofs in a command's InfoTree. -/
def collectProofs (tree : InfoTree) : IO (Array RawProof) := do
  let ((), s) ← (walk none none #[] none tree).run {}
  return s.proofs

end Distill.Informalizer.Extract
