import Distill.Informalizer.Extract.Recognizers

/-! A library tactic and its recognizer, used from `Tests/Extensibility.lean`. -/

open Distill.Informalizer.Extract

syntax (name := myIntro) "my_intro " ident : tactic
macro_rules (kind := myIntro)
  | `(tactic| my_intro $x:ident) => `(tactic| intro $x:ident)

/-- Registered like `@[tactic myIntro]`. -/
@[distill_recognizer myIntro] def recognizeMyIntro : Recognizer := fun r => do
  let some before := r.mainGoal? | return none
  let [after] := r.newGoals | return none
  return some (.intro (RecognizerInput.newHyps before after))
