# Proof-from-scratch levels

Set a published level's `type` to `from-scratch` to use proof-from-scratch mode at
`/app/levels/<slug>`.

The goal panel presents `statement` and `description`. Hover over the question-mark
button in the top right to read instructions for constructing a proof.
The same help opens on keyboard focus or a tap, and Escape
or a click outside dismisses it. From-scratch levels show help in place of Hints.
There is no supplied English proof to translate. The shared
Lean editor loads `starterCode` and sends edits to Lean for live diagnostics.

Use `statement` for the learner-facing target and `description` for the exercise
context. Put the Lean imports, variables, and target declaration in `starterCode`,
leaving the proof for the learner, for example:

```lean
theorem identity (P : Prop) : P → P := by
  sorry
```

Starter code is loaded verbatim, as in other modes; the app does not try to convert
the learner-facing statement into Lean or strip proof steps from authored code.
The learner can edit the entire declaration. Live diagnostics are feedback, not
level acceptance: checking the submitted theorem against the required target is
tracked separately in #80–#81, and the Check Proof action in #56.
