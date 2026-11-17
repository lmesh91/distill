# Translator work: progress

Branch `lmesh/translator`. Scope: the Lean side only (`lean/`, `docs/informalization/`,
`scripts/`). The frontend and the translation service (`src/`, `worker/`, `relay/`, and the
shape of what `Distill.translate` returns) are not touched.

This file is the resume point after a context reset. Read "Status" first.

## Status

| Phase | State |
|---|---|
| Setup 1: this file | done |
| Setup 2: judge prompt committed (frozen) | pending |
| Setup 3: edge-case catalog | pending |
| Setup 4: held-out split committed | pending |
| #89 #91 #93 #94 #95 #96 #97 | pending |
| #103 #104 #105 | pending |
| Acceptance 2–9 | pending |
| Final held-out evaluation | pending |

## Starting point (what already exists)

The pipeline `InfoTree → Proof IR → Presentation IR → normalize → verify → render` exists and
is tested. Statements are English already. Proof steps for `intro`/`have`/`exact`/`ext` exist
but justify themselves with quoted Lean (``Thus $x \in A$ by `hx`.``), steps are a flat list
with no case structure, anything else is ``Apply `tac`.``, and a proof the pipeline throws on
is dropped (a blank result).

## Interpretation of the in-scope issues

- **#89 Referenced constants.** A function from a Proof IR to the list of definitions and
  theorems the proof uses: the constants in the statement, goals, hypothesis types and proof
  term, plus the constants Lean only reaches by unfolding (found by type-checking the proof
  term and recording what the checker unfolds, e.g. `Set.Subset` for `intro` on `A ⊆ B`).
  Instances and their projections are left out, and so is anything that is not a constant
  (the auto-bound `α`). Each entry says whether it is direct or reached by unfolding. Done
  when a test shows the demo levels' lists agree with demo-coverage.md §1–2.
- **#91 Hypotheses and goals.** A function that writes any goal state (its objects, its
  hypotheses and its target) as English, built on the statement renderer: "Let … . Suppose
  that … . We need to show that … ." Done when a test prints every goal state of every demo
  proof and none contains Lean code. It is also what an unfinished proof's "it remains to
  show" text is written with.
- **#93 Expressions and terms.** Proof *terms* get English: a hypothesis used as it is, a
  hypothesis applied as a function (`hCA x hx`), projections (`h.left`, `hx.2`, `And.right
  hx`), anonymous constructors and `And.intro`, lemma applications, `fun`, `have` inside
  terms, and nested `by`. A term becomes presentation steps whose reasons are facts, lemmas
  and definitions, never quoted Lean. Every expression construct of demo-coverage.md and of
  the catalog renders as a formula or prose.
- **#94 Distill definitions.** `Set`, `Subset`, `Intersection`, `Union` and membership get a
  registered English name and definition. Where Lean accepted a step only by unfolding one
  of them, the step says so: "by the definition of intersection".
- **#95 Distill theorems.** A theorem used in a proof is cited in English: by a registered
  name with its content where there is one (`Set.ext`), otherwise by its statement written
  in English, with what it was applied to when that differs from its own variable names.
  This is generic, so it covers earlier-level theorems without naming them.
- **#96 Coherent explanation.** The steps of a proof read in order as one piece of prose:
  what has to be shown, introductions, forward steps with connectives, branches introduced
  one by one ("First, …", "Second, …") for `ext`, `constructor`, `refine ⟨?_, ?_⟩`, …, and a
  conclusion. The line-by-line output keeps its shape (`{line, english}`); the same texts
  joined in presentation order are the continuous proof.
- **#97 Fallback.** Unsupported tactics and terms, errors, `sorry` and unfinished proofs each
  give readable text that says what is known (which Lean was not explained, what remains to
  be shown). Nothing throws out of the pipeline, and a proof is never dropped: the worst case
  is the statement plus the quoted Lean.
- **#103 Regression tests.** Golden English for the demo levels and every non-held-out
  catalog entry, run by `lake test`.
- **#104 Coverage test.** A check over a level file that fails if any tactic, term construct,
  or referenced constant used there has no translation (a fallback step, quoted Lean in the
  English, or a definition without an English name). Run on the demo levels by `lake test`,
  with a negative test showing it does fail.
- **#105 Benchmark.** A committed script that measures elaboration and translation time per
  demo level and on generated proofs of ~500 and ~1000 steps, median of 5, checks the two
  thresholds of acceptance criterion 5, and writes the results into the docs.

## Decisions that interpret the task

- **Existing golden tests.** The rule says not to edit existing tests unless they are
  incorrect. The goldens in `lean/Tests/Informalization` record the old wording (quoted Lean
  as the reason), which these issues exist to replace. Their expected text is regenerated
  where the wording changed on purpose; what each test checks (its input, its assertions)
  is not changed. Any other edit to an existing test is listed below with its reason.
- **Catalog kinds.** Every catalog entry is one of: `alternative` (a complete proof of a
  demo level using demo constructs; must be fully translated and pass blind review),
  `partial` / `broken` (what a user has mid-typing; must give a readable fallback) and
  `unsupported` (a complete proof using a tactic outside the demo; must give a readable
  fallback, and is not sent to blind review because criterion 2 names "complete alternative
  proof[s]"). The kind is fixed in the entry's header before the split.
- **Catalog files** are `*.lean.txt`, not `*.lean`, so that `lake test` (which globs
  `Tests.+`) never compiles the held-out inputs, and so that inputs with syntax errors can
  exist. The regression test is a generated Lean file that embeds the non-held-out inputs.

## Edits to existing tests

(none yet)

## Review findings and answers

(none yet)

## Held-out evaluation

(not run yet)
