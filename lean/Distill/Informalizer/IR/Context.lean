import Distill.Informalizer.IR.Proof

/-!
# Working with Proof IR expressions

The expressions in a `ProofIR` mention its hypotheses (`FVarId`s) and goals (`MVarId`s). To
type-check, compare or pretty-print them, `ProofIR.withContext` rebuilds a local context with
every hypothesis and a metavariable context with every goal.
-/

namespace Distill.Informalizer.IR.ProofIR

open Lean Meta

/-- The goals in the order Lean created them: a node's goals before it, then those of the nodes
nested in it, then its goals after it. -/
def goalOrder (ir : ProofIR) : Array MVarId := Id.run do
  let nested : Std.HashSet Nat := .ofList (ir.nodes.toList.flatMap (·.children.toList))
  let mut seen : Std.HashSet MVarId := {}
  let mut out := #[]
  -- An explicit stack of (node, whether its children are done), to avoid recursion.
  let mut stack : List (Nat × Bool) :=
    (ir.nodes.filter (!nested.contains ·.id)).toList.map (·.id, false)
  let mut pending : Array MVarId := #[ir.rootGoal]
  while true do
    for g in pending do
      unless seen.contains g || !ir.goals.contains g do
        seen := seen.insert g
        out := out.push g
    pending := #[]
    match stack with
    | [] => break
    | (i, childrenDone) :: rest =>
      let n := ir.nodes[i]!
      if childrenDone then
        pending := n.goalsAfter
        stack := rest
      else
        pending := n.goalsBefore
        stack := n.children.toList.map (·, false) ++ (i, true) :: rest
  return out

/-- The hypotheses in the order Lean created them: the statement binders, then the new
hypotheses of each goal in `goalOrder`. -/
def hypOrder (ir : ProofIR) : Array FVarId := Id.run do
  let mut seen : Std.HashSet FVarId := {}
  let mut out := #[]
  for g in ir.goalOrder do
    for h in ir.statement.binders ++ (ir.goal? g |>.map (·.context) |>.getD #[]) do
      unless seen.contains h || !ir.hyps.contains h do
        seen := seen.insert h
        out := out.push h
  return out

private def addHyp (lctx : LocalContext) (h : HypInfo) : LocalContext :=
  match h.value? with
  | some v => lctx.mkLetDecl h.fvarId h.userName h.type v
  | none => lctx.mkLocalDecl h.fvarId h.userName h.type h.binderInfo

private def goalLCtx (ir : ProofIR) (hs : Array FVarId) : LocalContext :=
  hs.foldl (init := {}) fun lctx h =>
    match ir.hyps[h]? with
    | some hi => addHyp lctx hi
    | none => lctx

/--
Runs `x` with every hypothesis of `ir` in the local context and every goal declared as a
metavariable, so that expressions from `ir` can be type-checked and pretty-printed. A goal is
declared the way it occurs in its parent's proof: in the parent's context, as a function of its
new hypotheses (`?g1 : ∀ x, x ∈ A` for `fun x => ?g1 x`). `goalName` sets the user name of
each goal's metavariable, which is what the pretty printer shows (`?name`); by default it is the
goal's tag.
-/
def withContext (ir : ProofIR) (x : MetaM α) (goalName : MVarId → Name := fun g =>
    (ir.goal? g).map (·.tag) |>.getD .anonymous) : MetaM α := do
  let order := ir.hypOrder
  let lctx := order.foldl (init := {}) fun lctx h => addHyp lctx ir.hyps[h]!
  withLCtx lctx #[] do
    let insts ← order.filterMapM fun h => do
      return (← isClass? ir.hyps[h]!.type).map ({ className := ·, fvar := .fvar h })
    withLCtx lctx insts do
      for g in ir.goalOrder do
        let gi := ir.goals[g]!
        let new := if g == ir.rootGoal then #[] else ir.newHyps g
        let outer := gi.context.filter (!new.contains ·)
        let type ← mkForallFVars (new.map .fvar) gi.target
        let ginsts := insts.filter (outer.contains ·.fvar.fvarId!)
        modifyMCtx (·.addExprMVarDecl g (goalName g) (ir.goalLCtx outer) ginsts type .syntheticOpaque 0)
      x

/-- Runs `x` (inside `withContext`) in the local context of goal `g`, where its target and the
expressions of its hypotheses make sense. -/
def withGoalContext (ir : ProofIR) (g : MVarId) (x : MetaM α) : MetaM α := do
  let some gi := ir.goal? g | x
  let insts := (← getLocalInstances).filter (gi.context.contains ·.fvar.fvarId!)
  withLCtx (ir.goalLCtx gi.context) insts x

mutual
  /--
  The proof term that the assignments from `g` down add up to, or `none` if a goal on the way
  is unassigned (or, in a malformed IR, mentions itself). `visiting` are the goals on the way.

  An assignment mentions a subgoal applied to terms for its new hypotheses (`fun x => ?g1 x`),
  so the subgoal's proof is put in with those terms substituted for the hypotheses.
  -/
  partial def proofTerm? (ir : ProofIR) (g : MVarId := ir.rootGoal)
      (visiting : List MVarId := []) : Option Expr := do
    if visiting.contains g then none
    let gi ← ir.goal? g
    let a ← gi.assignment?
    fillSubgoals ir (g :: visiting) a.proof

  private partial def fillSubgoals (ir : ProofIR) (visiting : List MVarId) (e : Expr) :
      Option Expr := do
    let fillSubgoals := fillSubgoals ir visiting
    if !e.hasExprMVar then return e
    if let .mvar m := e.getAppFn then
      if ir.goals.contains m then
        let args ← e.getAppArgs.mapM fillSubgoals
        let new := ir.newHyps m
        if args.size < new.size then none
        let sub ← proofTerm? ir m visiting
        return ((sub.abstract (new.map .fvar)).instantiateRevRange 0 new.size args).beta
          (args.extract new.size args.size)
    match e with
    | .app f x => return .app (← fillSubgoals f) (← fillSubgoals x)
    | .lam n d b bi => return .lam n (← fillSubgoals d) (← fillSubgoals b) bi
    | .forallE n d b bi => return .forallE n (← fillSubgoals d) (← fillSubgoals b) bi
    | .letE n t v b nd => return .letE n (← fillSubgoals t) (← fillSubgoals v) (← fillSubgoals b) nd
    | .mdata d b => return .mdata d (← fillSubgoals b)
    | .proj s i b => return .proj s i (← fillSubgoals b)
    | _ => return e
end

end Distill.Informalizer.IR.ProofIR
