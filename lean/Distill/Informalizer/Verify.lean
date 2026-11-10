import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation

/-!
# Verifying a presentation

Presenting and normalizing a proof must not change what it says. `verify` checks a
`PresentedDecl` against the Proof IR it came from, with Lean's type checker:

* **Statement.** The presented statement, `∀ objects and their properties, hypotheses →
  conclusion` in the order the presentation introduces them, is the original statement: the same
  term, definitionally equal, or equivalent by a proof of `original ↔ presented` that `verify`
  builds and checks. The proof reorders the binders, and uses the proofs recorded in
  `MathExpr.history` where a hypothesis or the conclusion was restated.
* **Proof.** The `Evidence` of the steps adds up to a term without holes, and that term proves
  the presented statement.

This is to the Presentation IR what `checkProofTerm` is to the Proof IR. It is meant for tests
and debugging (`#informalize` prints the result), not for every translation.

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
  /-- Some goal is not proved by any step, as in an unfinished proof. -/
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
      let type ← inferType p
      let proves ← isDefEq type (mkIff r.before after) <||> isDefEq type (← mkEq r.before after)
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
    return .equivalent (← equivalenceProof ir d bs original presented)
  catch e => return .failed (← e.toMessageData.toString)

private def checkProof (ir : ProofIR) (d : PresentedDecl) (original presented : Expr)
    (statement : StatementCheck) : MetaM ProofCheck := do
  let mut evidence : Std.HashMap MVarId Expr := {}
  for e in blockEvidence d.proof do
    if evidence.contains e.goal then
      return .failed s!"two steps prove {← ppExpr (.mvar e.goal)}"
    evidence := evidence.insert e.goal e.proof
  let some term := ir.fillGoal (evidence[·]?) (strict := false) d.rootGoal
    | return .incomplete "no step proves the statement"
  let term ← instantiateMVars term
  let unproved := (term.collectMVars {}).result.filter ir.goals.contains
  unless unproved.isEmpty do
    let goals ← unproved.toList.mapM fun g => return toString (← ppExpr (.mvar g))
    return .incomplete s!"no step proves {", ".intercalate goals}"
  if term.hasMVar then return .incomplete "a hole is unfilled"
  if term.hasSorry then return .incomplete "the proof uses `sorry`"
  let binders := ir.statement.binders
  try
    -- Lean compiles recursive calls away, so there is no closed term to compare.
    if term.hasAnyFVar (ir.recursiveHyps.contains ·) then
      check (← mkLambdaFVars ((binders ++ ir.recursiveHyps).map .fvar) term)
      return .recursive
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
    return .complete proof
  catch e => return .failed (← e.toMessageData.toString)

/-- Checks `d`, the presentation of `ir`, against `ir`. Runs inside `ir.withContext`. -/
def verify (ir : ProofIR) (d : PresentedDecl) : MetaM Verification := do
  let original ← instantiateMVars
    (← mkForallFVars (ir.statement.binders.map .fvar) ir.statement.conclusion)
  let bs ← presentedBinders d
  let presented ← withBinders bs fun olds news locals => do
    instantiateMVars (← mkForallFVars locals (d.conclusion.prop.expr.replaceFVars olds news))
  let mut statement ← checkStatement ir d bs original presented
  -- The Proof IR's statement is what the checks above compare with, so it has to be the
  -- declaration's.
  if ir.isDeclBody then
    if let some info := (← getEnv).find? ir.decl then
      unless ← withNewMCtxDepth (isDefEq info.type original) do
        statement := .failed "the Proof IR does not have the statement of the declaration"
  return { original, presented, statement, proof := ← checkProof ir d original presented statement }

end Distill.Informalizer
