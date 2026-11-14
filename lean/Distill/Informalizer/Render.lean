import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation
import Distill.Informalizer.Text

/-!
# Rendering: Presentation IR ⟶ English

`render` writes a `PresentedDecl` as English: one sentence or two for the statement, and one
piece of text per proof step. The text is a `Text`, which keeps formulas and Lean code apart from
the words, so that the web app, or anything else that shows it, can lay them out its own way.

Whatever has no English yet is shown as the Lean it came from, so no part of a proof is ever
left out.
-/

namespace Distill.Informalizer

open Lean Meta
open Distill.Informalizer.IR

/-- The English of one proof step. -/
structure RenderedStep where
  /-- The step's id. -/
  step : Nat
  /-- The Proof IR nodes the step came from (`StepOrigin.nodes`), which locate it in the
  source. -/
  nodes : Array Nat
  text : Text
  deriving Inhabited, Repr

/-- The English of one declaration. -/
structure Rendered where
  statement : Text
  /-- In presentation order. -/
  steps : Array RenderedStep
  deriving Inhabited, Repr

/-- `e` as Lean code on one line. -/
def exprCode (e : Expr) : MetaM Text := do
  let s := (← ppExpr e).pretty (width := 10000)
  return .code (" ".intercalate ((s.splitOn "\n").map (·.trimAscii.toString)))

def roleLabel : DeclRole → String
  | .theorem => "Theorem"
  | .lemma => "Lemma"
  | .example => "Example"

private def displayName (n : Name) : String :=
  if n.hasMacroScopes then s!"{n.eraseMacroScopes}✝" else toString n

/-- The statement: "Theorem. Let …. Assume …. Then …." -/
def renderStatement (d : PresentedDecl) : MetaM Text := do
  let objects ← d.objects.toList.mapM fun o => do
    let type := (← ppExpr o.type.expr).pretty (width := 10000)
    return Text.code s!"{displayName o.name} : {type}"
  let hypotheses ← d.hypotheses.toList.mapM (exprCode ·.prop.expr)
  let conclusion ← exprCode d.conclusion.prop.expr
  let mut out : Text := s!"{roleLabel d.role}."
  unless objects.isEmpty do out := out ++ " Let " ++ Text.joinAnd objects ++ "."
  unless hypotheses.isEmpty do out := out ++ " Assume " ++ Text.joinAnd hypotheses ++ "."
  let then_ := if objects.isEmpty && hypotheses.isEmpty then "" else "Then "
  return out ++ s!" {then_}" ++ conclusion ++ "."

/-- The Lean a step came from, for steps that have no English yet. -/
def renderUntranslated (ir : ProofIR) (nodes : Array Nat) : Text :=
  let sources := nodes.toList.filterMap fun n =>
    (ir.node? n).map (Text.code <| syntaxFirstLine ·.stx)
  if sources.isEmpty then "A step that Distill cannot describe yet."
  else "Apply " ++ Text.joinAnd sources ++ "."

def renderStep (ir : ProofIR) (s : ProofStep) : MetaM RenderedStep := do
  let text ← match s.kind with
    | .untranslated n => pure (renderUntranslated ir #[n])
    | _ => pure (renderUntranslated ir s.origin.nodes)
  return { step := s.id, nodes := s.origin.nodes, text }

/-- The English of `d`, the presentation of `ir`. Runs inside `ir.withContext`. -/
def render (ir : ProofIR) (d : PresentedDecl) : MetaM Rendered := do
  let statement ← ir.withGoalContext ir.rootGoal (renderStatement d)
  return { statement, steps := ← d.proof.steps.mapM (renderStep ir) }

end Distill.Informalizer
