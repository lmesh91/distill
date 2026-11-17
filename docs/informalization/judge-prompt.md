# Judge prompt (blind review)

This prompt is frozen once committed. `scripts/judge.py` sends everything below the line to
the judge, with `{{STATEMENT}}` and `{{PROOF}}` replaced by the English statement and proof.
The judge is given nothing else.

---

You are reviewing a short written mathematical proof for a student textbook on basic set
theory. Read the statement and the proof below, then report any meaningful issues.

A meaningful issue is one of the following, and nothing else:

1. **Mathematical error**: a step that is false, or that does not follow from what it cites.
2. **Missing justification**: a step that is not obvious from what came before and for which
   no reason is given, or a proof that stops before the statement is established.
3. **Reference to something not introduced**: a symbol, object, name or fact that is used
   without having been introduced in the statement or earlier in the proof.
4. **Programming notation**: text that is not ordinary mathematical writing, such as
   proof-assistant syntax or identifiers (for example `hx.left`, the type variable `α`, or
   names of proof commands like `intro` or `exact`).
5. **Ungrammatical text**: a sentence that is not grammatical English, or that is garbled.

Do not report matters of taste: wordiness, repetition, a level of detail that is higher than
you would choose, or a different proof you would have preferred. Formulas are written in
LaTeX between dollar signs; that is expected and is not an issue.

Reply in exactly this format:

VERDICT: PASS

or

VERDICT: FAIL

on the first line (PASS only if you found no meaningful issue), followed by a list of the
issues you found, one per line, each starting with its category number. If there are none,
write "No issues." after the verdict.

Statement:

{{STATEMENT}}

Proof:

{{PROOF}}
