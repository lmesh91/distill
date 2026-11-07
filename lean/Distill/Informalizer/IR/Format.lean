import Distill.Informalizer.IR.Context

/-!
# Printing the Proof IR

A text form of a `ProofIR` for debugging and tests, in the style of the examples in
`docs/informalization/ir.md`. Goals are numbered `?g0`, `?g1`, … in order of first appearance
and hypotheses are shown by name, so the output does not depend on Lean's internal ids.
-/

namespace Distill.Informalizer.IR.ProofIR

open Lean Meta

private def hypLabel (ir : ProofIR) (h : FVarId) : String :=
  match ir.hyp? h with
  | some hi =>
    let n := hi.userName
    if n.hasMacroScopes then s!"{n.eraseMacroScopes}✝" else toString n
  | none => s!"<unknown {h.name}>"

private def hypList (ir : ProofIR) (hs : Array FVarId) : String :=
  "[" ++ ", ".intercalate (hs.map (hypLabel ir)).toList ++ "]"

private def spanStr (lineOffset : Nat) (s : IR.SourceSpan) : String :=
  s!"{s.start.line - lineOffset}:{s.start.column}–{s.stop.line - lineOffset}:{s.stop.column}"

private def originStr (lineOffset : Nat) : IR.SyntaxOrigin → String
  | .original s => spanStr lineOffset s
  | .synthetic s => s!"synthetic {spanStr lineOffset s}"
  | .none => "no position"

/-- The first line of a node's syntax, shortened. -/
private def syntaxStr (stx : Syntax) : String :=
  -- Hygienic names in macro expansions (`h._@.Module._hyg.3`) depend on the module.
  let stx := stx.rewriteBottomUp fun
    -- Only hygienic ones: `hygieneInfo` nodes are identifiers with no source text.
    | .ident info raw n pre =>
      if n.hasMacroScopes then
        let n := n.eraseMacroScopes
        .ident info (toString n).toRawSubstring n pre
      else .ident info raw n pre
    | s => s
  let text := (stx.reprint.getD (toString stx)).trimAscii.toString
  let line := (text.splitOn "\n").head!.trimAscii.toString
  if line.length > 40 then (line.take 39).toString ++ "…" else line

private def roleStr : NodeRole → String
  | .surface => "surface"
  | .inner => "inner"
  | .structural => "structural"

/--
Formats `ir`. Source positions are printed with `lineOffset` subtracted from their line, so that
they can be made relative to the start of the declaration.
-/
def format (ir : ProofIR) (lineOffset : Nat := 0) : MetaM String := do
  let order := ir.goalOrder
  let goalIndex : Std.HashMap MVarId Nat := .ofList (order.toList.zipIdx.map fun (g, i) => (g, i))
  -- Goals of failed alternatives are not in the table.
  let goalLabel (g : MVarId) : String := match goalIndex[g]? with
    | some i => s!"?g{i}"
    | none => "?✗"
  let goals (gs : Array MVarId) : String :=
    if gs.isEmpty then "—" else " ".intercalate (gs.map goalLabel).toList
  ir.withContext (goalName := fun g => .mkSimple (goalLabel g |>.drop 1).toString) do
    -- Expressions are printed in the context of the goal they belong to, so that a name is
    -- only marked inaccessible (`x✝`) if it is shadowed there.
    let pp (g? : Option MVarId) (e : Expr) : MetaM String := do
      let go := do
        let s := (← ppExpr e).pretty (width := 10000)
        -- `have` and `let` break the line after their value whatever the width.
        return " ".intercalate ((s.splitOn "\n").map (·.trimAscii.toString))
      try
        match g? with
        | some g => ir.withGoalContext g go
        | none => go
      catch _ => return toString e
    -- The first goal that has a hypothesis in its context.
    let hypGoal : Std.HashMap FVarId MVarId := order.foldl (init := {}) fun m g =>
      (ir.goals[g]!.context).foldl (init := m) fun m h => if m.contains h then m else m.insert h g
    let detailStr (g? : Option MVarId) : TacticDetail → MetaM String
      | .intro hs => return s!"intro {hypList ir hs}"
      | .have h t? g' => do
        let type ← match ir.hyp? h with
          | some hi => pure s!" : {← pp g? hi.type}"
          | none => pure ""
        let value ← match t?, g' with
          | some t, _ => pure s!" := {← pp g? t}"
          | none, some g => pure s!" := by {goalLabel g}"
          | none, none => pure ""
        return s!"have {hypLabel ir h}{type}{value}"
      | .term .exact e => return s!"exact {← pp g? e}"
      | .term .apply e => return s!"apply {← pp g? e}"
      | .term .refine e => return s!"refine {← pp g? e}"
      | .unrecognized => return "unrecognized"
      | _ => return "<detail>"
    let mut out := s!"ProofIR {ir.decl}{if ir.isDeclBody then "" else "   (a `by` block inside it)"}\n"
    out := out ++ "  statement\n"
    out := out ++ s!"    binders     {hypList ir ir.statement.binders}\n"
    out := out ++ s!"    conclusion  {← pp ir.rootGoal ir.statement.conclusion}\n"
    out := out ++ "  nodes\n"
    -- Indent children under their parent.
    let mut depth : Array Nat := Array.replicate ir.nodes.size 0
    for n in ir.nodes do
      for c in n.children do
        depth := depth.set! c (depth[n.id]! + 1)
    for n in ir.nodes do
      let indent := "".pushn ' ' (4 + 2 * depth[n.id]!)
      -- Only surface nodes are expected to have a detail, so `[unrecognized]` is only shown there.
      let detail ← if n.role != .surface && n.detail matches .unrecognized then pure ""
        else pure s!"   [{← detailStr n.goalsBefore[0]? n.detail}]"
      -- A structural node's syntax starts with its first child's, so show its kind instead.
      let stx := if n.role == .structural then s!"[{n.stx.getKind.eraseMacroScopes}]"
        else s!"`{syntaxStr n.stx}`"
      out := out ++ s!"{indent}#{n.id} {roleStr n.role} {stx}  " ++
        s!"{originStr lineOffset n.origin}  {goals n.goalsBefore} ⟶ {goals n.goalsAfter}{detail}\n"
    out := out ++ "  goals\n"
    for g in order do
      let gi := ir.goals[g]!
      let tag := if gi.tag.isAnonymous || gi.tag.hasMacroScopes then "" else s!" ({gi.tag})"
      let parent := match gi.parent? with
        | some p => s!"   parent {goalLabel p}"
        | none => ""
      out := out ++ s!"    {goalLabel g}{tag} ⊢ {← pp g gi.target}   ctx {hypList ir gi.context}{parent}\n"
      match gi.assignment? with
      | some a => out := out ++ s!"        assigned by #{a.node}: {← pp g a.proof}\n"
      | none => out := out ++ "        unassigned\n"
    out := out ++ "  hyps\n"
    for h in ir.hypOrder do
      let hi := ir.hyps[h]!
      let g? := hypGoal[h]?
      let value ← match hi.value? with
        | some v => pure s!" := {← pp g? v}"
        | none => pure ""
      let bi := match hi.binderInfo with
        | .implicit => "   {implicit}"
        | .strictImplicit => "   {strict implicit}"
        | .instImplicit => "   [instance]"
        | .default => ""
      let lineage := match hi.replaces? with
        | some l => s!"   replaces {hypLabel ir l.previous}{if l.fromAlias then "" else " (inferred)"}"
        | none => ""
      out := out ++ s!"    {hypLabel ir h} : {← pp g? hi.type}{value}{bi}{lineage}\n"
    return out

end Distill.Informalizer.IR.ProofIR
