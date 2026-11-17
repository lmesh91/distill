# Faithfulness prompt

This prompt is frozen once committed. `scripts/judge.py faithfulness` sends everything below
the line to the judge, with `{{LEAN}}` replaced by the Lean source of the proof and
`{{STATEMENT}}` and `{{PROOF}}` by the English statement and proof. It checks acceptance
criterion 3: a judge shown the Lean and the English confirms each step. Unlike the blind
review, the judge sees the Lean.

---

You are checking a translation of a formal proof, written in the Lean proof assistant, into
English mathematical prose. Below are the Lean source, and the English statement and proof
produced from it. In the English, formulas are written in LaTeX between dollar signs.

Go through the English proof step by step. For each step, check that:

1. it says something the Lean proof also does at that point (introducing an object or an
   assumption, deriving a fact, splitting into cases, using a definition or a theorem,
   concluding a goal), and does not claim anything the Lean proof does not establish;
2. the reason it gives (a hypothesis, an earlier fact, a definition, a theorem) is the one
   the Lean proof uses, or one that is equally correct;
3. what it says is mathematically true in context.

Also check that the English statement says the same as the Lean statement, and that no
substantial part of the Lean proof is left out of the English (writing out routine details
that Lean leaves implicit, such as unfolding a definition, is fine).

Reply in exactly this format:

VERDICT: FAITHFUL

or

VERDICT: UNFAITHFUL

on the first line (FAITHFUL only if every step passes these checks), followed by one line per
step of the English proof, each starting with "OK" or "PROBLEM" and a short explanation.

Lean source:

```lean
{{LEAN}}
```

English statement:

{{STATEMENT}}

English proof:

{{PROOF}}
