import Distill.Informalizer.IR.Proof

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

private def assignmentIn (mctx : MetavarContext) (g : MVarId) : Option Expr :=
  match mctx.eAssignment.find? g with
  | some v => some v
  | none => mctx.dAssignment.find? g |>.map (.mvar ·.mvarIdPending)

/-- Whether a node assigned `g` in its own state, whether or not that survived. -/
def assignedIn (ti : TacticInfo) (g : MVarId) : Bool :=
  (assignmentIn ti.mctxBefore g).isNone && (assignmentIn ti.mctxAfter g).isSome

/--
Whether a node assigned `g` and that assignment is the one in the current (final) metavariable
context. A node in an alternative that failed and was backtracked over (`first`, `repeat`,
`fail_if_success`, …) assigned `g` in its own state only. Assignments are compared after
instantiation, because `instantiateMVars` stores instantiated versions of them.
-/
def assignedBy (ti : TacticInfo) (g : MVarId) : MetaM Bool := do
  unless assignedIn ti g do return false
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

/-- The goal's case tag where it first appears: `case` and `next` clear it later. -/
private def firstTag (nodes : Array NodeFacts) (g : MVarId) : Option Name :=
  nodes.findSome? fun n =>
    if n.info.goalsBefore.contains g then n.info.mctxBefore.findDecl? g |>.map (·.userName)
    else if n.info.goalsAfter.contains g then n.info.mctxAfter.findDecl? g |>.map (·.userName)
    else none

/--
Builds the goal table. `nodes` are the proof's live tactic nodes, in pre-order. Runs in the final
metavariable context.
-/
def buildGoals (nodes : Array NodeFacts) (goals : Array MVarId) :
    MetaM (Std.HashMap MVarId GoalInfo) := do
  let goalSet := Std.HashSet.ofArray goals
  -- The nodes each goal is a goal before, in order.
  let holders : Std.HashMap MVarId (Array NodeFacts) := nodes.foldl (init := {}) fun m n =>
    n.info.goalsBefore.foldl (init := m) fun m g => m.alter g (some <| ·.getD #[] |>.push n)
  let mut table : Std.HashMap MVarId GoalInfo := {}
  for g in goals do
    let decl ← g.getDecl
    let context ← goalContext g
    let assignment? ← do
      -- The nodes that assign the same goal are nested in one another: take the innermost.
      let some n ← nodes.reverse.findM? (assignedBy ·.info g) | pure none
      -- The value as the node assigned it: later `instantiateMVars` calls store instantiated
      -- versions, in which the goal's subgoals are already replaced by their proofs.
      let some v := assignmentIn n.info.mctxAfter g | pure none
      let mut proof ← instantiateExceptGoals goalSet context v
      -- Goals only seen inside the node that its proof does not mention.
      let mentioned := (proof.collectMVars {}).result
      let nested := goals.filter fun h => h != g && !mentioned.contains h &&
        (holders[h]?.any fun hs => hs.all (n.contains ·))
      if !nested.isEmpty then
        let terms := n.terms ++ (nodes.filter (n.contains ·)).flatMap (·.terms)
        if let some p ← proofWithNestedGoals goalSet context g terms nested then proof := p
        for h in nested do
          unless (proof.collectMVars {}).result.contains h do
            if let some p ← foldByValue proof context h then proof := p
      pure (some { node := n.id, proof : Assignment })
    table := table.insert g {
      mvarId := g
      tag := (firstTag nodes g).getD decl.userName
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

/-- Builds the hypothesis table from the goals' local contexts. -/
def buildHyps (goals : Array MVarId) (aliases : Array FVarAliasInfo) :
    MetaM (Std.HashMap FVarId HypInfo) := do
  let goalSet := Std.HashSet.ofArray goals
  let mut table : Std.HashMap FVarId HypInfo := {}
  for g in goals do
    let context ← goalContext g
    for d in visibleHyps (← g.getDecl).lctx do
      if table.contains d.fvarId then continue
      let value? ← match d with
        | .ldecl (value := v) (nondep := false) .. =>
          some <$> instantiateExceptGoals goalSet context v
        | _ => pure none
      let replaces? := aliases.find? (·.id == d.fvarId) |>.map fun a =>
        { previous := a.baseId, fromAlias := true : HypLineage }
      table := table.insert d.fvarId {
        fvarId := d.fvarId
        userName := d.userName
        type := ← instantiateExceptGoals goalSet context d.type
        value?
        binderInfo := d.binderInfo
        replaces? }
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
  let mut hyps := hyps
  for (g, gi) in goals do
    let some p := gi.parent? | continue
    let some parent := goals[p]? | continue
    let steps := nodes.filter fun n => n.info.goalsBefore.contains p && n.info.goalsAfter.contains g
    for h in gi.context do
      let some hi := hyps[h]? | continue
      if hi.replaces?.isSome || parent.context.contains h then continue
      let name := hi.userName.eraseMacroScopes
      unless steps.any (atNames ·.info.stx name) do continue
      let previous? := parent.context.find? fun p =>
        !gi.context.contains p && hyps[p]?.any (·.userName == hi.userName)
      if let some previous := previous? then
        hyps := hyps.insert h { hi with replaces? := some { previous, fromAlias := false } }
  return hyps

end Distill.Informalizer.Extract
