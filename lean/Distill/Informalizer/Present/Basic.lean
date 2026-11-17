import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation
import Distill.Informalizer.Present.Unfold

/-!
# Presenting proof terms: the pieces

A Lean proof is, in the end, a term, and the Proof IR keeps the part of it that every tactic
contributed (`Assignment.proof`). Presentation reads these terms: a `fun` introduces, a `have`
derives, an application uses a fact or a theorem, a goal left open is where the next tactic's
term goes on. This file has what the reading is done with:

* `PresentM`, which hands out step and fact ids and knows which `Claim` every hypothesis is;
* the functions that build steps and introduce variables;
* `TermHandler`, how a library says what a term headed by its own constant, or a case
  distinction on its own type, means (`@[distill_term_handler c]`).

The reading itself is `Distill.Informalizer.Present.Term`.
-/

namespace Distill.Informalizer.Present

open Lean Meta
open Distill.Informalizer.IR

/-- A fact the proof has established, as a hypothesis knows it. -/
structure Fact where
  /-- The `Claim` to cite. -/
  id : Nat
  /-- The proposition as the reader was told it, which can differ from the hypothesis's type by
  unfolding: `x ∈ A ∩ B` for `hx : x ∈ A ∧ x ∈ B`. -/
  prop : Expr
  deriving Inhabited

structure Context where
  ir : ProofIR
  /-- The surface node every node was run for, if any (`owners`). -/
  owner : Array (Option Nat)
  /-- The goal whose proof is being read. -/
  goal? : Option MVarId := none
  /-- The node the steps being built come from. -/
  node? : Option Nat := none
  /-- Hypotheses of the goal being read that stand for a term here (`fillGoal` substitutes the
  same way). -/
  subst : Array (FVarId × Expr) := #[]

structure State where
  nextId : Nat
  facts : Std.HashMap FVarId Fact := {}
  /-- `PresentedDecl.locals`. -/
  locals : Array LocalDecl := #[]
  /-- The Lean proofs of the goals read since the last step; the next step carries them. -/
  pending : Array Evidence := #[]
  /-- The surface nodes whose goals were read since the last step, which no step came from yet:
  the next step comes from them too, so every tactic keeps a place in the text. -/
  pendingNodes : Array Nat := #[]
  /-- The nodes already shown as untranslated. -/
  reported : Std.HashSet Nat := {}
  /-- The surface nodes some step came from. -/
  used : Std.HashSet Nat := {}

abbrev PresentM := ReaderT Context (StateRefT State MetaM)

def freshId : PresentM Nat :=
  modifyGet fun s => (s.nextId, { s with nextId := s.nextId + 1 })

def newClaim (prop : Expr) (hyp? : Option FVarId := none) : PresentM Claim :=
  return { id := ← freshId, prop := { expr := prop }, hyp? }

