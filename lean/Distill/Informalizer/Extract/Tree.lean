import Distill.Informalizer.IR.Common

/-!
# Walking the InfoTree

Collects the `TacticInfo` nodes of a command's InfoTree, grouped by tactic proof, with the
context, path and nesting extraction needs. Nothing here interprets the tactics.
-/

namespace Distill.Informalizer.Extract

open Lean Elab

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
  as they were before later metavariable assignments. -/
  terms : Array Expr := #[]

/-- The tactic nodes of one tactic proof (one outermost `by` block). -/
structure RawProof where
  /-- Pre-order, so execution order. `nodes[0]` is the `by` block itself. -/
  nodes : Array RawNode
  aliases : Array FVarAliasInfo
  /-- Whether the `by` block is the whole body of the declaration (`theorem t … := by …`), as
  opposed to a part of a term, of the signature, of an instance, …. -/
  isDeclBody : Bool

private structure WalkState where
  proofs : Array RawProof := #[]
  /-- The proof being collected, if the walk is inside an outermost `by` block. -/
  current? : Option RawProof := none

private abbrev WalkM := StateT WalkState IO

/-- The bodies (after `:=`) of the declarations in a command: every declaration of a `mutual`
block, and the auxiliary definitions in `where` clauses. -/
private partial def declBodies (stx : Syntax) : Array Syntax :=
  let own :=
    if stx.isOfKind ``Lean.Parser.Command.declValSimple then #[stx[1]]
    else if stx.isOfKind ``Lean.Parser.Term.whereDecls then
      -- `letRecDecl`s, each holding a `letDecl` around a `letIdDecl` whose last argument is the body.
      stx[1].getSepArgs.filterMap fun d =>
        let d := d[2][0]
        if d.isOfKind ``Lean.Parser.Term.letIdDecl then d.getArgs.back? else none
    else #[]
  own ++ stx.getArgs.flatMap declBodies

private def sameRange (a b : Syntax) : Bool :=
  a.getPos?.isSome && a.getPos? == b.getPos? && a.getTailPos? == b.getTailPos?

/-- `cmd?` is the innermost command being elaborated. Subtrees that elaboration left as `.hole`s
(postponed, asynchronous) are skipped: callers must pass a tree with them substituted. -/
private partial def walk (ctx? : Option ContextInfo) (cmd? : Option Syntax) (path : Array Nat)
    (parent? : Option Nat) : InfoTree → WalkM Unit
  | .context i t => walk (i.mergeIntoOuter? ctx?) cmd? path parent? t
  | .hole _ => pure ()
  | .node info children => do
    let mut parent? := parent?
    let cmd? := if let .ofCommandInfo ci := info then some ci.stx else cmd?
    match info, ctx? with
    | .ofTacticInfo ti, some ctx =>
      if (← get).current?.isNone then
        -- Only `by` blocks start a proof. Other tactic infos outside one (e.g. from `decreasing_by`
        -- machinery) are ignored.
        if ti.stx.getKind == ``Lean.Parser.Term.byTactic then
          let isDeclBody := cmd?.any fun cmd => (declBodies cmd).any (sameRange · ti.stx)
          modify ({ · with current? := some { nodes := #[], aliases := #[], isDeclBody } })
      if let some proof := (← get).current? then
        let idx := proof.nodes.size
        let mut nodes := proof.nodes.push { ctx, info := ti, path, parent? }
        if let some p := parent? then
          nodes := nodes.modify p fun n => { n with children := n.children.push idx }
        modify ({ · with current? := some { proof with nodes } })
        parent? := some idx
    | .ofTermInfo ti, _ =>
      if let (some proof, some p) := ((← get).current?, parent?) then
        let nodes := proof.nodes.modify p fun n => { n with terms := n.terms.push ti.expr }
        modify ({ · with current? := some { proof with nodes } })
    | .ofFVarAliasInfo a, _ =>
      if let some proof := (← get).current? then
        modify ({ · with current? := some { proof with aliases := proof.aliases.push a } })
    | _, _ => pure ()
    let mut i := 0
    for c in children do
      walk ctx? cmd? (path.push i) parent? c
      i := i + 1
    -- Leaving the node that started the current proof finishes it.
    if parent?.isSome && (← get).current?.any (·.nodes.size > 0) then
      if let .ofTacticInfo ti := info then
        if let some proof := (← get).current? then
          if ti.stx.getKind == ``Lean.Parser.Term.byTactic && proof.nodes[0]?.any (·.path == path) then
            modify fun s => { proofs := s.proofs.push proof, current? := none }

/-- The tactic proofs in a command's InfoTree, in source order. -/
def collectProofs (tree : InfoTree) : IO (Array RawProof) := do
  let ((), s) ← (walk none none #[] none tree).run {}
  return s.proofs

end Distill.Informalizer.Extract
