import Distill.Informalizer.IR.Common

/-!
# Proof IR

The Proof IR records how a Lean proof was constructed. One `ProofIR` describes one
proof, usually the whole body of a declaration. It keeps only what translation needs and cannot cheaply recompute; everything
else (parent links, context differences, the hypotheses and constants a proof uses) is
derived on demand by the helpers at the end of this file.

The goal and hypothesis tables are maps because they are only ever looked up by id; where
order matters, it is stored explicitly (`GoalInfo.context`, `Statement.binders`).

It is a hybrid of three views over the same ids:

* **Execution order**: `ProofIR.nodes` lists every tactic node in the order Lean ran it (a
  pre-order walk of the InfoTree); `TacticNode.children` gives the nesting. A node's id is
  its index in this array.
* **Goal graph**: `ProofIR.goals` maps every goal's `MVarId` to its `GoalInfo`, which
  records its parent goal and the node and partial proof term that assigned it.
* **Hypothesis table**: `ProofIR.hyps` maps every local hypothesis or variable's `FVarId` to
  its `HypInfo`, with a link when a tactic replaced one hypothesis with another.

## Generic data and tactic details

Every node has the same generic data: syntax, goals before and after, children. On top of
that, `TacticNode.detail` is the tactic-specific part, and it is what translation works
from. A *recognizer* for a tactic family fills it in during extraction, because only then
are the InfoTree, the metavariable contexts and trace output available. Details are
*resolved*: they name the hypotheses, goals and intermediate states involved, not the raw
syntax arguments, so a translation handler rarely needs to look anything else up.

A tactic without a recognizer gets `.unrecognized`. Translation can still handle it
generically from the goal graph: the goals it closed, the hypotheses it added, and the
proof term it produced.

## Extending the IR

A project that defines new tactics has these routes, from least to most work:

1. **Nothing.** If the tactic is a macro, its expansion is in the InfoTree as the node's
   `.inner` children, and an `.unrecognized` macro node is translated through them: the
   recognizers of the tactics it expands to apply. Otherwise generic handling from the goal
   graph applies.
2. **A recognizer that produces an existing `TacticDetail` variant**, e.g. a new
   destructuring tactic producing `.destruct`. Translation then needs no change.
3. **A recognizer that produces `.custom`** with the project's own data (any type with a
   `TypeName` instance, stored as a `Dynamic`, as Lean's own `CustomInfo` does), together
   with a translation handler that reads it.

Recognizers are registered by syntax kind with `@[distill_recognizer kind]`, in the style of
`@[tactic]`, so extensions live in the project that defines the tactic. Handlers will be too.
-/

namespace Distill.Informalizer.IR

open Lean

/-! ## Statement and hypotheses -/

/-- What the proof proves: the declaration's statement when the proof is its body. -/
structure Statement where
  /-- The binders before the colon, in order. Their names, types and binder info are in the
  hypothesis table. -/
  binders : Array FVarId
  /-- The target of the initial goal. It may still contain `∀`/`→`, which the proof
  introduces with tactics; those are not binders of the statement. -/
  conclusion : Expr
  deriving Inhabited, Repr

/-- Records that a hypothesis replaced an earlier one, e.g. after `rw [...] at h` or the
substitution performed by an `rfl` pattern. Lean creates a new `FVarId` in these cases, and
sometimes also for later hypotheses that did not change. -/
structure HypLineage where
  previous : FVarId
  /-- Whether Lean recorded the link (an `FVarAliasInfo` node). If not, Distill inferred it,
  e.g. from the user name and the tactic's `at` location, and it may be wrong. -/
  fromAlias : Bool
  deriving Inhabited, Repr

/-- A local hypothesis or variable. -/
structure HypInfo where
  fvarId : FVarId
  userName : Name
  type : Expr
  /-- For `let`/`set` variables. -/
  value? : Option Expr := none
  /-- Only meaningful for statement binders. -/
  binderInfo : BinderInfo := .default
  replaces? : Option HypLineage := none
  /-- A reference to the declaration being defined, which a recursive proof calls, or to a
  `where`/`let rec` helper, whose proof is a `ProofIR` of its own. Not in any goal's context.
  `userName` is its name. -/
  isRecursive : Bool := false
  deriving Inhabited, Repr

/-! ## Goals -/