/-- A step that comes from the node being read, carrying the evidence gathered since the last
one. -/
def mkStep (kind : StepKind) (reasons : Array Reason := #[])
    (relation : OriginRelation := .partOf) : PresentM ProofStep := do
  let id ← freshId
  let evidence ← modifyGet fun s => (s.pending, { s with pending := #[] })
  let waiting ← modifyGet fun s => (s.pendingNodes, { s with pendingNodes := #[] })
  let nodes := waiting.foldl (init := (← read).node?.toArray) fun ns n =>
    if ns.contains n then ns else ns.push n
  modify fun s => { s with used := nodes.foldl (·.insert ·) s.used }
  return { id, kind, reasons, origin := { relation, nodes }, evidence }

/-- Records that the hypothesis `h` is the fact `c`. -/
def registerFact (h : FVarId) (c : Claim) : PresentM Unit :=
  modify fun s => { s with facts := s.facts.insert h { id := c.id, prop := c.prop.expr } }

def fact? (h : FVarId) : PresentM (Option Fact) :=
  return (← get).facts[h]?

/-- Whether `e` is an application of a goal of the Proof IR. -/
def goalApp? (e : Expr) : PresentM (Option (MVarId × Array Expr)) := do
  let .mvar m := e.consumeMData.getAppFn | return none
  if (← read).ir.goals.contains m then return some (m, e.consumeMData.getAppArgs) else return none

/-- Whether `e` is `sorry`; the flag says whether Lean put it there after an error. -/
def sorry? (e : Expr) : Option Bool :=
  let e := e.consumeMData
  if e.isAppOf ``sorryAx then some e.isSyntheticSorry else none

/-- The hypothesis of the Proof IR that `x` stands for in `body`: the one a goal in `body` is
passed `x` for. -/
private def hypFor? (body x : Expr) : PresentM (Option FVarId) := do
  let ctx ← read
  let some g := ctx.goal? | return none
  let found := body.find? fun e =>
    match e.getAppFn with
    | .mvar m => ctx.ir.goals.contains m && e.getAppArgs.contains x
    | _ => false
  let some app := found | return none
  let some i := app.getAppArgs.idxOf? x | return none
  return (ctx.ir.hypsSince g app.getAppFn.mvarId!)[i]?

/--
Opens the binder of `fun n : type => body` (or of a `have`), and runs `k` with the variable and
the body about it. The variable is the hypothesis of the Proof IR that the binder becomes, when
a goal under it has one; otherwise a new variable, recorded in `PresentedDecl.locals`.
-/
def openBinder (n : Name) (type body : Expr) (k : Expr → Expr → PresentM α)
    (bi : BinderInfo := .default) : PresentM α := do
  let probe := mkFVar (← mkFreshFVarId)
  match ← hypFor? (body.instantiate1 probe) probe with
  | some h => k (.fvar h) (body.instantiate1 (.fvar h))
  | none =>
    withLocalDecl n bi type fun x => do
      let decl ← x.fvarId!.getDecl
      modify fun s => { s with locals := s.locals.push decl }
      k x (body.instantiate1 x)

/-- The steps that introduce `x`, as what the reader was told to expect (`stated`): "let `x`" for
an object, "suppose `P`" for a proof, which becomes a fact. -/
def introduce (x : Expr) (stated : Expr) : PresentM ProofStep := do
  let h := x.fvarId!
  if ← isProp stated then
    let c ← newClaim stated (some h)
    registerFact h c
    mkStep (.assume #[c] .forImplication)
  else
    let decl ← h.getDecl
    mkStep (.fix #[{
      fvar := h, name := decl.userName, type := { expr := stated }
      value? := decl.value?.map ({ expr := · }) }])

/-- "Let `x`. Suppose `x ∈ A`." as "Let `x ∈ A`.": a membership assumed right after its element
is introduced becomes a property of the element. -/
def mergeIntroductions (steps : Array ProofStep) : Array ProofStep := Id.run do
  let mut out : Array ProofStep := #[]
  for s in steps do
    if let (some prev, .assume #[c] .forImplication) := (out.back?, s.kind) then
      if let (.fix os, some (set, .fvar x)) := (prev.kind, membership? c.prop.expr) then
        if let some o := os.back? then
          if o.fvar == x && o.properties.isEmpty && !set.containsFVar x then
            let o := { o with properties := #[c] }
            out := out.pop.push { prev with
              kind := .fix (os.pop.push o), evidence := prev.evidence ++ s.evidence }
            continue
    out := out.push s
  return out

/-! ## Handlers -/

/-- A case distinction in a proof term: `match major with …`, or `T.casesOn major …`. -/
structure Elimination where
  /-- The inductive type of `major`. -/
  type : Name
  major : Expr
  /-- One function per constructor, from the constructor's fields to the proof in that case. -/
  alts : Array Expr
  /-- How many fields each alternative binds. -/
  altNumParams : Array Nat
  /-- What every alternative is applied to after its fields: `cases` passes the equation between
  `major` and the constructor this way. -/
  remaining : Array Expr := #[]
  deriving Inhabited

/-- What a handler is asked to present. -/
structure TermInput where
  term : Expr
  /-- What `term` proves, as the reader was last told it. -/
  goal : Expr
  /-- Set when the handler is asked as the handler of an inductive type, for a case distinction
  on it. -/
  elimination? : Option Elimination := none

/-- The reading of terms, for handlers to continue with the parts of their term. -/
structure Explainer where
  /-- The steps that prove `goal` by `term`, ending in its conclusion. -/
  explain : (term goal : Expr) → PresentM (Array ProofStep)
  /-- The steps that establish `prop` by `term`, and the fact they establish. No steps if the
  term is a fact already. -/
  establish : (term prop : Expr) → PresentM (Array ProofStep × Fact)
  deriving Inhabited

/-- What a term means, for terms headed by one constant, or for case distinctions on one
inductive type. `none` if the handler does not handle this term. -/
abbrev TermHandler := Explainer → TermInput → PresentM (Option (Array ProofStep))

private def constKey (_ : Bool) (stx : Syntax) : AttrM Name := do
  let id ← Attribute.Builtin.getIdent stx
  Elab.realizeGlobalConstNoOverloadWithInfo id

/-- `@[distill_term_handler c] def h : TermHandler := …` has Distill present proof terms headed by
the constant `c` with `h`, or, if `c` is an inductive type, case distinctions on `c`. -/
unsafe initialize termHandlerAttribute : KeyedDeclsAttribute TermHandler ←
  KeyedDeclsAttribute.init {
    builtinName := `builtin_distill_term_handler
    name := `distill_term_handler
    descr := "how Distill presents proof terms headed by a constant"
    valueTypeName := ``TermHandler
    evalKey := constKey }

end Distill.Informalizer.Present
