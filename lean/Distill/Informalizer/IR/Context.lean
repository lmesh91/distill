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
  -- A goal's context is its parent's and its new hypotheses, and parents usually come first.
  let mut done : Std.HashSet MVarId := {}
  for g in ir.goalOrder do
    let parentDone := (ir.goal? g >>= (·.parent?)).any done.contains
    done := done.insert g
    let hs := if parentDone then ir.newHyps g
      else ir.statement.binders ++ (ir.goal? g |>.map (·.context) |>.getD #[])
    for h in hs do
      unless seen.contains h || !ir.hyps.contains h do
        seen := seen.insert h
        out := out.push h
  return out ++ ir.recursiveHyps

private def addHyp (lctx : LocalContext) (h : HypInfo) : LocalContext :=
  match h.value? with
  | some v => lctx.mkLetDecl h.fvarId h.userName h.type v
  | none =>
    lctx.mkLocalDecl h.fvarId h.userName h.type h.binderInfo (if h.isRecursive then .auxDecl else .default)

/-- `lctx` with the hypotheses `hs` added. -/
private def addHyps (ir : ProofIR) (lctx : LocalContext) (hs : Array FVarId) : LocalContext :=
  hs.foldl (init := lctx) fun lctx h =>
    match ir.hyps[h]? with
    | some hi => addHyp lctx hi
    | none => lctx

/-- The local context of the hypotheses `hs`, after the references to the declaration being
defined. -/
private def goalLCtx (ir : ProofIR) (hs : Array FVarId) : LocalContext :=
  ir.addHyps (ir.addHyps {} ir.recursiveHyps) hs

/--
Runs `x` with every hypothesis of `ir` in the local context and every goal declared as a
metavariable, so that expressions from `ir` can be type-checked and pretty-printed. A goal is
declared the way it occurs in its parent's proof: in the parent's context, as a function of its
new hypotheses (`?g1 : ∀ x, x ∈ A` for `fun x => ?g1 x`). `goalName` sets the user name of
each goal's metavariable, which is what the pretty printer shows (`?name`); by default it is the
goal's tag.

A goal's context is usually its parent's with a few hypotheses more, so it is built from the
parent's rather than from nothing: a proof of `n` steps has `n` goals with contexts of up to
`n` hypotheses, and building each from nothing would take time quadratic in `n`.
-/
def withContext (ir : ProofIR) (x : MetaM α) (goalName : MVarId → Name := fun g =>
    (ir.goal? g).map (·.tag) |>.getD .anonymous) : MetaM α := do
  let order := ir.hypOrder
  let lctx := order.foldl (init := {}) fun lctx h => addHyp lctx ir.hyps[h]!
  withLCtx lctx #[] do
    let insts ← order.filterMapM fun h => do
      return (← isClass? ir.hyps[h]!.type).map ({ className := ·, fvar := .fvar h })
    withLCtx lctx insts do
      let empty := ir.addHyps {} ir.recursiveHyps
      -- The local context of each goal's whole context, for its subgoals to start from.
      let mut full : Std.HashMap MVarId (Array FVarId × LocalContext) := {}
      let extend (hs : Array FVarId) : Option (Array FVarId × LocalContext) → LocalContext
        | some (pre, l) => match sharedPrefix? pre hs with
          | some n => ir.addHyps l (hs.extract n hs.size)
          | none => ir.addHyps empty hs
        | none => ir.addHyps empty hs
      for g in ir.goalOrder do
        let gi := ir.goals[g]!
        let new := if g == ir.rootGoal then #[] else ir.newHyps g
        let parentCtx := (gi.parent? >>= ir.goal?).map (·.context) |>.getD #[]
        let outer := if new.isEmpty then gi.context
          else match sharedPrefix? parentCtx gi.context with
            | some n => gi.context.extract 0 n
            | none => gi.context.filter (!new.contains ·)
        let type ← mkForallFVars (new.map .fvar) gi.target
        let ginsts := if insts.isEmpty then #[] else insts.filter (outer.contains ·.fvar.fvarId!)
        let outerLCtx := extend outer (gi.parent? >>= full.get?)
        modifyMCtx (·.addExprMVarDecl g (goalName g) outerLCtx ginsts type .syntheticOpaque 0)
        full := full.insert g (gi.context, extend gi.context (some (outer, outerLCtx)))
      x

/-- Runs `x` (inside `withContext`) in the local context of goal `g`, where its target and the
expressions of its hypotheses make sense. -/
def withGoalContext (ir : ProofIR) (g : MVarId) (x : MetaM α) : MetaM α := do
  let some gi := ir.goal? g | x
  let insts ← do
    let all ← getLocalInstances
    pure <| if all.isEmpty then all else all.filter (gi.context.contains ·.fvar.fvarId!)
  -- The goal's metavariable is declared in its context without its new hypotheses, which come
  -- last.
  let lctx := match (← getMCtx).findDecl? g with
    | some decl => Id.run do
      let mut extra := #[]
      let mut i := gi.context.size
      while i > 0 do
        i := i - 1
        let h := gi.context[i]!
        if decl.lctx.contains h then break
        extra := extra.push h
      return ir.addHyps decl.lctx extra.reverse
    | none => ir.goalLCtx gi.context
  withLCtx lctx insts x

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

/-- What the hypotheses introduced since the first goal stand for: a term, and the number of
binders it was written under. -/
private abbrev FillSubst := Std.HashMap FVarId (Expr × Nat)

/-- `e` with the hypotheses of `subst` replaced by their terms, where `e` is under `depth`
binders. -/
private def substHyps (subst : FillSubst) (depth : Nat) (e : Expr) : Expr :=
  if subst.isEmpty || !e.hasFVar then e
  else (go 0 e).run' {}
where
  /-- `e` under `off` binders more than `depth`; cached, as terms share subterms. -/
  go (off : Nat) (e : Expr) : StateM (Std.HashMap (Expr × Nat) Expr) Expr := do
    if !e.hasFVar then return e
    if let some r := (← get)[(e, off)]? then return r
    let r ← match e with
      | .fvar f => pure <| match subst[f]? with
        | some (t, d) => t.liftLooseBVars 0 (depth + off - d)
        | none => e
      | .app f a => return e.updateApp! (← go off f) (← go off a)
      | .lam _ d b _ => return e.updateLambdaE! (← go off d) (← go (off + 1) b)
      | .forallE _ d b _ => return e.updateForallE! (← go off d) (← go (off + 1) b)
      | .letE _ t v b _ => return e.updateLetE! (← go off t) (← go off v) (← go (off + 1) b)
      | .mdata _ b => return e.updateMData! (← go off b)
      | .proj _ _ b => return e.updateProj! (← go off b)
      | _ => pure e
    modify (·.insert (e, off) r)
    return r

/--
`e`, a part of the proof of `g` that is under `depth` binders of the whole term, with the goals
in it replaced by their proofs and the hypotheses of `subst` by their terms.

It works from the top down: a goal's proof goes in with the hypotheses it introduces replaced by
the terms its parent applies it to (`fun x => ?g1 x`: `x` by the variable of the `fun`), and
each proof is walked once. Putting the subgoals' proofs in first and then replacing the
hypotheses would walk through the whole proof below each goal again, which takes time quadratic
in the length of the proof.
-/
private partial def fillTopDown (ir : ProofIR) (proof? : MVarId → Option Expr) (strict : Bool)
    (first g : MVarId) (seen : Std.HashSet MVarId) (subst : FillSubst) (depth : Nat) (e : Expr) :
    Option Expr := do
  let fill := fillTopDown ir proof? strict first g seen subst
  if !e.hasExprMVar then return substHyps subst depth e
  if let .mvar m := e.getAppFn then
    if ir.goals.contains m then
      let args ← e.getAppArgs.mapM (fill depth)
      let new := ir.hypsSince g m
      if args.size < new.size then none
      if seen.contains m then none
      match proof? m with
      | some p =>
        let subst' := (new.zip args).foldl (init := subst) fun s (h, a) => s.insert h (a, depth)
        let sub ← fillTopDown ir proof? strict first m (seen.insert m) subst' depth p
        return sub.beta (args.extract new.size args.size)
      | none =>
        if strict then none
        -- The hypotheses since the first goal are terms by now.
        let since := (ir.hypsSince first g).map fun h => substHyps subst depth (.fvar h)
        return mkAppN (.mvar m) (since ++ args)
  match e with
  | .app f x => return .app (← fill depth f) (← fill depth x)
  | .lam n d b bi => return .lam n (← fill depth d) (← fill (depth + 1) b) bi
  | .forallE n d b bi => return .forallE n (← fill depth d) (← fill (depth + 1) b) bi
  | .letE n t v b nd =>
    return .letE n (← fill depth t) (← fill depth v) (← fill (depth + 1) b) nd
  | .mdata d b => return .mdata d (← fill depth b)
  | .proj s i b => return .proj s i (← fill depth b)
  | _ => return substHyps subst depth e

/--
The proof of `g` according to `proof?`, with the goals in it replaced by their proofs in turn.
`none` if `g` has no proof (or, in a malformed IR, its proof mentions itself). A goal further
down without a proof also gives `none` if `strict`, and otherwise stays a metavariable.

The proof of a goal mentions a goal below it applied to terms for the hypotheses introduced in
between (`fun x => ?g1 x`; `hypsSince`), so the lower goal's proof is put in with those terms
substituted for the hypotheses. A goal that stays a metavariable is applied the same way,
counting from `g`.
-/
def fillGoal (ir : ProofIR) (proof? : MVarId → Option Expr) (strict : Bool) (g : MVarId) :
    Option Expr := do
  fillTopDown ir proof? strict g g {g} {} 0 (← proof? g)

/-- The proof term that the assignments from `g` down add up to, or `none` if a goal on the way
is unassigned (or, in a malformed IR, mentions itself). -/
def proofTerm? (ir : ProofIR) (g : MVarId := ir.rootGoal) : Option Expr :=
  ir.fillGoal (fun g => (ir.goal? g >>= (·.assignment?)).map (·.proof)) (strict := true) g

/-- Names for the goals that do not depend on Lean's internal ids: `g0`, `g1`, … in `goalOrder`.
Pass it to `withContext` to have goals printed as `?g0`, `?g1`, …. -/
def goalNumbering (ir : ProofIR) : MVarId → Name :=
  let index : Std.HashMap MVarId Nat := .ofList (ir.goalOrder.toList.zipIdx)
  fun g => match index[g]? with
    | some i => .mkSimple s!"g{i}"
    | none => .mkSimple "✗"

end Distill.Informalizer.IR.ProofIR