/-- The assignment of a goal. -/
structure Assignment where
  /-- The innermost node that made the assignment, e.g. the `refine` inside a `have`. -/
  node : Nat
  /-- The term assigned to the goal, one level deep: goals in it are left as metavariables
  (they are the goal's subgoals) rather than replaced by their own assignments. A subgoal
  occurs applied to the terms its new hypotheses (`ProofIR.newHyps`) stand for, in order
  (`fun x => ?g1 x`). Metavariables that are not goals (e.g. implicit arguments solved by
  unification) are instantiated. -/
  proof : Expr
  deriving Inhabited, Repr

/-- A proof obligation. In Lean, a goal is a metavariable whose type and local context never
change; a tactic "changes the goal" by assigning it and creating new goals.

The table holds every goal some node reported. Goals a tactic creates and closes internally are
not in it: their proofs are part of the assignment of the reported goal they belong to.
Implicit arguments solved by unification are not goals. -/
structure GoalInfo where
  mvarId : MVarId
  /-- Case tag where the goal first appears, e.g. `mp`, `mpr`, `left`, `h`. Often hygienic
  (`body._@…`) for internal goals. -/
  tag : Name
  target : Expr
  /-- Visible hypotheses in the goal's local context, in order. -/
  context : Array FVarId
  /-- The goal whose assignment contains this one; `none` for the root goal. -/
  parent? : Option MVarId := none
  /-- `none` only in an unfinished proof. -/
  assignment? : Option Assignment := none
  deriving Inhabited, Repr

/-! ## Tactic details -/

/-- One branch produced by a destructuring tactic. -/
structure DestructBranch where
  /-- The goal of this branch; its case tag names the constructor. -/
  goal : MVarId
  /-- Objects and hypotheses the branch adds, in order (for induction, including the
  induction hypotheses). -/
  newHyps : Array FVarId
  /-- Variables eliminated by an `rfl` pattern, with the value they were replaced by
  (`obtain ⟨r, rfl⟩ := hp` gives `p ↦ 2 * r`). -/
  substituted : Array (FVarId × Expr) := #[]
  deriving Inhabited, Repr

/-- One rewrite rule applied at one location. -/
structure RewriteStep where
  /-- The elaborated rule, e.g. `Rat.num_div_den q`. -/
  rule : Expr
  /-- `← e` -/
  reverse : Bool
  /-- The hypothesis rewritten (before the rewrite), or `none` for the goal. -/
  hyp? : Option FVarId
  /-- The rewritten statement before and after. Lean emits a node per rule carrying the
  intermediate state, so a sequence of rules gives a chain of statements. -/
  before : Expr
  after : Expr
  node : Nat
  deriving Inhabited, Repr

/-- How a term is used to close or reduce a goal. -/
inductive TermMode where
  /-- `exact e`: `e` closes the goal. -/
  | exact
  /-- `apply e`: unify the conclusion of `e` with the goal; the remaining premises become goals. -/
  | apply
  /-- `refine e`: `?_` holes in `e` become goals. -/
  | refine
  deriving Inhabited, Repr, BEq

/-- What automation reveals about its own reasoning. Each variant says where it comes from. -/
inductive AutomationEvidence where
  /-- A nested tactic node (InfoTree) that shows part of the reasoning, e.g. `linarith`'s
  `ring1` goal, which is the linear-combination certificate as an equation. -/
  | internalNode (node : Nat)
  /-- A rewrite step, from `trace.Meta.Tactic.simp.rewrite` or reconstructed from the proof
  term. -/
  | rewrite (rule : Name) (before after : Expr)
  /-- A fact the procedure asserted, e.g. from `trace.grind.lia.assert`. -/
  | fact (e : Expr)
  /-- A "Try this" suggestion, e.g. `simp only [...]` from `set_option tactic.simp.trace`. -/
  | suggestion (stx : Syntax)
  /-- Trace output Distill could not parse. -/
  | trace (cls : Name) (text : String)
  deriving Inhabited, Repr

/-- The tactic-specific content of a node, resolved against the goal graph and the
hypothesis table. Translation handlers dispatch on it. Each variant covers a family of
tactics; the node's syntax says which member ran. -/
inductive TacticDetail where
  /-- `intro`, `intros`, `rintro x y`: the hypotheses introduced, in order. -/
  | intro (hyps : Array FVarId)
  /-- `rcases`, `obtain`, `rintro ⟨…⟩`, `cases`. `source?` is the destructured term, `none`
  when it was the goal's premise (`rintro`). -/
  | destruct (source? : Option Expr) (branches : Array DestructBranch)
  /-- `induction`. Branches as for `destruct`. -/
  | induction (target : Expr) (branches : Array DestructBranch)
  /-- `have h : t := e` (`term? := e`) or `have h : t := by tac` (`proofGoal?` is the goal
  `tac` proves). `hyp` is the new hypothesis, which carries `t`. -/
  | «have» (hyp : FVarId) (term? : Option Expr) (proofGoal? : Option MVarId)
  /-- `exact e`, `apply e`, `refine e`. `e` is elaborated; the goals it leaves are the node's
  `goalsAfter`. -/
  | term (mode : TermMode) (e : Expr)
  /-- `rw`, `rewrite`, `rwa`, in the order applied. -/
  | rewrite (steps : Array RewriteStep)
  /-- `use e₁, …, eₙ`, `exists`: the witnesses and parts supplied. -/
  | witnesses (terms : Array Expr)
  /-- `constructor`: the new goals, with their case tags, are the node's `goalsAfter`. -/
  | constructor
  /-- `simp`, `linarith`, `lia`, `norm_num`, `exact_mod_cast`, …: closes or changes goals
  without explaining itself in the goal graph. `hints` are the terms the user supplied
  (`simp [h₁, h₂]`, `simpa using e`). -/
  | automation (hints : Array Expr) (evidence : Array AutomationEvidence)
  /-- Data from a recognizer defined outside Distill. A translation handler registered for
  the same syntax kind reads it with `Dynamic.get?`. -/
  | custom (data : Dynamic)
  /-- No recognizer ran. Translation falls back on the goal graph. -/
  | unrecognized
  deriving Inhabited, Repr

/-! ## Tactic nodes -/

/-- Distill's classification of a node, from the InfoTree's shape and the syntax origin. It
decides which nodes translation starts from. -/
inductive NodeRole where
  /-- Written by the user (also a term proof's first node). Under a combinator (`t <;> s`, `all_goals s`) each run of `s` on
  a goal is its own surface node, with the same syntax. -/
  | surface
  /-- Run on behalf of its parent: a macro expansion (`have` ⇒ `refine_lift` ⇒ `refine`),
  automation internals (`ring1` inside `linarith`), a discharger, or a tactic that left
  nothing in the proof (a failed `try` alternative, `skip`). The parent's recognizer decides what, if anything, to use. -/
  | inner
  /-- Only passes goals to user-written tactics nested in it: tactic sequences, `·`, `case`,
  `focus`, `first`, `try` and other combinators. Translation looks through it. -/
  | structural
  deriving Inhabited, Repr, BEq

/-- One `TacticInfo` node of the InfoTree. -/
structure TacticNode where
  /-- The node's index in `ProofIR.nodes`. -/
  id : Nat
  stx : Syntax
  /-- The elaborator or macro that ran, e.g. `Lean.Elab.Tactic.evalIntro`. -/
  elaborator : Name
  origin : SyntaxOrigin
  role : NodeRole
  goalsBefore : Array MVarId
  goalsAfter : Array MVarId
  /-- Ids of the nodes nested in this one, in execution order. -/
  children : Array Nat
  /-- Child indices from the root of the declaration's InfoTree to this node. InfoTree nodes
  have no identity of their own, so this path is the node's address. -/
  infoTreePath : Array Nat
  detail : TacticDetail := .unrecognized
  deriving Inhabited, Repr

/-! ## Declaration -/

/-- The Proof IR of one proof: a declaration body that proves a proposition, or an outermost `by`
block elsewhere. A body that is a term has a first node like a top-level `exact` or `refine`, with
its `by` blocks as the goals it leaves. -/
structure ProofIR where
  /-- The declaration the proof is part of. -/
  decl : Name
  /-- Whether the proof is the declaration's whole body, so that `statement` is the declaration's
  statement. Otherwise (a `by` in a signature or in a term that is not a proof) `statement` is
  only the goal of the block, and its binders include whatever the surrounding term bound. -/
  isDeclBody : Bool
  statement : Statement
  /-- The goal the whole proof proves; its context is the statement binders. -/
  rootGoal : MVarId
  /-- All tactic nodes in execution order. `nodes[i].id = i`. -/
  nodes : Array TacticNode
  /-- Every goal some node reported (see `GoalInfo`). -/
  goals : Std.HashMap MVarId GoalInfo
  /-- Every hypothesis and variable of the statement and the proof. -/
  hyps : Std.HashMap FVarId HypInfo
  deriving Inhabited, Repr

namespace ProofIR

def node? (ir : ProofIR) (id : Nat) : Option TacticNode :=
  ir.nodes[id]?

def goal? (ir : ProofIR) (g : MVarId) : Option GoalInfo :=
  ir.goals[g]?

def hyp? (ir : ProofIR) (h : FVarId) : Option HypInfo :=
  ir.hyps[h]?

/-- Nodes the user wrote, in execution order. -/
def surfaceNodes (ir : ProofIR) : Array TacticNode :=
  ir.nodes.filter (·.role == .surface)

/-- The surface nodes nested in node `id` without another surface node in between, looking
through inner and structural nodes: the tactics of a `have h : t := by …` block, the
alternative of `first | … | …` that succeeded, the tactics under `·`. -/
partial def nestedSurface (ir : ProofIR) (id : Nat) : Array TacticNode :=
  let children := (ir.node? id).map (·.children) |>.getD #[]
  children.foldl (init := #[]) fun acc c =>
    match ir.node? c with
    | some n => if n.role == .surface then acc.push n else acc ++ ir.nestedSurface c
    | none => acc

/-- The node `id` is nested in. -/
def parent? (ir : ProofIR) (id : Nat) : Option TacticNode :=
  ir.nodes.find? (·.children.contains id)

/-- The goals occurring in `g`'s assignment. -/
def subgoals (ir : ProofIR) (g : MVarId) : Array MVarId :=
  match ir.goal? g >>= (·.assignment?) with
  | some a => (a.proof.collectMVars {}).result.filter ir.goals.contains
  | none => #[]

/-- Hypotheses in `g`'s context that its parent goal does not have. -/
def newHyps (ir : ProofIR) (g : MVarId) : Array FVarId :=
  match ir.goal? g with
  | none => #[]
  | some gi =>
    let parentCtx := (gi.parent? >>= ir.goal?).map (·.context) |>.getD #[]
    gi.context.filter (!parentCtx.contains ·)

end ProofIR

end Distill.Informalizer.IR
