import Distill.Informalizer.IR.Proof
import Lean.Util.CollectFVars

/-!
# Goals and hypotheses

Builds the goal graph and the hypothesis table of a Proof IR from the metavariable context at
the end of the proof.
-/

namespace Distill.Informalizer.Extract

open Lean Meta Elab
open Distill.Informalizer.IR

/-- The visible hypotheses of a local context, in order. -/
def visibleHyps (lctx : LocalContext) : Array LocalDecl :=
  lctx.foldl (init := #[]) fun acc d => if d.isImplementationDetail then acc else acc.push d

private structure InstContext where
  goals : Std.HashSet MVarId
  /-- The context of the goal the expression belongs to. -/
  scope : Std.HashSet FVarId

private abbrev InstM := ReaderT InstContext <| StateRefT (Std.HashMap ExprStructEq Expr) MetaM

/-- How goal `m` occurs in an expression: applied to its hypotheses that are not in scope (its
new hypotheses), so that substituting for them, as tactics do, reaches the goal. -/
private def goalOccurrence (m : MVarId) : InstM Expr := do
  let scope := (← read).scope
  let hyps := (visibleHyps (← m.getDecl).lctx).filter (!scope.contains ·.fvarId)
  return mkAppN (.mvar m) (hyps.map (·.toExpr))

mutual
  private partial def instGo (e : Expr) : InstM Expr := do
    if !e.hasMVar then return e
    if let some r := (← get)[(e : ExprStructEq)]? then return r
    let r ← match e with
      | .mvar m => instApp e m #[]
      | .app .. =>
        let f := e.getAppFn
        let args ← e.getAppArgs.mapM instGo
        match f with
        | .mvar m => instApp f m args
        | _ => pure (mkAppN (← instGo f) args)
      | .const n ls => pure (.const n (← ls.mapM instantiateLevelMVars))
      | .sort l => pure (.sort (← instantiateLevelMVars l))
      | .lam _ d b _ => pure (e.updateLambdaE! (← instGo d) (← instGo b))
      | .forallE _ d b _ => pure (e.updateForallE! (← instGo d) (← instGo b))
      | .letE _ t v b _ => pure (e.updateLetE! (← instGo t) (← instGo v) (← instGo b))
      | .mdata _ b => pure (e.updateMData! (← instGo b))
      | .proj _ _ b => pure (e.updateProj! (← instGo b))
      | _ => pure e
    modify (·.insert e r)
    return r

  /-- `f` is `.mvar m`, applied to the (already instantiated) `args`. Like `instantiateMVars`,
  except for goals. -/
  private partial def instApp (f : Expr) (m : MVarId) (args : Array Expr) : InstM Expr := do
    if (← read).goals.contains m then return mkAppN (← goalOccurrence m) args
    if let some v ← getExprMVarAssignment? m then
      return (← instGo v).beta args
    if let some d ← getDelayedMVarAssignment? m then
      -- `?m args` stands for `(fun fvars => ?pending) args`.
      let n := d.fvars.size
      if args.size < n then return mkAppN f args
      let v ← instGo (.mvar d.mvarIdPending)
      return ((v.abstract d.fvars).instantiateRevRange 0 n args).beta (args.extract n args.size)
    return mkAppN f args
end

/--
Instantiates the metavariables in `e`, an expression in the context `scope`, except goals, so
that a proof is only one level deep. A goal occurs applied to its new hypotheses
(`goalOccurrence`): `intro x` gives `fun x => ?g x`, and `rewrite … at h` gives
`?g (Eq.mp … h)`, the term the new `h` stands for.

Metavariables that are not goals are resolved like `instantiateMVars` does, including the
delayed-assignment placeholders `intro` and `have` create. Unassigned ones (e.g. in an
unfinished proof) stay as they are.
-/
def instantiateExceptGoals (goals : Std.HashSet MVarId) (scope : Array FVarId) (e : Expr) :
    MetaM Expr :=
  (instGo e).run { goals, scope := .ofArray scope } |>.run' {}

/-- The visible hypotheses of goal `g`. -/
def goalContext (g : MVarId) : MetaM (Array FVarId) :=
  return (visibleHyps (← g.getDecl).lctx).map (·.fvarId)

/-- What `g` is assigned in `mctx`; for a delayed assignment, the goal it waits for. -/
def assignmentIn (mctx : MetavarContext) (g : MVarId) : Option Expr :=
  match mctx.eAssignment.find? g with
  | some v => some v
  | none => mctx.dAssignment.find? g |>.map (.mvar ·.mvarIdPending)

/-- Whether a node assigned `g`. Nodes that were undone are not looked at: `discardedNodes`. -/
def assignedIn (ti : TacticInfo) (g : MVarId) : Bool :=
  (assignmentIn ti.mctxBefore g).isNone && (assignmentIn ti.mctxAfter g).isSome

/--
Whether a node's assignment of `g` is the one in the current (final) metavariable context. Compared
after instantiation, because `instantiateMVars` stores instantiated versions of assignments.
-/
def assignmentSurvives (ti : TacticInfo) (g : MVarId) : MetaM Bool := do
  let some final := assignmentIn (← getMCtx) g | return false
  let some own := assignmentIn ti.mctxAfter g | return false
  if own == final then return true
  return (← instantiateMVars own) == (← instantiateMVars final)

/-- What `buildGoals` needs to know about a tactic node. Nodes are numbered in pre-order, so
the nodes nested in a node are the ones numbered after it, up to `last`. -/
structure NodeFacts where
  id : Nat
  /-- The last node nested in this one, or `id`. -/
  last : Nat
  info : TacticInfo
  /-- The terms the node elaborated directly; see `RawNode.terms`. -/
  terms : Array Expr
  deriving Inhabited

private def NodeFacts.contains (n m : NodeFacts) : Bool :=
  n.id < m.id && m.id ≤ n.last

/--
A term elaborated by a tactic can contain `by` blocks (`exact ⟨by …, by …⟩`). Their goals are
often assigned before the tactic instantiates its term, so the term it assigns contains their
proofs rather than their goals. This recovers the term with the goals in place from the terms
the node elaborated (`terms`, in which the `by` blocks are still metavariables): the first one
that, fully instantiated, is the assigned proof. Returns `none` if there is none.
-/
private def proofWithNestedGoals (goals : Std.HashSet MVarId) (context : Array FVarId)
    (g : MVarId) (terms : Array Expr) (nested : Array MVarId) : MetaM (Option Expr) := do
  let full ← instantiateMVars (.mvar g)
  for t in terms do
    let t' ← instantiateExceptGoals goals context t
    if (t'.collectMVars {}).result.any nested.contains && (← instantiateMVars t) == full then
      return some t'
  return none

/-- How often `v` occurs in `e`, counting up to 2. -/
private def occurrences (e v : Expr) : Nat :=
  let rec go (e : Expr) : StateM (Std.HashMap Expr Nat) Nat := do
    if e == v then return 1
    if e.approxDepth < v.approxDepth then return 0
    if let some n := (← get)[e]? then return n
    let n ← match e with
      | .app f a => return (← go f) + (← go a)
      | .lam _ d b _ | .forallE _ d b _ => return (← go d) + (← go b)
      | .letE _ t x b _ => return (← go t) + (← go x) + (← go b)
      | .mdata _ b | .proj _ _ b => go b
      | _ => pure 0
    let n := min n 2
    modify (·.insert e n)
    return n
  (go e).run' {}

/--
The fallback for nested goals whose `by` block left no term to recover them from (`calc` steps,
`exact (by …)`, a `by` in a `rw` rule): replaces the proof of `h` in `proof` by `h`, if it
occurs exactly once. Only for goals without new hypotheses, whose proof occurs as it is.
-/
private def foldByValue (proof : Expr) (context : Array FVarId) (h : MVarId) :
    MetaM (Option Expr) := do
  unless (← goalContext h).all context.contains do return none
  let v ← instantiateMVars (.mvar h)
  if v.hasMVar || occurrences proof v != 1 then return none
  return proof.replace fun e => if e == v then some (.mvar h) else none

/-- Each goal's case tag where it first appears: `case` and `next` clear it later. -/
private def firstTags (nodes : Array NodeFacts) : Std.HashMap MVarId Name :=
  nodes.foldl (init := {}) fun m n =>
    let add (m : Std.HashMap MVarId Name) (gs : List MVarId) (mctx : MetavarContext) :=
      gs.foldl (init := m) fun m g =>
        if m.contains g then m else match mctx.findDecl? g with
          | some d => m.insert g d.userName
          | none => m
    add (add m n.info.goalsBefore n.info.mctxBefore)
      (n.info.goalsAfter.filter (!n.info.goalsBefore.contains ·)) n.info.mctxAfter

/-- The nodes directly nested in each node, and the outermost nodes, as indices into `nodes`. -/
private def nesting (nodes : Array NodeFacts) : Array (Array Nat) × Array Nat := Id.run do
  let mut kids := Array.replicate nodes.size #[]
  let mut tops := #[]
  -- The nodes `i` is nested in, innermost first.
  let mut open_ : List Nat := []
  for h : i in [0:nodes.size] do
    open_ := open_.dropWhile (!nodes[·]!.contains nodes[i])
    match open_ with
    | p :: _ => kids := kids.modify p (·.push i)
    | [] => tops := tops.push i
    open_ := i :: open_
  return (kids, tops)

/--
The innermost node that assigned `g`, as an index into `nodes`. A node assigns `g` if a node
nested in it does, so this goes down from the outermost nodes. Of the nodes directly nested in
one, the one that assigned `g` is the first whose final state has it assigned: nodes that were
undone are not among them, so the states of the others only gain assignments. It also goes
through nodes that did not assign `g`, since a term proof's first node starts from the final
state.
-/
private def assigner? (nodes : Array NodeFacts) (kids : Array (Array Nat)) (tops : Array Nat)
    (g : MVarId) : Option Nat := Id.run do
  let mut level := tops
  let mut found := none
  repeat
    let mut lo := 0
    let mut hi := level.size
    while lo < hi do
      let mid := (lo + hi) / 2
      if (assignmentIn nodes[level[mid]!]!.info.mctxAfter g).isSome then hi := mid else lo := mid + 1
    let some i := level[lo]? | break
    if assignedIn nodes[i]!.info g then found := some i
    level := kids[i]!
  return found

/--
Builds the goal table. `nodes` are the proof's live tactic nodes, in pre-order. Runs in the final
metavariable context.
-/
def buildGoals (nodes : Array NodeFacts) (goals : Array MVarId) :
    MetaM (Std.HashMap MVarId GoalInfo) := do
  let goalSet := Std.HashSet.ofArray goals
  let (kids, tops) := nesting nodes
  let tags := firstTags nodes
  -- The nodes each goal is a goal before, in order.
  let holders : Std.HashMap MVarId (Array NodeFacts) := nodes.foldl (init := {}) fun m n =>
    n.info.goalsBefore.foldl (init := m) fun m g => m.alter g (some <| ·.getD #[] |>.push n)
  let mut table : Std.HashMap MVarId GoalInfo := {}
  for g in goals do
    let decl ← g.getDecl
    let context ← goalContext g
    let assignment? ← do
      -- The nodes that assign the same goal are nested in one another: take the innermost.
      let some i := assigner? nodes kids tops g | pure none
      let n := nodes[i]!
      -- Nodes are in pre-order, so those nested in `n` come right after it.
      let inside := (nodes.extract (i + 1) nodes.size).takeWhile (n.contains ·)
      -- The value as the node assigned it: later `instantiateMVars` calls store instantiated
      -- versions, in which the goal's subgoals are already replaced by their proofs.
      let some v := assignmentIn n.info.mctxAfter g | pure none
      let mut proof ← instantiateExceptGoals goalSet context v
      -- Goals only seen inside the node that its proof does not mention.
      let mentioned := (proof.collectMVars {}).result
      let candidates := Std.HashSet.ofList (inside.toList.flatMap (·.info.goalsBefore))
      let nested := goals.filter fun h => candidates.contains h && h != g &&
        !mentioned.contains h && (holders[h]?.any fun hs => hs.all (n.contains ·))
      if !nested.isEmpty then
        let terms := n.terms ++ inside.flatMap (·.terms)
        if let some p ← proofWithNestedGoals goalSet context g terms nested then proof := p
        for h in nested do
          unless (proof.collectMVars {}).result.contains h do
            if let some p ← foldByValue proof context h then proof := p
      pure (some { node := n.id, proof : Assignment })
    table := table.insert g {
      mvarId := g
      tag := tags[g]?.getD decl.userName
      target := ← instantiateExceptGoals goalSet context decl.type
      context
      assignment? }
  -- Parents: the goal whose assignment contains this one.
  for (g, gi) in table.toArray do
    if let some a := gi.assignment? then
      for m in (a.proof.collectMVars {}).result do
        if m == g then continue
        if let some child := table[m]? then
          table := table.insert m { child with parent? := some g }
  -- Goals no assignment mentions (inlined in a term, or created by a tactic that then failed):
  -- the goal of the innermost tactic around where the goal first appears.
  for (h, gi) in table.toArray do
    if gi.parent?.isSome then continue
    let some m := holders[h]? >>= (·[0]?) | continue
    let around := nodes.filter fun c => c.contains m && c.info.goalsBefore.any (· != h)
    if let some g := around.back? >>= (·.info.goalsBefore.find? (· != h)) then
      table := table.insert h { gi with parent? := some g }
  return table

/-- Builds the hypothesis table from the goals' local contexts. The declaration being defined is
in those contexts too, as an auxiliary declaration, and is added if a proof calls it. -/
def buildHyps (goals : Std.HashMap MVarId GoalInfo) (aliases : Array FVarAliasInfo) :
    MetaM (Std.HashMap FVarId HypInfo) := do
  let goalSet := Std.HashSet.ofArray goals.keysArray
  let mut table : Std.HashMap FVarId HypInfo := {}
  for (g, gi) in goals do
    for d in visibleHyps (← g.getDecl).lctx do
      if table.contains d.fvarId then continue
      let value? ← match d with
        | .ldecl (value := v) (nondep := false) .. =>
          some <$> instantiateExceptGoals goalSet gi.context v
        | _ => pure none
      let replaces? := aliases.find? (·.id == d.fvarId) |>.map fun a =>
        { previous := a.baseId, fromAlias := true : HypLineage }
      table := table.insert d.fvarId {
        fvarId := d.fvarId
        userName := d.userName
        type := ← instantiateExceptGoals goalSet gi.context d.type
        value?
        binderInfo := d.binderInfo
        replaces? }
  let exprs := goals.values.flatMap (fun gi => gi.assignment?.map (·.proof) |>.toList) ++
    table.values.flatMap (·.value?.toList)
  let used := exprs.foldl collectFVars {}
  for (g, gi) in goals do
    for d in (← g.getDecl).lctx do
      if d.isAuxDecl && !table.contains d.fvarId && used.fvarSet.contains d.fvarId then
        table := table.insert d.fvarId {
          fvarId := d.fvarId, userName := d.userName, isRecursive := true
          type := ← instantiateExceptGoals goalSet gi.context d.type }
  return table

/-- Whether a tactic's `at` clause names a hypothesis called `n`, or is `at *`. -/
private def atNames (stx : Syntax) (n : Name) : Bool :=
  (stx.find? (·.isOfKind ``Lean.Parser.Tactic.location)).any fun loc =>
    (loc.find? (·.isOfKind ``Lean.Parser.Tactic.locationWildcard)).isSome ||
      (loc.find? fun s => s.isIdent && s.getId.eraseMacroScopes == n).isSome

/--
Links each hypothesis that a goal adds to the one it stands for in the parent goal, when Lean
recorded no alias: a tactic that changes a hypothesis (`rw … at h`) adds a new one with the same
name and drops the old one. Only for tactics whose `at` clause names it, since others (`induction
n`) reuse names for unrelated hypotheses. The link has `fromAlias := false`.
-/
def inferLineage (nodes : Array NodeFacts) (goals : Std.HashMap MVarId GoalInfo)
    (hyps : Std.HashMap FVarId HypInfo) : Std.HashMap FVarId HypInfo := Id.run do
  -- The nodes each goal is a goal after.
  let makers : Std.HashMap MVarId (Array NodeFacts) := nodes.foldl (init := {}) fun m n =>
    n.info.goalsAfter.foldl (init := m) fun m g => m.alter g (some <| ·.getD #[] |>.push n)
  let mut hyps := hyps
  for (g, gi) in goals do
    let some p := gi.parent? | continue
    let some parent := goals[p]? | continue
    let steps := (makers[g]?.getD #[]).filter (·.info.goalsBefore.contains p)
    let parentContext := Std.HashSet.ofArray parent.context
    let context := Std.HashSet.ofArray gi.context
    for h in gi.context do
      let some hi := hyps[h]? | continue
      if hi.replaces?.isSome || parentContext.contains h then continue
      let name := hi.userName.eraseMacroScopes
      unless steps.any (atNames ·.info.stx name) do continue
      let previous? := parent.context.find? fun p =>
        !context.contains p && hyps[p]?.any (·.userName == hi.userName)
      if let some previous := previous? then
        hyps := hyps.insert h { hi with replaces? := some { previous, fromAlias := false } }
  return hyps

end Distill.Informalizer.Extract
