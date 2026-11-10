import Distill.Informalizer.Render.Basic
import Distill.Informalizer.Render.Expr

/-!
# Rendering: Presentation IR ⟶ English

`render` writes a `PresentedDecl` as English: one sentence or two for the statement, and one
piece of text per proof step. The text is the rich text the web app displays: `$…$` is LaTeX
and `` `…` `` is Lean code.

Rendering decides wording only. What is said, and in which order, is the Presentation IR's
business: the statement introduces the object groups in order, each with its properties, then
states the hypotheses and the conclusion. How an expression is written is up to the translators
of `Distill.Informalizer.Render.Expr`.

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

def roleLabel : DeclRole → String
  | .theorem => "Theorem"
  | .lemma => "Lemma"
  | .example => "Example"

/-! ## Statements -/

/-- The clause that introduces the objects of a group: "let $A$ and $B$ be sets", "let
$x \in A$". `none` if the text introduces none of them. -/
private def groupClause (g : ObjectGroup) : RenderM (Option String) := do
  let omitted := (← read).omitted
  let objects := g.objects.filter (!omitted.contains ·.fvar)
  let some first := objects[0]? | return none
  let type ← instantiateMVars first.type.expr
  if first.binderInfo.isInstImplicit then
    mention type
    return some s!"fix an instance of {← exprCode type}"
  let name (o : MathObject) := nameTex o.name
  if let some value := first.value? then
    let value ← instantiateMVars value.expr
    match ← Render.math value with
    | some m => return some s!"let ${name first} = {m.tex}$"
    | none =>
      mention value
      return some s!"let ${name first}$ be {← exprCode value}"
  -- "let $x, y \in A$": the set says what the objects are, so their type is left out.
  if let #[property] := first.properties then
    if let some (set, .fvar x) := membership? (← instantiateMVars property.prop.expr) then
      if x == first.fvar then
        if let some m ← Render.math set then
          return some s!"let ${", ".intercalate (objects.toList.map name)} \\in {m.at 51}$"
  let noun ← Render.noun type
  let names := objects.toList.map fun o => s!"${name o}$"
  let head := match names with
    | [n] => s!"let {n} be {noun.article} {noun.singular}{noun.qualifier}"
    | _ => s!"let {joinAnd names} be {noun.plural}{noun.qualifier}"
  let properties ← objects.flatMapM fun o => o.properties.mapM fun p => do
    return (← Render.prose (← instantiateMVars p.prop.expr)).text
  if properties.isEmpty then return some head
  return some s!"{head} such that {joinAnd properties.toList}"

/-- "a", "a and b", "a, b, and c", for clauses that may contain "and" themselves. -/
private def joinClauses : List String → String
  | [a] => a
  | [a, b] => s!"{a} and {b}"
  | clauses => match clauses.getLast? with
    | some last => ", ".intercalate (clauses.dropLast ++ [s!"and {last}"])
    | none => ""

/-- The statement with its label, given which objects not to introduce. -/
private def statementText (d : PresentedDecl) : RenderM String := do
  let clauses ← d.objects.toList.filterMapM groupClause
  let hypotheses ← d.hypotheses.toList.mapM fun h => do
    Render.prose (← instantiateMVars h.prop.expr)
  let conclusion ← Render.prose (← instantiateMVars d.conclusion.prop.expr)
  let mut sentences := [s!"{roleLabel d.role}."]
  unless clauses.isEmpty do
    sentences := sentences ++ [s!"{capitalize (joinClauses clauses)}."]
  if hypotheses.isEmpty then
    -- "Then if …" would stack two connectives.
    let then_ := if clauses.isEmpty || conclusion.text.startsWith "if " then "" else "then "
    sentences := sentences ++ [s!"{capitalize (then_ ++ conclusion.text)}."]
  else if conclusion.simple && hypotheses.all (·.simple) then
    sentences := sentences ++
      [s!"If {joinAnd (hypotheses.map (·.text))}, then {conclusion.text}."]
  else
    sentences := sentences ++ [
      s!"Suppose {joinAnd (hypotheses.map (s!"that {·.text}"))}.",
      s!"Then {conclusion.text}."]
  return " ".intercalate sentences

/--
The statement: "Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$,
then $C \subseteq A \cap B$."

An implicit object (`{α : Type}`) is introduced only if the rest of the text names it. Which
objects that leaves out is not known before the text is written, so the text is written again
until none of the objects it leaves out is named.
-/
def renderStatement (d : PresentedDecl) : MetaM String := do
  let implicit := d.objects.flatMap fun g => g.objects.filterMap fun o =>
    if o.binderInfo == .implicit || o.binderInfo == .strictImplicit then some o.fvar else none
  let mut omitted : FVarIdSet := implicit.foldl (·.insert ·) {}
  -- Every round but the last introduces an object more.
  for _ in [0:implicit.size] do
    let (text, state) ← (statementText d).run { omitted } |>.run {}
    let named := omitted.toList.filter state.mentioned.contains
    if named.isEmpty then return text
    omitted := named.foldl (·.erase ·) omitted
  (statementText d).run { omitted } |>.run' {}

/-! ## Proof steps -/

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
