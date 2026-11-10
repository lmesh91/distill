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

/-- References to the declaration being defined (`HypInfo.isRecursive`), by name. -/
def recursiveHyps (ir : ProofIR) : Array FVarId :=
  let hs := ir.hyps.values.toArray.filter (·.isRecursive)
  (hs.qsort (·.userName.quickLt ·.userName)).map (·.fvarId)

/-- The hypotheses in the order Lean created them: the statement binders, then the new
hypotheses of each goal in `goalOrder`, then the references to the declaration being defined. -/
def hypOrder (ir : ProofIR) : Array FVarId := Id.run do
  let mut seen : Std.HashSet FVarId := {}
  let mut out := #[]
  for g in ir.goalOrder do
    for h in ir.statement.binders ++ (ir.goal? g |>.map (·.context) |>.getD #[]) do
      unless seen.contains h || !ir.hyps.contains h do
        seen := seen.insert h
        out := out.push h
  return out ++ ir.recursiveHyps

private def addHyp (lctx : LocalContext) (h : HypInfo) : LocalContext :=
  match h.value? with
  | some v => lctx.mkLetDecl h.fvarId h.userName h.type v
  | none =>
    lctx.mkLocalDecl h.fvarId h.userName h.type h.binderInfo (if h.isRecursive then .auxDecl else .default)

private def goalLCtx (ir : ProofIR) (hs : Array FVarId) : LocalContext :=
  (hs ++ ir.recursiveHyps).foldl (init := {}) fun lctx h =>
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

/-- The hypotheses introduced on the way from the goal `ancestor` down to `g`, a goal in its
proof: the `newHyps` of the goals after `ancestor` on that way, outermost first. For a goal that
is not below `ancestor`, its own `newHyps`. -/
def hypsSince (ir : ProofIR) (ancestor g : MVarId) : Array FVarId := Id.run do
  let mut hyps := #[]
  let mut cur := g
  for _ in [0:ir.goals.size + 1] do
    if cur == ancestor then return hyps
    hyps := ir.newHyps cur ++ hyps
    match ir.goal? cur >>= (·.parent?) with
    | some p => cur := p
    | none => break
  return ir.newHyps g

mutual
  /--
  The proof of `g` according to `proof?`, with the goals in it replaced by their proofs in turn.
  `none` if `g` has no proof (or, in a malformed IR, its proof mentions itself). A goal further
  down without a proof also gives `none` if `strict`, and otherwise stays a metavariable.
  `visiting` are the goals on the way.

  The proof of a goal mentions a goal below it applied to terms for the hypotheses introduced in
  between (`fun x => ?g1 x`; `hypsSince`), so the lower goal's proof is put in with those terms
  substituted for the hypotheses. A goal that stays a metavariable is applied the same way,
  counting from the goal `fillGoal` was called for.
  -/
  partial def fillGoal (ir : ProofIR) (proof? : MVarId → Option Expr) (strict : Bool) (g : MVarId)
      (visiting : List MVarId := []) : Option Expr := do
    if visiting.contains g then none
    fillSubgoals ir proof? strict (g :: visiting) (← proof? g)

  private partial def fillSubgoals (ir : ProofIR) (proof? : MVarId → Option Expr) (strict : Bool)
      (visiting : List MVarId) (e : Expr) : Option Expr := do
    let fillSubgoals := fillSubgoals ir proof? strict visiting
    if !e.hasExprMVar then return e
    if let (.mvar m, some g) := (e.getAppFn, visiting.head?) then
      if ir.goals.contains m then
        let args ← e.getAppArgs.mapM fillSubgoals
        let new := ir.hypsSince g m
        if args.size < new.size then none
        match fillGoal ir proof? strict m visiting with
        | some sub =>
          return ((sub.abstract (new.map .fvar)).instantiateRevRange 0 new.size args).beta
            (args.extract new.size args.size)
        | none =>
          if strict then none
          -- The hypotheses between the first goal and `g` are still variables here; they become
          -- terms as this proof is put into the proofs of the goals above.
          let outer := (visiting.getLast?.map (ir.hypsSince · g)).getD #[]
          return mkAppN (.mvar m) (outer.map .fvar ++ args)
    match e with
    | .app f x => return .app (← fillSubgoals f) (← fillSubgoals x)
    | .lam n d b bi => return .lam n (← fillSubgoals d) (← fillSubgoals b) bi
    | .forallE n d b bi => return .forallE n (← fillSubgoals d) (← fillSubgoals b) bi
    | .letE n t v b nd => return .letE n (← fillSubgoals t) (← fillSubgoals v) (← fillSubgoals b) nd
    | .mdata d b => return .mdata d (← fillSubgoals b)
    | .proj s i b => return .proj s i (← fillSubgoals b)
    | _ => return e
end

/-- The proof term that the assignments from `g` down add up to, or `none` if a goal on the way
is unassigned (or, in a malformed IR, mentions itself). `visiting` are the goals on the way. -/
def proofTerm? (ir : ProofIR) (g : MVarId := ir.rootGoal) (visiting : List MVarId := []) :
    Option Expr :=
  ir.fillGoal (fun g => (ir.goal? g >>= (·.assignment?)).map (·.proof)) (strict := true) g visiting

/-- Names for the goals that do not depend on Lean's internal ids: `g0`, `g1`, … in `goalOrder`.
Pass it to `withContext` to have goals printed as `?g0`, `?g1`, …. -/
def goalNumbering (ir : ProofIR) : MVarId → Name :=
  let index : Std.HashMap MVarId Nat := .ofList (ir.goalOrder.toList.zipIdx)
  fun g => match index[g]? with
    | some i => .mkSimple s!"g{i}"
    | none => .mkSimple "✗"

end Distill.Informalizer.IR.ProofIR
