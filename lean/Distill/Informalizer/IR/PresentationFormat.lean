import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation

/-!
# Printing the Presentation IR

A text form of a `PresentedDecl` for debugging and tests, in the style of the examples in
`docs/informalization/ir.md`. Facts are `f<id>`, steps `s<id>` and Proof IR nodes `#<id>`.
-/

namespace Distill.Informalizer.IR.PresentedDecl

open Lean Meta

private def hypName (ir : ProofIR) (h : FVarId) : String :=
  match ir.hyp? h with
  | some hi => if hi.userName.hasMacroScopes then s!"{hi.userName.eraseMacroScopes}✝" else toString hi.userName
  | none => s!"<unknown {h.name}>"

private def pp (e : Expr) : MetaM String := do
  let s := (← ppExpr e).pretty (width := 10000)
  return " ".intercalate ((s.splitOn "\n").map (·.trimAscii.toString))

/-- An expression, followed by what it was before each change normalization made. -/
private def mathExpr (m : MathExpr) : MetaM String := do
  let mut out ← pp m.expr
  for r in m.history.reverse do
    out := out ++ s!"  ⟸ {← pp r.before}  [{r.rule}, {if r.proof?.isSome then "proved" else "defeq"}]"
  return out

private def claim (ir : ProofIR) (c : Claim) : MetaM String := do
  let hyp := match c.hyp? with
    | some h => s!"   hyp {hypName ir h}"
    | none => ""
  return s!"f{c.id}: {← mathExpr c.prop}{hyp}"

private def relation : OriginRelation → String
  | .direct => "direct"
  | .partOf => "partOf"
  | .consolidated => "consolidated"
  | .inferred => "inferred"
  | .synthesized => "synthesized"

private def kindName : StepKind → String
  | .fix .. => "fix"
  | .assume .. => "assume"
  | .derive .. => "derive"
  | .obtain .. => "obtain"
  | .claim .. => "claim"
  | .suffices .. => "suffices"
  | .witness .. => "witness"
  | .calc .. => "calc"
  | .split .. => "split"
  | .contradiction => "contradiction"
  | .conclude .. => "conclude"
  | .untranslated .. => "untranslated"
  | .gap _ .unfinished => "gap unfinished"
  | .gap _ .sorry => "gap sorry"
  | .gap _ .error => "gap error"

private def step (ir : ProofIR) (s : ProofStep) : String :=
  let detail := match s.kind with
    | .untranslated n => match ir.node? n with
      | some node => s!" `{syntaxFirstLine node.stx}`"
      | none => s!" <unknown node #{n}>"
    | _ => ""
  let nodes := " ".intercalate (s.origin.nodes.map (s!"#{·}")).toList
  let rule := match s.origin.rule? with
    | some r => s!"  rule {r}"
    | none => ""
  s!"s{s.id} {kindName s.kind}{detail}   origin {relation s.origin.relation} [{nodes}]{rule}"

private def roleName : DeclRole → String
  | .theorem => "theorem"
  | .lemma => "lemma"
  | .example => "example"

/-- A group on one line: `{α} : Type`, `A, B : Set α`, `x : α   with f0: x ∈ A   hyp hx`. -/
private def group (ir : ProofIR) (g : ObjectGroup) : MetaM String := do
  let some first := g.objects[0]? | return "<empty group>"
  let name (o : MathObject) : String :=
    let n := hypName ir o.fvar
    match o.binderInfo with
    | .implicit => s!"\{{n}}"
    | .strictImplicit => s!"⦃{n}⦄"
    | .instImplicit => s!"[{n}]"
    | .default => n
  let value ← match first.value? with
    | some v => pure s!" := {← mathExpr v}"
    | none => pure ""
  let properties ← g.objects.flatMapM (·.properties.mapM (claim ir))
  let with_ := if properties.isEmpty then "" else s!"   with {"; ".intercalate properties.toList}"
  return s!"{", ".intercalate (g.objects.toList.map name)} : {← mathExpr first.type}{value}{with_}"

private partial def block (ir : ProofIR) (b : Block) (indent := "    ") : MetaM String := do
  let mut out := ""
  for s in b.steps do
    out := out ++ s!"{indent}{step ir s}\n"
    match s.kind with
    | .fix objects =>
      for o in objects do
        out := out ++ s!"{indent}  {← group ir { objects := #[o] }}\n"
    | .assume facts _ | .derive facts =>
      for c in facts do
        out := out ++ s!"{indent}  {← claim ir c}\n"
    | .conclude c | .suffices c | .claim c _ | .gap c _ =>
      out := out ++ s!"{indent}  {← claim ir c}\n"
    | _ => pure ()
    for r in s.reasons do
      match r with
      | .term t => out := out ++ s!"{indent}  by {← mathExpr t}\n"
      | .lemma n args =>
        let args ← args.toList.mapM (mathExpr ·)
        out := out ++ s!"{indent}  by lemma {" ".intercalate (toString n :: args)}\n"
      | .fact id _ => out := out ++ s!"{indent}  by f{id}\n"
      | .definition n => out := out ++ s!"{indent}  by definition {n}\n"
      | .automation n => out := out ++ s!"{indent}  by automation #{n}\n"
    for e in s.evidence do
      let proof ← ir.withGoalContext e.goal (pp e.proof)
      out := out ++ s!"{indent}  proves {← pp (.mvar e.goal)}: {proof}\n"
    match s.kind with
    | .claim _ proof => out := out ++ (← block ir proof (indent ++ "  "))
    | .split _ branches =>
      for branch in branches do
        let goal ← match branch.body.goal? with
          | some c => pure s!" {← claim ir c}"
          | none => pure ""
        out := out ++ s!"{indent}  branch{goal}\n"
        for c in branch.assumptions do
          out := out ++ s!"{indent}    assuming {← claim ir c}\n"
        out := out ++ (← block ir branch.body (indent ++ "    "))
    | _ => pure ()
  return out

/-- Formats `d`, the presentation of `ir`. Runs inside `ir.withContext`; with
`goalName := ir.goalNumbering`, the goals in the steps' evidence are numbered as in `#proof_ir`. -/
def format (d : PresentedDecl) (ir : ProofIR) : MetaM String := ir.withGoalContext ir.rootGoal do
  let mut out := s!"PresentedDecl {d.decl}   role {roleName d.role}\n"
  out := out ++ "  objects\n"
  for g in d.objects do
    out := out ++ s!"    {← group ir g}\n"
  out := out ++ "  hypotheses\n"
  for h in d.hypotheses do
    out := out ++ s!"    {← claim ir h}\n"
  out := out ++ s!"  conclusion\n    {← claim ir d.conclusion}\n"
  out := out ++ s!"  proof of {← pp (.mvar d.rootGoal)}\n"
  out := out ++ (← ir.withContext (d.withLocals (block ir d.proof)) (goalName := ir.goalNumbering))
  return out

end Distill.Informalizer.IR.PresentedDecl
