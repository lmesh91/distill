import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation
import Distill.Informalizer.Present

/-!
# Verifying a presentation

Presenting and normalizing a proof must not change what it says. `verify` checks a
`PresentedDecl` against the Proof IR it came from, with Lean's type checker:

* **Statement.** The presented statement, `∀ objects and their properties, hypotheses →
  conclusion` in the order the presentation introduces them, is the original statement: the same
  term, definitionally equal, or equivalent by a proof of `original ↔ presented` that `verify`
  builds and checks. The proof reorders the binders, and uses the proofs recorded in
  `MathExpr.history` where a hypothesis or the conclusion was restated.
* **Proof.** The `Evidence` of the steps adds up to a term that proves the presented statement.
  Only the sum is checked: which step carries which piece is not, and neither is that every
  tactic of the proof has a step.
* **Structure.** What rendering reads besides expressions is right: objects in a group are
  described the same way, and objects and the declaration have their own names and label.

This is to the Presentation IR what `checkProofTerm` is to the Proof IR. The pipeline runs it on
every presentation before rendering it (`Distill.Informalizer.informalize`), so that the English
a reader sees was written from a presentation that says what the Lean says.

An unfinished proof is not a wrong presentation: `verify` accepts a presentation that leaves
open what the Lean proof leaves open, and nothing else.

What is not supported: restating the *type* of an object other than definitionally.
-/

namespace Distill.Informalizer

open Lean Meta
open Distill.Informalizer.IR

/-- How the presented statement relates to the original one. -/
inductive StatementCheck where
  /-- The same term. -/
  | identical
  | defEq
  /-- `proof : original ↔ presented` type-checks. -/
  | equivalent (proof : Expr)
  | failed (reason : String)
  deriving Inhabited

/-- Whether the steps prove the presented statement. -/
inductive ProofCheck where
  /-- `proof` has no holes and its type is the presented statement. -/
  | complete (proof : Expr)
  /-- The proof type-checks but cannot be closed into a term of the statement, because it calls
  itself. -/
  | recursive
  /-- Some goal is not proved by any step, because the Lean proof does not prove it either. -/
  | incomplete (reason : String)
  | failed (reason : String)
  deriving Inhabited

structure Verification where
  /-- The statement of the Proof IR: `∀ binders, conclusion`. -/
  original : Expr
  presented : Expr
  statement : StatementCheck
  proof : ProofCheck
  deriving Inhabited

/-- Why the presentation is not one to show, if it is not. -/
def Verification.failure? (v : Verification) : Option String :=
  match v.statement, v.proof with
  | .failed reason, _ => some reason
  | _, .failed reason => some reason
  | _, _ => none

/-- Whether the presentation says what the proof says. -/
def Verification.ok (v : Verification) : Bool := v.failure?.isNone

def StatementCheck.describe : StatementCheck → String
  | .identical => "identical to the original statement"
  | .defEq => "definitionally equal to the original statement"
  | .equivalent _ => "equivalent to the original statement (proof checked)"
  | .failed reason => s!"NOT VERIFIED: {reason}"

def ProofCheck.describe : ProofCheck → String
  | .complete _ => "the steps rebuild a proof of the presented statement"
  | .recursive => "the steps type-check (not compared: the proof is recursive)"
  | .incomplete reason => s!"incomplete ({reason})"
  | .failed reason => s!"NOT VERIFIED: {reason}"

/-- The evidence of the steps of a block and of the blocks nested in them. The `expansion?` of
a step is another account of the same step, so it is left out. -/
partial def blockEvidence (b : Block) : Array Evidence :=
  b.steps.flatMap fun s => s.evidence ++ match s.kind with
    | .claim _ proof => blockEvidence proof
    | .split _ branches => branches.flatMap (blockEvidence ·.body)
    | _ => #[]

/-- Something the presented statement binds. -/
private structure Binder where
  /-- The Lean variable it presents. -/
  fvar? : Option FVarId
  name : Name
  type : MathExpr
  value? : Option Expr := none
  binderInfo : BinderInfo := .default
  deriving Inhabited

