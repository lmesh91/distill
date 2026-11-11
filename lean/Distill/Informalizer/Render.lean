import Distill.Informalizer.Render.Basic
import Distill.Informalizer.Render.Expr

/-!
# Rendering: Presentation IR ⟶ English

`render` writes a `PresentedDecl` as English: one sentence or two for the statement, and one
piece of text per proof step. The text is a `Text`, which keeps formulas and Lean code apart from
the words, so that the web app, or anything else that shows it, can lay them out its own way.

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
  text : Text
  deriving Inhabited, Repr

/-- The English of one declaration. -/
structure Rendered where
  /-- `none` if there is no theorem to state: the proof is a `by` block inside a declaration, or
  what it builds is not a proof of a proposition (`def n : Nat := by exact 1`). -/
  statement? : Option Text
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
private def groupClause (g : ObjectGroup) : RenderM (Option Text) := do
  let omitted := (← read).omitted
  let objects := g.objects.filter (!omitted.contains ·.fvar)
  let some first := objects[0]? | return none
  let type ← instantiateMVars first.type.expr
  if first.binderInfo.isInstImplicit then
    mention type
    return some ("fix an instance of " ++ (← exprCode type))
  let name (o : MathObject) := nameTex o.name
  if let some value := first.value? then
    let value ← instantiateMVars value.expr
    match ← Render.math value with
    | some m => return some ("let " ++ Text.math s!"{name first} = {m.tex}")
    | none =>
      mention value
      return some ("let " ++ Text.math (name first) ++ " be " ++ (← exprCode value))
  -- "let $x, y \in A$": the set says what the objects are, so their type is left out.
  if let #[property] := first.properties then
    if let some (set, .fvar x) := membership? (← instantiateMVars property.prop.expr) then
      if x == first.fvar then
        if let some m ← Render.math set then
          return some <|
            "let " ++ Text.math s!"{", ".intercalate (objects.toList.map name)} \\in {m.at 51}"
  let noun ← Render.noun type
  let names := objects.toList.map fun o => Text.math (name o)
  let head := match names with
    | [n] => "let " ++ n ++ s!" be {noun.article} {noun.singular}" ++ noun.qualifier
    | _ => "let " ++ Text.joinAnd names ++ s!" be {noun.plural}" ++ noun.qualifier
  let properties ← objects.flatMapM fun o => o.properties.mapM fun p => do
    return (← Render.prose (← instantiateMVars p.prop.expr)).text
  if properties.isEmpty then return some head
  return some (head ++ " such that " ++ Text.joinAnd properties.toList)

/-- "a", "a and b", "a, b, and c", for clauses that may contain "and" themselves. -/
private def joinClauses : List Text → Text
  | [a] => a
  | [a, b] => a ++ " and " ++ b
  | clauses => match clauses.getLast? with
    | some last => Text.intercalate ", " (clauses.dropLast ++ ["and " ++ last])
    | none => .empty

/-- The statement with its label, given which objects not to introduce. -/
private def statementText (d : PresentedDecl) : RenderM Text := do
  let clauses ← d.objects.toList.filterMapM groupClause
  let hypotheses ← d.hypotheses.toList.mapM fun h => do
    Render.prose (← instantiateMVars h.prop.expr)
  let conclusion ← Render.prose (← instantiateMVars d.conclusion.prop.expr)
  -- "Then if …" would stack two connectives.
  let conditional := conclusion.text.startsWith "if "
  let sentence (t : Text) : Text := t.capitalize ++ "."
  let mut sentences : List Text := [s!"{roleLabel d.role}."]
  unless clauses.isEmpty do
    sentences := sentences ++ [sentence (joinClauses clauses)]
  if hypotheses.isEmpty then
    let then_ := if clauses.isEmpty || conditional then "" else "then "
    sentences := sentences ++ [sentence (then_ ++ conclusion.text)]
  else if conclusion.simple && Prose.joinable hypotheses then
    sentences := sentences ++ [sentence <|
      "if " ++ Text.joinAnd (hypotheses.map (·.text)) ++ ", then " ++ conclusion.text]
  else
    sentences := sentences ++ [
      sentence ("suppose " ++ Text.joinAnd (hypotheses.map ("that " ++ ·.text))),
      sentence ((if conditional then "" else "then ") ++ conclusion.text)]
  return Text.intercalate " " sentences

/--
The statement: "Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$,
then $C \subseteq A \cap B$."

An implicit object (`{α : Type}`) is introduced only if the rest of the text names it, or if it
has properties, which are stated where it is introduced. Which
objects that leaves out is not known before the text is written, so the text is written again
until none of the objects it leaves out is named.
-/
def renderStatement (d : PresentedDecl) : MetaM Text := do
  let implicit := d.objects.flatMap fun g => g.objects.filterMap fun o =>
    if (o.binderInfo == .implicit || o.binderInfo == .strictImplicit) && o.properties.isEmpty
    then some o.fvar else none
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

/-- `ir` as the Lean it is, for a proof whose presentation `d` does not verify: the statement of
the declaration as Lean code, and each step as its source. Nothing here was translated, so
nothing can say something else than the Lean does. Runs inside `ir.withContext`. -/
def renderQuoted (ir : ProofIR) (d : PresentedDecl) : MetaM Rendered := do
  let env ← getEnv
  let statement? ← match if ir.isDeclBody then env.find? ir.decl else none with
    | some info => pure (some ((s!"{roleLabel d.role}. " : Text) ++ (← exprCode info.type) ++ "."))
    | none => pure none
  return {
    statement?
    steps := d.proof.steps.map fun s =>
      { step := s.id, nodes := s.origin.nodes, text := renderUntranslated ir s.origin.nodes } }

/-- The English of `d`, the presentation of `ir`. Runs inside `ir.withContext`. -/
def render (ir : ProofIR) (d : PresentedDecl) : MetaM Rendered := do
  let statement? ← ir.withGoalContext ir.rootGoal do
    if ir.isDeclBody && (← isProp d.conclusion.prop.expr) then some <$> renderStatement d
    else pure none
  return { statement?, steps := ← d.proof.steps.mapM (renderStep ir) }

end Distill.Informalizer
