import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation

/-!
# Rendering: Presentation IR ⟶ English

`render` writes a `PresentedDecl` as English: one sentence or two for the statement, and one
piece of text per proof step. The text is the rich text the web app displays: `$…$` is LaTeX
and `` `…` `` is Lean code.

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
  text : String
  deriving Inhabited, Repr

/-- The English of one declaration. -/
structure Rendered where
  statement : String
  /-- In presentation order. -/
  steps : Array RenderedStep
  deriving Inhabited, Repr

/-- `s` as inline code. The fence is longer than any run of backticks in `s`, as in Markdown. -/
def code (s : String) : String :=
  let (longest, _) := s.foldl (init := (0, 0)) fun (longest, run) c =>
    if c == '`' then (max longest (run + 1), run + 1) else (longest, 0)
  let fence := "".pushn '`' (longest + 1)
  let pad := if s.startsWith "`" || s.endsWith "`" then " " else ""
  s!"{fence}{pad}{s}{pad}{fence}"

/-- "a", "a and b", "a, b and c". -/
def joinAnd : List String → String
  | [] => ""
  | [a] => a
  | [a, b] => s!"{a} and {b}"
  | a :: rest => s!"{a}, {joinAnd rest}"

/-- `e` as Lean code on one line. -/
def exprCode (e : Expr) : MetaM String := do
  let s := (← ppExpr e).pretty (width := 10000)
  return code (" ".intercalate ((s.splitOn "\n").map (·.trimAscii.toString)))

def roleLabel : DeclRole → String
  | .theorem => "Theorem"
  | .lemma => "Lemma"
  | .example => "Example"

private def displayName (n : Name) : String :=
  if n.hasMacroScopes then s!"{n.eraseMacroScopes}✝" else toString n

/-- The statement: "Theorem. Let …. Assume …. Then …." -/
def renderStatement (d : PresentedDecl) : MetaM String := do
  let objects ← d.objects.toList.mapM fun o => do
    let type := (← ppExpr o.type.expr).pretty (width := 10000)
    return code s!"{displayName o.name} : {type}"
  let hypotheses ← d.hypotheses.toList.mapM (exprCode ·.prop.expr)
  let conclusion ← exprCode d.conclusion.prop.expr
  let mut out := s!"{roleLabel d.role}."
  unless objects.isEmpty do out := out ++ s!" Let {joinAnd objects}."
  unless hypotheses.isEmpty do out := out ++ s!" Assume {joinAnd hypotheses}."
  let then_ := if objects.isEmpty && hypotheses.isEmpty then "" else "Then "
  return out ++ s!" {then_}{conclusion}."

/-- The Lean a step came from, for steps that have no English yet. -/
def renderUntranslated (ir : ProofIR) (nodes : Array Nat) : String :=
  let sources := nodes.toList.filterMap fun n => (ir.node? n).map (code <| syntaxFirstLine ·.stx)
  if sources.isEmpty then "A step that Distill cannot describe yet."
  else s!"Apply {joinAnd sources}."

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
