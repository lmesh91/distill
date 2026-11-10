import Distill.Informalizer.Extract.Goals
import Lean.Elab.Util

/-!
# Recognizers

A recognizer fills in `TacticNode.detail` for one family of tactics. It only reports what the
tactic did (the hypotheses it introduced, the term it elaborated, the goals it left); what that
means mathematically is decided by translation.

A library registers a recognizer for its tactic with `@[distill_recognizer kind]`, like an
elaborator with `@[tactic kind]`. Those are tried first, the most recent first, then the built-in
`recognizers`, which do not depend on what the elaborated file imports.
-/

namespace Distill.Informalizer.Extract

open Lean Meta Elab
open Distill.Informalizer.IR

/-- What a recognizer gets to look at. Runs in the final metavariable context. -/
structure RecognizerInput where
  info : TacticInfo
  goals : Std.HashMap MVarId GoalInfo

/-- `none` means the node does not have the expected shape, which gives `.unrecognized`. -/
abbrev Recognizer := RecognizerInput → MetaM (Option TacticDetail)

namespace RecognizerInput

/-- The goal the tactic ran on. -/
def mainGoal? (r : RecognizerInput) : Option GoalInfo :=
  r.info.goalsBefore.head? >>= (r.goals[·]?)

/-- Hypotheses in `after`'s context that `before`'s context does not have. -/
def newHyps (before after : GoalInfo) : Array FVarId :=
  after.context.filter (!before.context.contains ·)

/-- The tactic's main goal and its proof, if the tactic itself (or a node nested in it)
assigned it. The goal table records the final assignment, which a later node may have made
instead. -/
def ownAssignment? (r : RecognizerInput) : Option (GoalInfo × Expr) := do
  let g ← r.mainGoal?
  let a ← g.assignment?
  guard (assignedIn r.info g.mvarId)
  return (g, a.proof)

/-- The goals the tactic created: those after it that were not there before. -/
def newGoals (r : RecognizerInput) : List GoalInfo :=
  (r.info.goalsAfter.filter (!r.info.goalsBefore.contains ·)).filterMap (r.goals[·]?)

end RecognizerInput

/-- `intro x y`, `intros`: the hypotheses added to the goal. Patterns (`intro ⟨ha, hb⟩`)
destructure as well, which `.intro` does not describe, so they are left unrecognized. -/
def recognizeIntro : Recognizer := fun r => do
  let simple (arg : Syntax) := arg.isIdent || arg.isOfKind ``Lean.Parser.Term.hole
  unless r.info.stx[1].getArgs.all simple do return none
  let some before := r.mainGoal? | return none
  let [after] := r.newGoals | return none
  return some (.intro (RecognizerInput.newHyps before after))

/--
`have h : t := e` and `have h : t := by tac`. The proof term of the goal is `have h : t := v; ?body`;
`v` is `e`, or the goal `tac` proves.
-/
def recognizeHave : Recognizer := fun r => do
  let some (before, proof) := r.ownAssignment? | return none
  let [body] := r.newGoals | return none
  let #[hyp] := RecognizerInput.newHyps before body | return none
  let value? := match proof.consumeMData with
    | .letE _ _ v _ _ => some v
    | .app (.app (.app (.app (.const ``letFun _) _) _) v) _ => some v
    | _ => none
  let some v := value? | return none
  if let .mvar m := v.consumeMData then
    if r.goals.contains m then return some (.have hyp none (some m))
  return some (.have hyp (some v) none)

/-- `exact e`, `apply e`, `refine e`: the elaborated term, as assigned to the goal. -/
def recognizeTerm (mode : TermMode) : Recognizer := fun r => do
  let some (_, proof) := r.ownAssignment? | return none
  return some (.term mode proof)

/--
`ext` without patterns: it applies the extensionality lemma for the goal's type and leaves
the lemma's premises as goals, like `apply` would. With patterns it also introduces
hypotheses, which this does not describe yet.
-/
def recognizeExt : Recognizer := fun r => do
  if r.info.stx[1].getNumArgs != 0 then return none
  let some (before, proof) := r.ownAssignment? | return none
  if r.newGoals.any fun g => (RecognizerInput.newHyps before g).size > 0 then return none
  return some (.term .apply proof)

/-- The built-in recognizers, by syntax kind. -/
def recognizers : Std.HashMap SyntaxNodeKind Recognizer := .ofList [
  (``Lean.Parser.Tactic.intro, recognizeIntro),
  (``Lean.Parser.Tactic.intros, recognizeIntro),
  (``Lean.Parser.Tactic.tacticHave__, recognizeHave),
  (``Lean.Parser.Tactic.exact, recognizeTerm .exact),
  (``Lean.Parser.Tactic.apply, recognizeTerm .apply),
  (``Lean.Parser.Tactic.refine, recognizeTerm .refine),
  (``Lean.Elab.Tactic.Ext.ext, recognizeExt)
]

/-- `@[distill_recognizer kind] def r : Recognizer := …` makes `r` fill in the detail of the
tactic `kind`. If it returns `none` or throws, the next recognizer for the kind is tried. -/
unsafe initialize recognizerAttribute : KeyedDeclsAttribute Recognizer ←
  KeyedDeclsAttribute.init {
    builtinName := `builtin_distill_recognizer
    name := `distill_recognizer
    descr := "how Distill describes a tactic in the Proof IR"
    valueTypeName := ``Recognizer
    evalKey := fun _ stx => syntaxNodeKindOfAttrParam `Lean.Parser.Tactic stx }

/-- The detail of a node; `.unrecognized` if no recognizer applies. -/
def recognize (input : RecognizerInput) : MetaM TacticDetail := do
  let kind := input.info.stx.getKind
  for rec in recognizerAttribute.getValues (← getEnv) kind ++ recognizers[kind]?.toList do
    try
      if let some detail ← rec input then return detail
    catch _ => pure ()
  return .unrecognized

end Distill.Informalizer.Extract
