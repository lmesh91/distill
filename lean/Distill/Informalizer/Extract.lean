import Distill.Informalizer.Extract.Tree
import Distill.Informalizer.Extract.Goals
import Distill.Informalizer.Extract.Recognizers

/-!
# Extraction: InfoTree ⟶ Proof IR

`extractProofs` turns the InfoTree of an elaborated command into one `ProofIR` per tactic proof
(outermost `by` block) in it. Parts of the tree that asynchronous elaboration left as holes
must be substituted first (`InfoState.substituteLazy`, which the language server's snapshots
already do). It works from InfoTrees alone, so it can run wherever they are
available: in the language server on a document's snapshots, or after elaborating a source
string with `Distill.Informalizer.Extract.Frontend`.

Extraction never fails because of the proof it is given. Unfinished proofs, `sorry` and
elaboration errors give goals without an assignment or with an error term, and tactics without
a recognizer give `.unrecognized` nodes.
-/

namespace Distill.Informalizer.Extract

open Lean Meta Elab
open Distill.Informalizer.IR

/-- Syntax kinds that only pass goals to their children. -/
def structuralKinds : Std.HashSet SyntaxNodeKind := .ofList [
  ``Lean.Parser.Term.byTactic,
  `by,
  ``Lean.Parser.Tactic.tacticSeq,
  ``Lean.Parser.Tactic.tacticSeq1Indented,
  ``Lean.Parser.Tactic.tacticSeqBracketed,
  ``Lean.cdot,
  ``Lean.cdotTk,
  ``Lean.Parser.Tactic.paren,
  ``Lean.Parser.Tactic.focus,
  ``Lean.Parser.Tactic.case,
  ``Lean.Parser.Tactic.«tacticNext_=>_»,
  ``Lean.Parser.Tactic.«tactic_<;>_»,
  ``Lean.Parser.Tactic.allGoals,
  ``Lean.Parser.Tactic.anyGoals,
  ``Lean.Parser.Tactic.withAnnotateState
]

/-- The syntax kinds of the `tactic` category, i.e. things a user can write as a tactic. -/
def tacticKinds (env : Environment) : Parser.SyntaxNodeKindSet :=
  (Parser.parserExtension.getState env).categories.find? `tactic |>.map (·.kinds) |>.getD {}

def SyntaxOrigin.ofSyntax (fileMap : FileMap) (stx : Syntax) : SyntaxOrigin :=
  let span? := do
    let start ← stx.getPos?
    let stop ← stx.getTailPos?
    return { start := fileMap.toPosition start, stop := fileMap.toPosition stop : SourceSpan }
  match stx.getHeadInfo, span? with
  | .original .., some span => .original span
  | .synthetic .., some span => .synthetic span
  | _, _ => .none

/--
The role of a node, given the roles of its ancestors.

* User-written tactics are surface nodes, also when nested in another tactic (the tactics of a
  `have h : t := by …` block, the right side of `t <;> s`).
* Sequences, focusing and similar syntax are structural when the user wrote them, or when no
  surface node encloses them.
* Everything else inside a surface node ran on its behalf (macro expansions, the parts of
  `intro x y` that introduce one name each) and is inner.
-/
def classify (tactics : Parser.SyntaxNodeKindSet) (stx : Syntax) (insideSurface : Bool) : NodeRole :=
  let kind := stx.getKind
  let original := stx.getHeadInfo matches .original ..
  if original && tactics.contains kind && !structuralKinds.contains kind then .surface
  else if structuralKinds.contains kind && (original || !insideSurface) then .structural
  else if insideSurface then .inner
  else .structural

/--
Which nodes ran in a tactic whose effects were undone (`first`, `try`, `repeat`,
`fail_if_success`, `any_goals`, …), so that they are not in the final state. A node is discarded
if it is nested in a discarded node, if it made an assignment that the final state does not
have, or by the combinator's rule: every alternative of `first | t₁ | t₂ | …` but the last, the
last iteration of `repeat`, and everything in `fail_if_success`. The rules also catch failed
tactics that assigned nothing; elsewhere (a failed iteration of `any_goals`) those stay as nodes
that changed nothing. Runs in the final metavariable context.
-/
private def discardedNodes (raw : RawProof) : MetaM (Array Bool) := do
  let mut out : Array Bool := #[]
  for n in raw.nodes do
    let inherited := n.parent?.any fun p =>
      out[p]! || raw.nodes[p]?.any fun pn =>
        let last := pn.children.back? == some out.size
        (pn.info.stx.isOfKind ``Lean.Parser.Tactic.first && !last) ||
        -- `repeat t` runs `t` until it fails.
        (pn.info.stx.isOfKind ``Lean.Parser.Tactic.tacticRepeat_ && last) ||
        -- `fail_if_success t` always undoes `t`.
        pn.info.stx.isOfKind ``Lean.Parser.Tactic.failIfSuccess
    let undone ← n.info.goalsBefore.anyM fun g => do
      return assignedIn n.info g && !(← assignedBy n.info g)
    out := out.push (inherited || undone)
  return out

/-- The goals the live nodes report, in order of first appearance. -/
private def reportedGoals (raw : RawProof) (discarded : Array Bool) : Array MVarId := Id.run do
  let mut seen : Std.HashSet MVarId := {}
  let mut out := #[]
  for (n, i) in raw.nodes.zipIdx do
    if discarded[i]! then continue
    for g in n.info.goalsBefore ++ n.info.goalsAfter do
      unless seen.contains g do
        seen := seen.insert g
        out := out.push g
  return out

/-- Builds the Proof IR of one tactic proof. -/
def extractProof (raw : RawProof) : IO ProofIR := do
  let some root := raw.nodes[0]? | throw <| .userError "empty tactic proof"
  let some rootGoal := root.info.goalsBefore.head?
    | throw <| .userError "`by` block without a goal"
  -- Assignments only accumulate, so the context after the outermost `by` block has them all
  -- (except those of failed alternatives, which were backtracked).
  let ctx := { root.ctx with mctx := root.info.mctxAfter }
  ctx.runMetaM {} do
    let discarded ← discardedNodes raw
    -- A goal of a backtracked alternative is not in the final metavariable context.
    let goalIds := (reportedGoals raw discarded).filter (root.info.mctxAfter.decls.contains ·)
    -- The last node nested in each node: nodes are in pre-order.
    let last := Id.run do
      let mut last := Array.replicate raw.nodes.size 0
      for i in (List.range raw.nodes.size).reverse do
        let lastChild? := raw.nodes[i]?.bind (·.children.back?)
        last := last.set! i ((lastChild?.map (last[·]!)).getD i)
      return last
    let live := (raw.nodes.zipIdx.filter (!discarded[·.2]!)).map fun (n, id) =>
      { id, last := last[id]!, info := n.info, terms := n.terms : NodeFacts }
    let goals ← buildGoals live goalIds
    let hyps := inferLineage live goals (← buildHyps goalIds raw.aliases)
    let tactics := tacticKinds (← getEnv)
    let mut nodes : Array TacticNode := #[]
    -- Whether some ancestor of the node is a surface node; parents come before children.
    let mut insideSurfaceOf : Array Bool := #[]
    for h : i in [0:raw.nodes.size] do
      let n := raw.nodes[i]
      let insideSurface := n.parent?.any fun p => nodes[p]!.role == .surface || insideSurfaceOf[p]!
      insideSurfaceOf := insideSurfaceOf.push insideSurface
      -- A failed alternative is inner, and says nothing about the goals of the final proof.
      let role := if discarded[i]! then .inner else classify tactics n.info.stx insideSurface
      let detail ← if discarded[i]! then pure .unrecognized else recognize { info := n.info, goals }
      nodes := nodes.push {
        id := i
        stx := n.info.stx
        elaborator := n.info.elaborator
        origin := SyntaxOrigin.ofSyntax n.ctx.fileMap n.info.stx
        role
        goalsBefore := n.info.goalsBefore.toArray
        goalsAfter := n.info.goalsAfter.toArray
        children := n.children
        infoTreePath := n.path
        detail }
    let rootInfo := goals[rootGoal]!
    return {
      decl := root.ctx.parentDecl?.getD .anonymous
      isDeclBody := raw.isDeclBody
      statement := { binders := rootInfo.context, conclusion := rootInfo.target }
      rootGoal, nodes, goals, hyps }

/-- The Proof IR of every tactic proof in an InfoTree, in source order. -/
def extractProofs (tree : InfoTree) : IO (Array ProofIR) := do
  (← collectProofs tree).mapM extractProof

end Distill.Informalizer.Extract
