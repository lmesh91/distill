import Distill.Informalizer.Present.Basic

/-!
# Presenting proof terms

`goalSteps` presents the proof of a goal of the Proof IR as mathematical steps, by reading the
term the goal was assigned:

| Term | Steps |
| --- | --- |
| `fun x hx => t` | "by the definition of …, we need to show ∀ …" if the goal is not a `∀` as written; "let `x`", "suppose …"; then `t` |
| `have h : P := v; t` | `P` derived from what `v` uses, or claimed with the proof `v` is; then `t` |
| `h a b`, `thm a b` | the conclusion, because of the fact `h` or the theorem `thm`, the facts among `a b`, and the definitions Lean unfolded to make them fit |
| … with goals among `a b` | "it suffices to show …", then the proofs of those goals, as branches if there are several |
| `match h with \| ⟨a, b⟩ => t` | the parts of `h` as facts; then `t` |
| `?g a b` | the proof of the goal `?g`, after "we need to show …" if its target is written differently |
| `sorry`, a goal without a proof | a gap |

Nothing here depends on which tactic wrote the term, so a term written by hand and one built by
tactics are presented alike, and a new tactic is presented as soon as it has a recognizer.

A node whose tactic is not known to say everything in its term (`simp`, an unknown tactic) is
shown as the Lean it is, and so is any term that cannot be read; presentation goes on with the
goals it leaves.
-/

namespace Distill.Informalizer.Present

open Lean Meta
open Distill.Informalizer.IR

/-- Whether the term a tactic with this detail assigned says all the tactic did, so that the
term can be presented in its place. Automation and unknown tactics are not: their terms are not
written to be read. -/
def transparent : TacticDetail → Bool
  | .intro .. | .destruct .. | .have .. | .term .. | .constructor => true
  | _ => false

private def applySubst (e : Expr) : PresentM Expr := do
  let subst := (← read).subst
  if subst.isEmpty then return e
  return e.replaceFVars (subst.map (mkFVar ·.1)) (subst.map (·.2))

private def gapStep (goal : Expr) (cause : GapCause) : PresentM ProofStep := do
  mkStep (.gap (← newClaim goal) cause)

/-- Whether proving something by `v` takes a proof of its own, rather than one step. -/
private def needsBlock (v : Expr) : MetaM Bool := do
  let v := v.consumeMData
  if v.isLambda || v.isLet || v.hasSorry || v.hasExprMVar then return true
  return (← matchMatcherApp? v (alsoCasesOn := true)).isSome

/-- Runs `x`, a block of its own: what it establishes on the way is not cited after it. -/
private def inBlock (x : PresentM α) : PresentM α := do
  let facts := (← get).facts
  try x finally modify fun s => { s with facts }

