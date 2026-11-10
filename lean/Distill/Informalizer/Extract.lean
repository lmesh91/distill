import Distill.Informalizer.Extract.Tree
import Distill.Informalizer.Extract.Goals
import Distill.Informalizer.Extract.Recognizers

/-!
# Extraction: InfoTree ⟶ Proof IR

`extractProofs` turns the InfoTree of an elaborated command into one `ProofIR` per proof in it: a
declaration body that proves a proposition, or a `by` block elsewhere. Parts of the tree that asynchronous elaboration left as holes
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
Which nodes left nothing in the proof. Lean records the nodes of a tactic that failed or was
backtracked over, so whatever combinator caused that, the signs are in the node's states:

* it, or a `by` block in it, assigned a goal that is unassigned in the state execution continued
  from, which is the next sibling's or else the parent's final state, or that has another
  assignment in the end (a tactic can redo a goal after undoing what this node did);
* it is a tactic that changed nothing, which is also how a tactic that failed before changing
  anything looks (`skip`, `done`, … are no loss);
* it is nested in such a node.

A `by` block is not in sequence with its siblings: terms choose when to run them.
-/
private def discardedNodes (raw : RawProof) (tactics : Parser.SyntaxNodeKindSet) :
    MetaM (Array Bool) := do
  let next : Std.HashMap Nat Nat := raw.nodes.foldl (init := {}) fun m n =>
    (n.children.zip (n.children.extract 1)).foldl (init := m) fun m (c, s) => m.insert c s
  let isBlock (n : RawNode) := n.info.stx.isOfKind ``Lean.Parser.Term.byTactic
  -- Whether a node and the nodes in it changed nothing, and the goals of the `by` blocks in it.
  let mut quiet := Array.replicate raw.nodes.size false
  let mut blocks : Array (Array MVarId) := Array.replicate raw.nodes.size #[]
  for i in (List.range raw.nodes.size).reverse do
    let some n := raw.nodes[i]? | continue
    blocks := blocks.set! i (n.children.flatMap (blocks[·]!) ++
      if isBlock n then n.info.goalsBefore.toArray else #[])
    quiet := quiet.set! i (n.info.goalsAfter == n.info.goalsBefore &&
      !n.info.goalsBefore.any (assignedIn n.info) && n.children.all (quiet[·]!))
  let mut out : Array Bool := #[]
  for (n, i) in raw.nodes.zipIdx do
    let some parent := n.parent? >>= (raw.nodes[·]?)
      | out := out.push false; continue
    let sibling? := if isBlock n then none else next[i]? >>= (raw.nodes[·]?)
    let continued := (sibling?.map (·.info.mctxBefore)).getD parent.info.mctxAfter
    let undone ← (n.info.goalsBefore.toArray ++ blocks[i]!).anyM fun g => do
      if !assignedIn n.info g then return false
      return (assignmentIn continued g).isNone || !(← assignmentSurvives n.info g)
    -- Not tokens (`;`), which are nodes too, or `by` blocks, whose goals nothing else reports.
    let inert := quiet[i]! && !isBlock n && (tactics.contains n.info.stx.getKind || !n.children.isEmpty)
    out := out.push (n.parent?.any (out[·]!) || undone || inert)
  return out

/-- Syntax a user wrote as a tactic. -/
private def isUserTactic (tactics : Parser.SyntaxNodeKindSet) (stx : Syntax) : Bool :=
  stx.getHeadInfo matches .original .. && tactics.contains stx.getKind

/-- An assignment that only passes the goal on: `case` renaming hypotheses, or error recovery
closing a goal whose tactic failed. -/
private def passesGoalOn (v : Expr) : Bool :=
  v.consumeMData.isMVar || v.isSyntheticSorry

/--
Which nodes only pass goals to user-written tactics nested in them: sequences, `·`, `case`,
`t <;> s`, `first`, `try`, …, whether built in or from a library. Going by the InfoTree, such a
node does no work itself, its nodes that do are all user-written, and it has at least one. What
sets `· intro x` apart from the macro `intro x hx` is that the nodes doing the work in the macro
are its expansion, which the user did not write.
-/
private def delegatingNodes (raw : RawProof) (tactics : Parser.SyntaxNodeKindSet)
    (discarded : Array Bool) : Array Bool := Id.run do
  let mut out := Array.replicate raw.nodes.size false
  for i in (List.range raw.nodes.size).reverse do
    let some n := raw.nodes[i]? | continue
    let kids := n.children.filterMap fun c => raw.nodes[c]?.map fun k =>
      (k, isUserTactic tactics k.info.stx || out[c]!, discarded[c]!)
    let live := kids.filter (!·.2.2)
    let ownWork := !n.terms.isEmpty || n.info.goalsBefore.any fun g =>
      assignedIn n.info g && !live.any (assignedIn ·.1.info g) &&
        !(assignmentIn n.info.mctxAfter g).any passesGoalOn
    let kidsWork := live.any fun (k, written, _) =>
      !written && k.info.goalsBefore.any (assignedIn k.info)
    -- A user-written tactic that failed still counts: `· exact wrong` is a `·` like any other.
    out := out.set! i (!ownWork && !kidsWork && kids.any (·.2.1))
  return out

/--
The role of a node. `delegates` is `delegatingNodes`'s answer for it and `insideSurface` is
whether some ancestor is a surface node.

* User-written tactics are surface nodes, also when nested in another tactic (the tactics of a
  `have h : t := by …` block, the right side of `t <;> s`), unless they only delegate.
* Nodes that only delegate are structural when the user wrote them, or when no surface node
  encloses them.
* Everything else inside a surface node ran on its behalf (macro expansions, the parts of
  `intro x y` that introduce one name each) and is inner.
-/
def classify (tactics : Parser.SyntaxNodeKindSet) (stx : Syntax) (delegates insideSurface : Bool) :
    NodeRole :=
  let original := stx.getHeadInfo matches .original ..
  if isUserTactic tactics stx && !delegates then .surface
  else if delegates && (original || !insideSurface) then .structural
  else if insideSurface then .inner
  else .structural

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

/-- Builds the Proof IR of one proof. -/
def extractProof (raw : RawProof) : IO ProofIR := do
  let some root := raw.nodes[0]? | throw <| .userError "empty proof"
  let some rootGoal := root.info.goalsBefore.head?
    | throw <| .userError "`by` block without a goal"
  -- Assignments only accumulate, so the context after the root has them all (except those of
  -- failed alternatives, which were backtracked).
  let ctx := { root.ctx with mctx := root.info.mctxAfter }
  ctx.runMetaM {} do
    let tactics := tacticKinds (← getEnv)
    let discarded ← discardedNodes raw tactics
    let delegates := delegatingNodes raw tactics discarded
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
    let hyps := inferLineage live goals (← buildHyps goals raw.aliases)
    let mut nodes : Array TacticNode := #[]
    -- Whether some ancestor of the node is a surface node; parents come before children.
    let mut insideSurfaceOf : Array Bool := #[]
    for h : i in [0:raw.nodes.size] do
      let n := raw.nodes[i]
      -- A term proof's node stands for no tactic: the blocks in it are like any other `by`.
      let insideSurface := n.parent?.any fun p =>
        (nodes[p]!.role == .surface && !(raw.isTermProof && p == 0)) || insideSurfaceOf[p]!
      insideSurfaceOf := insideSurfaceOf.push insideSurface
      -- A failed alternative is inner, and says nothing about the goals of the final proof.
      let isTermRoot := i == 0 && raw.isTermProof
      let role := if isTermRoot then .surface else if discarded[i]! then .inner
        else classify tactics n.info.stx delegates[i]! insideSurface
      let input := { info := n.info, goals : RecognizerInput }
      let detail ← if discarded[i]! then pure .unrecognized
        -- A term proof reads as `exact`, or as `refine` when `by` blocks fill in parts of it.
        else if isTermRoot then
          let mode := if n.info.goalsAfter.isEmpty then .exact else .refine
          pure ((← recognizeTerm mode input).getD .unrecognized)
        else recognize input
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

/-- The Proof IR of every proof in an InfoTree. -/
def extractProofs (tree : InfoTree) : IO (Array ProofIR) := do
  (← collectProofs tree).mapM extractProof

end Distill.Informalizer.Extract