/-- What the presented statement binds, in order: each object followed by its properties, then
the hypotheses. -/
private def presentedBinders (d : PresentedDecl) : MetaM (Array Binder) := do
  let claim (c : Claim) : MetaM Binder := do
    let name ← match c.hyp? with
      | some h => pure ((← getLCtx).find? h |>.map (·.userName) |>.getD `h)
      | none => pure `h
    return { fvar? := c.hyp?, name, type := c.prop }
  let mut out := #[]
  for g in d.objects do
    for o in g.objects do
      out := out.push {
        fvar? := some o.fvar, name := o.name, type := o.type, value? := o.value?.map (·.expr)
        binderInfo := o.binderInfo }
      out := out ++ (← o.properties.mapM claim)
  return out ++ (← d.hypotheses.mapM claim)

/-- Runs `k` with a new local variable for every binder, typed as the presentation states it.
`k` gets the Lean variables that are presented, the new variables that present them, and all the
new variables. -/
private partial def withBinders (bs : Array Binder)
    (k : (olds news locals : Array Expr) → MetaM α) (i := 0)
    (olds news locals : Array Expr := #[]) : MetaM α := do
  let some b := bs[i]? | k olds news locals
  let next (x : Expr) : MetaM α :=
    match b.fvar? with
    | some f => withBinders bs k (i + 1) (olds.push (.fvar f)) (news.push x) (locals.push x)
    | none => withBinders bs k (i + 1) olds news (locals.push x)
  let type := b.type.expr.replaceFVars olds news
  match b.value? with
  | some v => withLetDecl b.name type (v.replaceFVars olds news) next
  | none => withLocalDecl b.name b.binderInfo type next

/-- The expression each change in `m.history` produced: the next change's `before`, or `m.expr`
for the last one. -/
private def afterOf (m : MathExpr) (i : Nat) : Expr :=
  (m.history[i + 1]?.map (·.before)).getD m.expr

/-- Checks every change in `m.history`: one with a proof proves `before = after` or
`before ↔ after`, and one without is a definitional equality. -/
private def checkHistory (m : MathExpr) : MetaM Unit := do
  for h : i in [0:m.history.size] do
    let r := m.history[i]
    let after := afterOf m i
    match r.proof? with
    | none =>
      unless ← withNewMCtxDepth (isDefEq r.before after) do
        throwError "{r.rule} restated {r.before} as {after}, which is not definitionally equal, without a proof"
    | some p =>
      check p
      let p ← instantiateMVars p
      if p.hasSorry || p.hasExprMVar then
        throwError "{r.rule} restated {r.before} as {after}, but its proof is not finished"
      let type ← inferType p
      let proves ← withNewMCtxDepth <|
        isDefEq type (mkIff r.before after) <||> isDefEq type (← mkEq r.before after)
      unless proves do
        throwError "{r.rule} restated {r.before} as {after}, but its proof is of {type}"

/-- If `m` was restated with proofs: the expression it started as, and a proof that it is
equivalent to `m.expr`, composed from the proofs in `m.history`. Changes without a proof are
definitional, so they need no step. -/
private def restatementIff? (m : MathExpr) : MetaM (Option (Expr × Expr)) := do
  let some first := m.history[0]?.map (·.before) | return none
  let mut acc? : Option Expr := none
  for h : i in [0:m.history.size] do
    let r := m.history[i]
    let some p := r.proof? | continue
    let after := afterOf m i
    let step ←
      if (← whnf (← inferType p)).isAppOfArity ``Iff 2 then pure p
      else mkAppM ``Iff.of_eq #[p]
    acc? := some <| match acc? with
      | none => step
      | some acc => mkApp5 (mkConst ``Iff.trans) first r.before after acc step
  return acc?.map (first, ·)

/-- `x : a` as a proof of `b`, or the other way around, given `iff : a ↔ b`. -/
private def transport (forward : Bool) (a b iff x : Expr) : Expr :=
  mkApp4 (mkConst (if forward then ``Iff.mp else ``Iff.mpr)) a b iff x

/-- A proof of `original ↔ presented`: each direction takes the binders of one statement and
passes them to a proof of the other. -/
private def equivalenceProof (ir : ProofIR) (d : PresentedDecl) (bs : Array Binder)
    (original presented : Expr) : MetaM Expr := do
  let binders := ir.statement.binders
  let isLet (h : FVarId) := (ir.hyp? h).any (·.value?.isSome)
  let conclusion? ← restatementIff? d.conclusion.prop
  let mp ← withLocalDeclD `h original fun h => withBinders bs fun olds news locals => do
    let mut args := #[]
    for b in binders do
      if isLet b then continue
      let some i := bs.findIdx? (·.fvar? == some b)
        | throwError "{(ir.hyp? b).map (·.userName) |>.getD b.name} is missing from the presented statement"
      let some j := olds.idxOf? (.fvar b) | unreachable!
      args := args.push <| match ← restatementIff? bs[i]!.type with
        | some (first, iff) =>
          let r (e : Expr) := e.replaceFVars olds news
          transport false (r first) (r bs[i]!.type.expr) (r iff) news[j]!
        | none => news[j]!
    let mut body := mkAppN h args
    if let some (first, iff) := conclusion? then
      let r (e : Expr) := e.replaceFVars olds news
      body := transport true (r first) (r d.conclusion.prop.expr) (r iff) body
    mkLambdaFVars (#[h] ++ locals) body
  let mpr ← withLocalDeclD `h presented fun h => do
    let mut args := #[]
    for b in bs do
      if b.value?.isSome then continue
      let some f := b.fvar?
        | throwError "the presented statement assumes something that is not a hypothesis"
      unless binders.contains f do
        throwError "the presented statement binds {b.name}, which the original does not"
      args := args.push <| match ← restatementIff? b.type with
        | some (first, iff) => transport true first b.type.expr iff (.fvar f)
        | none => .fvar f
    let mut body := mkAppN h args
    if let some (first, iff) := conclusion? then
      body := transport false first d.conclusion.prop.expr iff body
    mkLambdaFVars (#[h] ++ binders.map .fvar) body
  let proof := mkApp4 (mkConst ``Iff.intro) original presented mp mpr
  check proof
  unless ← isDefEq (← inferType proof) (mkIff original presented) do
    throwError "the proof built for the equivalence proves something else"
  return proof

private def checkStatement (ir : ProofIR) (d : PresentedDecl) (bs : Array Binder)
    (original presented : Expr) : MetaM StatementCheck := do
  if original == presented then return .identical
  try
    for b in bs do checkHistory b.type
    checkHistory d.conclusion.prop
    if ← withNewMCtxDepth (isDefEq original presented) then return .defEq
    let proof ← instantiateMVars (← equivalenceProof ir d bs original presented)
    if proof.hasSorry || proof.hasExprMVar then
      return .failed "the proof of the equivalence is not finished"
    return .equivalent proof
  catch e => return .failed (← e.toMessageData.toString)

/-- What `render` reads that the statement's term does not show: `none` if the groups, names
and labels of `d` are right. -/
private def structureProblem? (ir : ProofIR) (d : PresentedDecl) : MetaM (Option String) := do
  if d.decl != ir.decl || d.role != declRole ir.decl then
    return some "the presentation is labelled as another declaration"
  for g in d.objects do
    let some first := g.objects[0]? | return some "a group has no objects"
    -- An object's description with the object itself abstracted.
    let key (o : MathObject) : MetaM (Expr × Array Expr) := do
      return (← instantiateMVars o.type.expr, ← o.properties.mapM fun p =>
        return (← instantiateMVars p.prop.expr).abstract #[.fvar o.fvar])
    for o in g.objects do
      if let some decl := (← getLCtx).find? o.fvar then
        unless decl.userName == o.name do
          return some s!"{decl.userName} is presented under the name {o.name}"
      if g.objects.size > 1 then
        if o.value?.isSome || o.binderInfo.isInstImplicit then
          return some s!"{o.name} cannot be introduced in a group"
        unless (← key o) == (← key first) do
          return some s!"{o.name} is grouped with {first.name}, which is described differently"
  return none

private def checkProof (ir : ProofIR) (d : PresentedDecl) (original presented : Expr)
    (statement : StatementCheck) : MetaM ProofCheck := do
  let mut evidence : Std.HashMap MVarId Expr := {}
  for e in blockEvidence d.proof do
    if evidence.contains e.goal then
      return .failed s!"two steps prove ?{ir.goalNumbering e.goal}"
    evidence := evidence.insert e.goal e.proof
  -- What the Lean proof itself leaves open, which the steps may leave open too.
  let leanProof (g : MVarId) := (ir.goal? g >>= (·.assignment?)).map (·.proof)
  let leanFrom (g : MVarId) : MetaM (Option Expr) :=
    (ir.fillGoal leanProof (strict := false) g).mapM (instantiateMVars ·)
  let lean? ← leanFrom d.rootGoal
  let openGoals (e : Expr) := (e.collectMVars {}).result.filter ir.goals.contains
  -- A goal Lean gave up on (a tactic failed, and elaboration went on with `sorry`) is open too.
  let givenUp (g : MVarId) := (leanProof g).any fun p =>
    (p.consumeMData.getLambdaBody.consumeMData.getAppFn).isConstOf ``sorryAx
  -- A step may use `sorry` only where the Lean proof does.
  for (g, e) in evidence do
    if e.hasSorry && !(← leanFrom g).any (·.hasSorry) then
      return .failed s!"the step for ?{ir.goalNumbering g} uses `sorry`, which the Lean proof does not"
  let some term := ir.fillGoal (evidence[·]?) (strict := false) d.rootGoal
    | return if lean?.isNone then .incomplete "no step proves the statement"
        else .failed "no step proves the statement, which the Lean proof does"
  let term ← instantiateMVars term
  let unproved := openGoals term
  let mut incomplete? : Option String := none
  if !unproved.isEmpty then
    let names (gs : Array MVarId) := ", ".intercalate (gs.toList.map (s!"?{ir.goalNumbering ·}"))
    let leanOpen := (lean?.map openGoals).getD #[]
    let lost := unproved.filter fun g => !leanOpen.contains g && !givenUp g
    unless lost.isEmpty do
      return .failed s!"no step proves {names lost}, which the Lean proof does"
    incomplete? := some s!"no step proves {names unproved}"
  else if term.hasMVar then
    unless lean?.any (·.hasMVar) do
      return .failed "the steps leave a hole that the Lean proof fills"
    incomplete? := some "a hole is unfilled"
  else if term.hasSorry then
    incomplete? := some "the proof uses `sorry`"
  let binders := ir.statement.binders
  -- What there is of an unfinished proof is type-checked like a finished one, with each hole
  -- as a `sorry` of its type, where it has one.
  let mut term := term
  if let some reason := incomplete? then
    try
      term ← Meta.transform term (pre := fun e => do
        if e.getAppFn.isMVar then return .done (← mkSorry (← inferType e) (synthetic := true))
        return .continue)
    catch _ =>
      -- A goal that a failed tactic left behind may not have a type that fits its place.
      return .incomplete reason
  try
    -- Lean compiles recursive calls away, so there is no closed term to compare.
    if term.hasAnyFVar (ir.recursiveHyps.contains ·) then
      check (← mkLambdaFVars ((binders ++ ir.recursiveHyps).map .fvar) term)
      return (incomplete?.map .incomplete).getD .recursive
    let closed ← mkLambdaFVars (binders.map .fvar) term
    let (proof, statement) ← match statement with
      | .equivalent iff => pure (transport true original presented iff closed, presented)
      | .identical | .defEq => pure (closed, presented)
      | .failed _ => pure (closed, original)
    check proof
    unless ← isDefEq (← inferType proof) statement do
      return .failed "the steps prove a different statement"
    if statement == original && !(statement == presented) then
      return .failed "the steps prove the original statement, which the presented one was not shown to match"
    return (incomplete?.map .incomplete).getD (.complete proof)
  catch e => return .failed (← e.toMessageData.toString)

/-- Checks `d`, the presentation of `ir`, against `ir`. Runs inside `ir.withContext`. -/
def verify (ir : ProofIR) (d : PresentedDecl) : MetaM Verification := do
  -- A statement that did not elaborate has holes nothing declares.
  let stated := ir.statement.conclusion :: ir.statement.binders.toList.filterMap fun b =>
    (ir.hyp? b).map (·.type)
  if ← stated.anyM fun e => return (← instantiateMVars e).hasExprMVar then
    let reason := "the statement has holes"
    return {
      original := ir.statement.conclusion, presented := d.conclusion.prop.expr
      statement := .failed reason, proof := .failed reason }
  let original ← instantiateMVars
    (← mkForallFVars (ir.statement.binders.map .fvar) ir.statement.conclusion)
  let bs ← presentedBinders d
  let presented ← withBinders bs fun olds news locals => do
    instantiateMVars (← mkForallFVars locals (d.conclusion.prop.expr.replaceFVars olds news))
  let mut statement ← checkStatement ir d bs original presented
  if let some problem ← structureProblem? ir d then
    statement := .failed problem
  -- The Proof IR's statement is what the checks above compare with, so it has to be the
  -- declaration's.
  if ir.isDeclBody then
    if let some info := (← getEnv).find? ir.decl then
      unless ← withNewMCtxDepth (isDefEq info.type original) do
        statement := .failed "the Proof IR does not have the statement of the declaration"
  return { original, presented, statement, proof := ← checkProof ir d original presented statement }

end Distill.Informalizer