/-- The nodes of the last step of `steps` that has any, for a step added after them. -/
private partial def lastNodes (steps : Array ProofStep) : Array Nat :=
  steps.foldr (init := #[]) fun s acc =>
    if !acc.isEmpty then acc else
    let nested := match s.kind with
      | .claim _ b => lastNodes b.steps
      | .split _ bs => bs.foldr (init := #[]) fun b acc =>
          if !acc.isEmpty then acc else lastNodes b.body.steps
      | _ => #[]
    if !nested.isEmpty then nested else s.origin.nodes

private def dedup [BEq α] (xs : Array α) : Array α :=
  xs.foldl (init := #[]) fun acc x => if acc.contains x then acc else acc.push x

/-- The case distinction `e` is, if it is one on a single term. -/
private def elimination? (e : Expr) : MetaM (Option Elimination) := do
  let some app ← matchMatcherApp? e (alsoCasesOn := true) | return none
  let some major := app.discrs.back? | return none
  let .const type _ := (← whnf (← inferType major)).getAppFn | return none
  return some {
    type, major, alts := app.alts, altNumParams := app.altNumParams, remaining := app.remaining }

/-- Whether the constant `c` is something a proof cites: a theorem, an axiom, a constructor (an
introduction rule), or a definition that is a proof. Recursors and the functions Lean generates
for `match` are not. -/
private def citable (c : Name) : MetaM Bool := do
  let env ← getEnv
  if isAuxRecursor env c || isMatcherCore env c || isNoConfusion env c then return false
  match env.find? c with
  | some (.thmInfo _) | some (.axiomInfo _) | some (.ctorInfo _) => return true
  | some (.defnInfo info) | some (.opaqueInfo { toConstantVal := info, .. }) =>
    forallTelescope info.type fun _ body => isProp body
  | _ => return false

/-- `steps` with the Lean proof of `m` carried by the last of them. -/
private def finishedBy (m : MVarId) (steps : Array ProofStep) : Array ProofStep := Id.run do
  let some i := steps.findIdx? (·.evidence.any (·.goal == m)) | return steps
  if i + 1 == steps.size then return steps
  let own := steps[i]!.evidence.filter (·.goal == m)
  let steps := steps.modify i fun s => { s with evidence := s.evidence.filter (·.goal != m) }
  steps.modify (steps.size - 1) fun s => { s with evidence := s.evidence ++ own }

mutual

/-- The steps that prove `goal` by the term `e`. Throws if `e` has a shape it cannot read. -/
partial def explain (e goal : Expr) : PresentM (Array ProofStep) := do
  let e := (← instantiateMVars e).consumeMData
  let goal ← tidy goal
  if let some synthetic := sorry? e then
    return #[← gapStep goal (if synthetic then .error else .sorry)]
  if let some (m, args) ← goalApp? e then return ← enterGoal m args goal
  -- A hole Lean could not fill (`_`), which it reports as an error.
  if e.getAppFn.isMVar then return #[← gapStep goal .error]
  -- `@id t p`, how `show t` writes a type ascription: `p` proves the goal restated as `t`.
  if e.isAppOfArity ``id 2 then
    let inner := e.appArg!
    if (← goalApp? inner).isSome then return ← explain inner goal
    let t ← tidy e.appFn!.appArg!
    let some defs ← sameUpToDefinitions goal t | throwError "{t} is not {goal}"
    let pre ← if defs.isEmpty then pure #[] else
      pure #[(← mkStep (.suffices (← newClaim t)) (defs.map .definition) .inferred).about goal]
    return pre ++ (← explain inner t)
  match e with
  | .lam n _ b bi => explainFun n b bi goal
  | .letE n t v b _ => explainHave n t v b goal
  | _ =>
    -- `(fun h => t) v` is how some tactics write `have h := v; t`.
    if let .lam n t b _ := e.getAppFn then
      if e.getAppNumArgs == 1 then return ← explainHave n t e.appArg! b goal
      return ← explain e.headBeta goal
    if let some elim ← elimination? e then return ← explainElimination e elim goal
    if let .const c _ := e.getAppFn then
      for handler in termHandlerAttribute.getValues (← getEnv) c do
        if let some steps ← handler (mkExplainer ()) { term := e, goal } then return steps
    return (← justify e goal (conclude := true)).1

/-- `fun x => b`: the goal is a `∀` or an implication, by definition if not as written. -/
private partial def explainFun (n : Name) (b : Expr) (bi : BinderInfo) (goal : Expr) :
    PresentM (Array ProofStep) := do
  let mut pre := #[]
  let mut goal := goal
  unless goal.isForall do
    let (unfolded, defs) ← whnfWithDefinitions goal
    unless unfolded.isForall do throwError "a function proves {goal}"
    goal := unfolded
    pre := #[(← mkStep (.suffices (← newClaim goal)) (defs.map .definition) .inferred).about goal]
  let .forallE _ d body _ := goal | unreachable!
  openBinder n d b (bi := bi) fun x b => do
    let intro ← introduce x d
    return mergeIntroductions (pre ++ #[intro] ++ (← explain b (body.instantiate1 x)))

/-- `have n : t := v; b`. -/
private partial def explainHave (n : Name) (t v b goal : Expr) : PresentM (Array ProofStep) := do
  unless ← isProp t do throwError "a definition inside a proof"
  let (steps, fact) ← premise v t
  openBinder n t b fun x b => do
    modify fun s => { s with facts := s.facts.insert x.fvarId! fact }
    return steps ++ (← explain b goal)

/-- The steps that make `prop`, which `v` proves, a fact: a claim with its proof if `v` is a proof
of its own, and what `establish` gives otherwise. -/
private partial def premise (v prop : Expr) : PresentM (Array ProofStep × Fact) := do
  let v := (← instantiateMVars v).consumeMData
  if ← needsBlock v then
    let c ← newClaim prop
    let steps ← inBlock (explain v prop)
    return (#[← mkStep (.claim c { goal? := some c, steps })], { id := c.id, prop })
  establish v prop

/-- The steps that make `prop` a fact by the term `v`, which has no goals or binders in it. None
if `v` is a fact that already reads `prop`. -/
partial def establish (v prop : Expr) : PresentM (Array ProofStep × Fact) := do
  let v := (← instantiateMVars v).consumeMData
  let prop ← tidy prop
  if let .fvar h := v then
    let some f ← fact? h | throwError "{v} is not a fact of the presentation"
    match ← sameUpToDefinitions f.prop prop with
    | some #[] => return (#[], f)
    | some defs =>
      -- Said once: the next use of `h` as `prop` cites this step.
      let c ← newClaim prop
      modify fun s => { s with facts := s.facts.insert h { f with id := c.id, prop } }
      let step ← mkStep (.derive #[c]) (#[.fact f.id] ++ defs.map .definition)
      return (#[step], { id := c.id, prop })
    | none => throwError "{v} does not prove {prop}"
  -- A part of a known structure is known with it: `h.left` for `h : P ∧ Q` cites `h`.
  if let .const c _ := v.getAppFn then
    if let some info := (← getEnv).getProjectionFnInfo? c then
      if v.getAppNumArgs == info.numParams + 1 then
        let (steps, f) ← premise v.appArg! (← whnf (← inferType v.appArg!))
        return (steps, { f with prop })
  justify v prop (conclude := false)

/--
The steps for an application `head a₁ … aₙ` that proves `goal`. The head is a fact or a theorem.
Arguments that are proofs are facts it is applied to, established first if they are terms
themselves; arguments that are goals are what remains to be shown, and then the step is "it
suffices to show", followed by their proofs. Where Lean unfolded a definition to make a type
fit, the definition is one of the reasons.

`conclude` says whether `goal` is the goal of the block or a fact on the way.
-/
partial def justify (e goal : Expr) (conclude : Bool) : PresentM (Array ProofStep × Fact) := do
  let fn := e.getAppFn
  let mut reasons : Array Reason := #[]
  let mut defs : Array Name := #[]
  let mut pre : Array ProofStep := #[]
  let mut remaining : Array (MVarId × Array Expr × Expr) := #[]
  let mut objects : Array MathExpr := #[]
  let mut head? : Option Name := none
  let mut type : Expr := default
  -- What each premise proved on the way has to prove, as the function's type says.
  let mut premises : Array Expr := #[]
  match fn with
  | .fvar h =>
    let some f ← fact? h | throwError "{fn} is not a fact of the presentation"
    reasons := #[.fact f.id]
    type := f.prop
  | .const c _ =>
    unless ← citable c do throwError "{c} is not a theorem"
    head? := some c
    type ← inferType fn
  | .proj _ _ a =>
    -- The structure as Lean reads it: `x ∈ A ∧ x ∈ B` for `a : x ∈ A ∩ B`.
    let structure_ ← whnf (← inferType a)
    let (steps, f) ← premise a structure_
    premises := premises.push structure_
    pre := steps
    reasons := #[.fact f.id]
    type ← inferType fn
  | _ => throwError "cannot read {e}"
  unless ← isProp goal do throwError "{goal} is not a proposition"
  for a in e.getAppArgs do
    type ← tidy type
    unless type.isForall do
      let (unfolded, ds) ← whnfWithDefinitions type
      unless unfolded.isForall do throwError "{fn} is applied to too many arguments"
      type := unfolded
      defs := defs ++ ds
    let .forallE _ d b _ := type | unreachable!
    if ← isProp d then
      match ← goalApp? a with
      | some (m, args) => remaining := remaining.push (m, args, d)
      | none =>
        let (steps, f) ← premise a d
        premises := premises.push d
        pre := pre ++ steps
        reasons := reasons.push (.fact f.id)
    else if (← isClass? d).isNone then
      objects := objects.push { expr := a }
    type := b.instantiate1 a
  let some ds ← sameUpToDefinitions type goal | throwError "{e} does not prove {goal}"
  let all := (head?.map (Reason.lemma · objects)).toArray ++ reasons ++
    (dedup (defs ++ ds)).map .definition
  let c ← newClaim goal
  let fact : Fact := { id := c.id, prop := goal }
  if remaining.isEmpty then
    -- The goal rests on one fact that takes a proof of its own: say first what it takes, then
    -- prove it ("By extensionality, it suffices to show that …").
    if conclude then
      if let #[{ kind := .claim claim body, id, origin, evidence, .. }] := pre then
        let rest := all.filter fun | .fact f _ => f != claim.id | _ => true
        let step := (← mkStep (.suffices claim) rest).about goal premises
        return (#[{ step with
          evidence := evidence ++ step.evidence
          origin := { step.origin with nodes := origin.nodes ++ step.origin.nodes } }] ++
          body.steps, fact)
    let kind := if conclude then StepKind.conclude c else .derive #[c]
    let step ← mkStep kind all
    return (pre.push (if conclude then step.about goal else step), fact)
  unless conclude do throwError "a fact on the way leaves a goal"
  let ir := (← read).ir
  -- In the order the proof goes on to prove them.
  let position (m : MVarId) := ((ir.goal? m >>= (·.assignment?)).map (·.node)).getD ir.nodes.size
  remaining := remaining.insertionSort fun a b => position a.1 < position b.1
  let targets := remaining.map (·.2.2)
  let all_ := targets.pop.foldr mkAnd targets.back!
  -- `⟨?_, ?_⟩` for `P ∧ Q` leaves `P` and `Q`: nothing to announce.
  let announced := !((← tidy goal) == all_)
  let mut steps := pre
  if announced then
    steps := steps.push ((← mkStep (.suffices (← newClaim all_)) all).about goal targets)
  if let #[(m, args, target)] := remaining then
    return (steps ++ (← enterGoal m args target), fact)
  let mut branches : Array Branch := #[]
  for (m, args, target) in remaining do
    let goal ← newClaim target
    let body ← inBlock (enterGoal m args target)
    branches := branches.push {
      tag := ((ir.goal? m).map (·.tag)).getD .anonymous, body := { goal? := some goal, steps := body } }
  steps := steps.push (← mkStep (.split .conjunction branches))
  if announced then
    let last := lastNodes steps
    let step := (← mkStep (.conclude c) #[] .synthesized).about goal
    steps := steps.push { step with origin := { step.origin with nodes := last } }
  return (steps, fact)

/-- `match major with | ⟨a, b⟩ => t`, `T.casesOn major fun a b => t`: the parts of `major` are
facts (or objects it gives) from here on. A distinction of several cases is left to the handler
of the type. -/
private partial def explainElimination (e : Expr) (elim : Elimination) (goal : Expr) :
    PresentM (Array ProofStep) := do
  for handler in termHandlerAttribute.getValues (← getEnv) elim.type do
    if let some steps ← handler (mkExplainer ()) { term := e, goal, elimination? := some elim } then
      return steps
  let (#[alt], #[arity]) := (elim.alts, elim.altNumParams)
    | throwError "a case distinction on {elim.type}"
  let structure_ ← whnf (← inferType elim.major)
  -- How the reader knows the major premise, and what it takes to read it as the structure.
  let major := (← instantiateMVars elim.major).consumeMData
  let (pre, known, defs) ← do
    let direct? ← match major with
      | .fvar h => fact? h
      | _ => pure none
    match direct? with
    | some f =>
      let some defs ← sameUpToDefinitions f.prop structure_
        | throwError "{major} is not a {elim.type}"
      pure (#[], f, defs)
    | none =>
      let (steps, f) ← premise major structure_
      pure (steps, f, #[])
  let rec fields (i : Nat) (alt : Expr) (xs : Array Expr) : PresentM (Array ProofStep) := do
    if i < arity then
      let .lam n t b bi := (← instantiateMVars alt).consumeMData
        | throwError "an alternative that does not bind its fields"
      return ← openBinder n t b (bi := bi) fun x b => fields (i + 1) b (xs.push x)
    let mut objects : Array MathObject := #[]
    let mut facts : Array Claim := #[]
    for x in xs do
      let decl ← x.fvarId!.getDecl
      let type ← tidy (← inferType x)
      if ← isProp type then
        facts := facts.push (← newClaim type (some x.fvarId!))
      else
        objects := objects.push { fvar := x.fvarId!, name := decl.userName, type := { expr := type } }
    let mut steps := pre
    if objects.isEmpty && defs.isEmpty then
      -- Nothing new to say: `P ∧ Q` is known, and `P` and `Q` are cited as it.
      for c in facts do
        modify fun s => { s with
          facts := s.facts.insert c.hyp?.get! { id := known.id, prop := c.prop.expr } }
    else
      for c in facts do registerFact c.hyp?.get! c
      let reasons := #[Reason.fact known.id] ++ defs.map .definition
      let kind := if objects.isEmpty then StepKind.derive facts else .obtain objects facts
      steps := steps.push (← mkStep kind reasons)
    return steps ++ (← explain (mkAppN alt elim.remaining).headBeta goal)
  fields 0 alt #[]

/-- The proof goes on with the goal `m`, here applied to `args`: the terms its new hypotheses
stand for. If the goal reads differently from what the reader was told to expect (`show`), that
is said first. -/
private partial def enterGoal (m : MVarId) (args : Array Expr) (goal : Expr) :
    PresentM (Array ProofStep) := do
  let ctx ← read
  let some gi := ctx.ir.goal? m | throwError "unknown goal"
  let new := match ctx.goal? with
    | some g => ctx.ir.hypsSince g m
    | none => ctx.ir.newHyps m
  unless args.size == new.size do throwError "a goal applied to something else than its hypotheses"
  let mut subst := ctx.subst
  for h in new, a in args do
    unless a == .fvar h do
      subst := subst.filter (·.1 != h) |>.push (h, a)
  withReader ({ · with subst }) do
    let target ← tidy (← applySubst gi.target)
    let mut steps := #[]
    match ← sameUpToDefinitions goal target with
    | none => throwError "the goal {target} is not {goal}"
    | some defs =>
      unless defs.isEmpty do
        steps := #[(← mkStep (.suffices (← newClaim target)) (defs.map .definition) .inferred).about goal]
    return steps ++ (← goalSteps m target)

/-- The steps that prove the goal `m`, whose target reads `target` here. Never throws: what
cannot be read is shown as the Lean it is. -/
partial def goalSteps (m : MVarId) (target : Expr) : PresentM (Array ProofStep) := do
  let ctx ← read
  let ir := ctx.ir
  let some a := ir.goal? m >>= (·.assignment?)
    | -- A step written for this goal that left it unproved failed.
      let failed := ir.nodes.any fun n => n.role == .surface && n.goalsBefore[0]? == some m
      return #[← gapStep target (if failed then .error else .unfinished)]
  modify fun s => { s with pending := s.pending.push { goal := m, proof := a.proof } }
  let owner := ctx.owner[a.node]?.getD none
  if let some o := owner then
    unless (← get).used.contains o || (← get).pendingNodes.contains o do
      modify fun s => { s with pendingNodes := s.pendingNodes.push o }
  let node? := owner <|> (ir.nestedSurface a.node)[0]?.map (·.id) <|> ctx.node?
  withReader ({ · with goal? := some m, node? }) do
    let proof ← applySubst (← instantiateMVars a.proof)
    let readable := (sorry? proof).isSome || match owner with
      | some o => transparent ir.nodes[o]!.detail
      | none => true
    if readable then
      let saved ← get
      let steps? ← tryCatchRuntimeEx (some <$> explain proof target) fun _ => do
        set saved
        pure none
      if let some steps := steps? then
        -- A goal proved outright is proved by the step that finishes it, which carries its proof.
        if proof.hasExprMVar then return steps
        return finishedBy m steps
    asLean m owner (owner.getD a.node)

/-- The goals below `m` that the node `owner` did not prove itself, with the proofs of the ones
it did recorded as evidence. -/
private partial def leftBy (m : MVarId) (owner : Option Nat) : PresentM (Array MVarId) := do
  let ctx ← read
  let mut out := #[]
  for sub in ctx.ir.subgoals m do
    match ctx.ir.goal? sub >>= (·.assignment?) with
    | some a =>
      if owner.isSome && (ctx.owner[a.node]?.getD none) == owner then
        modify fun s => { s with pending := s.pending.push { goal := sub, proof := a.proof } }
        out := out ++ (← leftBy sub owner)
      else out := out.push sub
    | none => out := out.push sub
  return out

/-- The goal `m` as the Lean step that proves or reduces it (node `n`), followed by the proofs
of the goals that step leaves. -/
private partial def asLean (m : MVarId) (owner : Option Nat) (n : Nat) :
    PresentM (Array ProofStep) := do
  let ctx ← read
  let ir := ctx.ir
  let left ← leftBy m owner
  let mut steps := #[]
  unless (← get).reported.contains n do
    modify fun s => { s with reported := s.reported.insert n }
    steps := steps.push (← mkStep (.untranslated n) #[] .direct)
  -- What the step added to the context of a goal it leaves.
  let continueWith (g : MVarId) : PresentM (Array ProofStep) := do
    let mut intro := #[]
    let mut facts := #[]
    for h in ir.hypsSince m g do
      let some hi := ir.hyp? h | continue
      if ← isProp hi.type then
        let c ← newClaim hi.type (some h)
        registerFact h c
        facts := facts.push c
      else
        intro := intro.push (← introduce (.fvar h) hi.type)
    unless facts.isEmpty do
      intro := intro.push (← mkStep (.derive facts) #[.automation n])
    let target := ((ir.goal? g).map (·.target)).getD default
    return intro ++ (← goalSteps g (← applySubst target))
  match left with
  | #[] => return steps
  | #[g] => return steps ++ (← continueWith g)
  | gs =>
    let mut branches : Array Branch := #[]
    for g in gs do
      let some gi := ir.goal? g | continue
      let goal ← newClaim (← applySubst gi.target)
      branches := branches.push {
        tag := gi.tag, body := { goal? := some goal, steps := ← inBlock (continueWith g) } }
    return steps.push (← mkStep (.split .conjunction branches))

private partial def mkExplainer (_ : Unit) : Explainer := { explain, establish }

end

end Distill.Informalizer.Present
