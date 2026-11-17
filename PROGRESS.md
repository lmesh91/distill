# Translator work: progress

Branch `lmesh/translator`. Scope: the Lean side only (`lean/`, `docs/informalization/`,
`scripts/`). The frontend and the translation service (`src/`, `worker/`, `relay/`, and the
shape of what `Distill.translate` returns) are not touched.

This file is the resume point after a context reset. Read "Status" first.

## Status

| Phase                                                                 | State                                                                    |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| Setup 1: this file                                                    | done                                                                     |
| Setup 2: judge prompt committed (frozen)                              | done (9820c77)                                                           |
| Setup 3: edge-case catalog                                            | done (9aea9f4)                                                           |
| Setup 4: held-out split committed                                     | done (9aea9f4)                                                           |
| #93 #95 #96 #97 (term-driven presentation, English reasons, fallback) | done, committed                                                          |
| #89 #91 #94                                                           | done, committed                                                          |
| #103 #104 #105                                                        | done, committed (benchmark results in docs/informalization/benchmark.md) |
| Acceptance 2–9                                                        | pending                                                                  |
| Final held-out evaluation                                             | pending                                                                  |

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
- **#93 Expressions and terms.** Proof _terms_ get English: a hypothesis used as it is, a
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
  exist. The regression test `lean/Tests/Informalization/Catalog.lean` is generated by
  `scripts/informalization/catalog.py test`: one `#guard_msgs` per non-held-out entry, which
  reads the entry from `Tests/Catalog/cases/` (never `Tests/HeldOut/`), prints its English and
  says whether it meets what its kind requires.

## Edits to existing tests

- The expected English in `DemoLevels.lean`, `Pipeline.lean` and `Catalog.lean` says "the
  previously proved theorem that" instead of "the theorem that" (see "Judges" below).

- **Goldens regenerated** (expected text only, inputs and assertions unchanged) in
  `Tests/Extraction/{Extensibility,Robustness,Shapes}.lean` (the Proof IR printer now prints
  `constructor` and `destruct … ⟶ …` instead of `<detail>`) and
  `Tests/Informalization/{DemoLevels,Extensibility,Pipeline,Tactics}.lean` (new English and
  new Presentation IR). Every diff was read and is the intended new wording.
- **`Tests/Informalization/Extensibility.lean`, `fakeEvidence` pass.** The pass rewrote
  evidence only on top-level steps. Evidence for a goal now lives on the step that finishes
  that goal, often inside a split or claim block, so the pass changed nothing and the test
  no longer tested anything (verification trivially succeeded). The pass now recurses into
  nested blocks (`fakeBlock`). What the test asserts (verification rejects fake evidence and
  the step is skipped) is unchanged and passes.

## Performance notes (#105)

- The benchmark runs the translator the way the language server does: this library's code is
  interpreted (no `precompileModules`), Lean's own functions are compiled. Loops of this
  library's code over a goal's whole context therefore cost far more than Lean's.
- Long proofs were quadratic (ratio 3.9 for 500 → 1000 steps). Every stage did work
  proportional to a goal's whole context for each goal. Now: a goal's new hypotheses are found
  in constant time when its context extends its parent's (`IR.sharedPrefix?`, relying on
  tactics only adding hypotheses at the end of a context, with an exact fallback), local
  contexts are built from the parent's, the proof term is filled top-down with one substitution,
  goal contexts are read with Lean's `getLocalHyps`, and the hypothesis table only looks at each
  goal's new hypotheses. Ratio now about 2.2.

## Checks (criterion 9)

Run with Node 24 (the system Node 18 is too old for `npm run check` and the TypeScript tests).

- `lake test`: passes.
- `npm run check` (svelte-check and types): 0 errors, 0 warnings.
- `npm test`: 101 pass, 34 fail. The same 34 fail on `main`; they need services that are not
  running here. This branch does not change the frontend or the translation service.
- `eslint`: 1 error, in `src/routes/app/levels/[slug]/+page.svelte`, which is also on `main`.
- `prettier --check`: 19 files, none of them changed by this branch (all pre-existing on
  `main`).

## Review findings and answers

### Code review, round 1 (high effort, whole branch against `main`)

| #   | Finding                                                                                                                                             | Severity | Outcome                                                                                                                                                                                                                                                                                                    |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `judge.py` recorded a failed `claude` call (expired login, network) as a FAIL judgment                                                              | high     | fixed: a failed call stops the run, and a preflight call checks the judge is reachable before anything is judged                                                                                                                                                                                           |
| 2   | `recognizeShow` also matched `change … at h`                                                                                                        | medium   | fixed: a tactic with an `at` clause is not recognized, so it is shown as its Lean (fallback)                                                                                                                                                                                                               |
| 3   | The hypothesis table keeps one type per hypothesis, so a hypothesis changed in place (`change … at h`, same fvar) keeps its old type in later goals | medium   | answered, not changed: this is how the Proof IR has always modelled hypotheses (one `HypInfo` per fvar); `change … at h` is now untranslated (2), so the English never relies on the stale type for it. Changing it needs per-goal hypothesis types in the IR, which no demo construct needs.              |
| 4   | `have h : t` without a value (two new goals) was recognized as a `.destruct`                                                                        | low      | fixed: recognized as `.have` whose value is the goal of proving `t`                                                                                                                                                                                                                                        |
| 5   | A definition was marked as already explained even when the step's sentence did not cite it                                                          | low      | fixed: `stepText` keeps the mark only if the sentence contains the citation                                                                                                                                                                                                                                |
| 6   | Coverage rebuilt the proof's context once per referenced constant                                                                                   | low      | fixed: one `withContext` for all of them                                                                                                                                                                                                                                                                   |
| 7   | `sharedPrefix?` never matched an empty parent context                                                                                               | low      | fixed                                                                                                                                                                                                                                                                                                      |
| 8   | `newHypsIn` stops at the last shared hypothesis instead of filtering the whole context                                                              | low      | answered, not changed: it relies on the invariant documented on `sharedPrefix?` (tactics add hypotheses only at the end of a context; Lean's `LocalContext` appends, and tactics that reorder revert and reintroduce with new fvars). Filtering whole contexts per goal made long proofs quadratic (#105). |

### Code review, round 2 (changes since round 1)

| Finding                                                                                                                                                                  | Outcome                                                              |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------- |
| The new "sole constructor" rule also let `Exists.intro` (one constructor, but a witness field) write "we need to show", which claims the choice of witness loses nothing | Fixed: every field of the constructor must be a proof.               |
| `sorry` arguments are dropped by replacing the whole application, including its type                                                                                     | Answered: the type is the goal's target, which is already collected. |

No high-severity findings remain.

### Design review (criterion 8)

- **First run, discarded.** The agent's worktree was created from `main` (95e109c), without
  this branch's commits, so it reviewed the translator as it was before this work (for example,
  it found no term handlers and "by `h`" in every proof). Its files (on branch
  `worktree-agent-ae26f3c951885d994`) are not used. Rerun on a worktree of this branch
  (`design-review-or`, from 5d39ab6).

- **Second run** (branch `design-review-or`, commit 141f660, not merged). It added `Or`
  (`cases`, `rcases`, `obtain`, `rintro` patterns, `match`, `Or.elim`, `left`, `right`) with no
  change under `lean/Distill/` and no edit to an existing file. Files touched:
  `lean/Tests/Extensibility/Or.lean` (a recognizer for `left`/`right`, silent citations for
  `Or.inl`/`Or.inr`, term handlers for `Or.inl`/`Or.inr`, for case splits on `Or` and for
  `Or.elim`) and `lean/Tests/Informalization/Or.lean` (10 goldens). Every golden gives complete
  English with no Lean code, and verification passes. Example (`union_subset`): "Then
  $x \in A$ or $x \in B$ by the definition of union. First, suppose that $x \in A$. Since
  $A \subseteq C$ and $x \in A$, we conclude that $x \in C$ by the definition of subset. Now
  suppose instead that $x \in B$. …"
- **Was a recognizer plus a renderer enough?** Nearly: the recognizer was needed only for
  `left`/`right`; the rest is term handlers (the presentation's extension point) and
  translators. The wording of a case split ("First, suppose … / Now suppose instead …") is
  fixed in `Render.lean` and cannot be changed by an extension.

| Finding                                                                                                                                       | Outcome                                                                                                                                         |
| --------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| A silent lemma (`Or.inl`) left a `suffices` reading "by the definition of union, we need to show that $x \in A$", which claims an equivalence | Fixed: only definitions, or the sole constructor of a type (`And.intro`), allow "we need to show"; any other lemma gives "it suffices to show". |
| Coverage reported `Lean.Name`, `Bool`, … for any `sorry`                                                                                      | Fixed: a `sorry`'s arguments are not counted; new case in `Tests/Informalization/Coverage.lean`.                                                |
| `lake test` builds `Tests/HeldOut` (glob `Tests.+`)                                                                                           | Answered: the held-out entries are `.lean.txt` files, which are not Lean modules, so the glob does not build them.                              |
| Case-split wording, `StepKind` and step rendering are closed; `split` renders no lead sentence                                                | Answered: a recorded limitation for future work (a step-sentence translator kind). The demo's case structure (`ext`) reads correctly.           |
| Handler toolkit (`inBlock`, `premise`, `needsBlock`) private; evidence order undocumented                                                     | Answered: recorded for future work.                                                                                                             |
| A recognizer's transparency depends on the detail kind                                                                                        | Answered: recorded for future work (let recognizers declare it).                                                                                |
| Fallback is per declaration: one bad term handler quotes the whole proof                                                                      | Answered: the main risk for long LLM proofs; per-goal verification and fallback is the top recommendation below.                                |

**Extensibility review (summary).** Reading proof terms is the strength: one handler on `Or`
covered five tactic syntaxes and a hand-written `match`, and an unreadable goal falls back
locally. Toward full Lean: recognizers are a whitelist (`exfalso`, `exists`, `specialize`,
`by_cases` stay untranslated), several `TacticDetail` kinds have no producer, and `witness`,
`calc` and `contradiction` have no renderer. Toward Mathlib: the vocabulary is keyed on
`Distill.Set`, theorems without a registered citation are cited by statement, automation is
quoted, and the unfold-tracking used for "by definition" has not been measured on
typeclass-heavy terms. Toward long LLM proofs: verification failure falls back for the whole
declaration. Ranked recommendations: (1) verify and fall back per goal; (2) open step rendering
(a step-sentence translator, a lead sentence for `split`); (3) public handler toolkit with a
documented evidence contract; (4) recognizers that declare transparency; (5) for Mathlib, a
configurable vocabulary, cached unfold analysis, name-based citations, and an automation
recognizer.

### PR #193 review comments

| Comment                                                                                                        | Outcome                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| -------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The `isDefEq` in `Present` should run with `withNewMCtxDepth`                                                  | Already done (`Present/Unfold.lean`). The other calls that compare with goals or proofs now do too: `Verify.lean` (two, where an incomplete proof's open goals could otherwise be assigned to make a check pass), `Constants.lean` and `Extract/Frontend.lean`.                                                                                                                                                                                                                                                                                |
| `Distill.Set.ext` is hard-coded                                                                                | Already done: presentation is term-driven and has no case for it; its English is an entry in the translator table (`Render/Expr.lean`).                                                                                                                                                                                                                                                                                                                                                                                                        |
| `✝` shows in the English for shadowed names (`probe_shadow`)                                                   | Already done: `probe_shadow` translates to English with no Lean code and no `✝`.                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Verification should check that `conclude`, `derive` and `suffices` statements match their hypotheses and goals | Partly done: every claim that is a Lean hypothesis (object properties, assumptions, derived and obtained facts, case hypotheses) must state its type (`claimProblem?` in `Verify.lean`, negative test `Tests/Informalization/ClaimCheck.lean`). Not done: `conclude`/`suffices` against their goal. A step's evidence does not identify its goal (in a term proof it is what was gathered since the previous step), so this needs the presentation to record each step's goal; an attempt that used the evidence rejected correct term proofs. |

### Judges (criteria 2 and 3)

The judge is `haiku` (`claude-haiku-5-5`), run as one subagent per judgment (the user asked for
subagents instead of the `claude` CLI): `scripts/judge.py all --export DIR` writes every prompt,
each subagent reads one and writes its reply, and `scripts/judge.py all --import DIR` scores them.
56 cases (the 6 demo levels and 50 alternative proofs), 3 blind runs and 1 faithfulness run each.

**Run 1** (commit be3e01b): 47 of 56 cases passed blind review 3/3, and 55 of 56 were faithful.

- Blind review failed on every proof of level 6 (`inter_comm`), and once (1 of 3) on
  `l5-exact-direct`. The judges' reason: "the theorem that for all sets $A$ and $B$, …" is cited
  without being introduced, and for level 6 looked circular. A cited theorem is now "the
  previously proved theorem that …" (an axiom "the axiom that …").
- Faithfulness failed on `l6-refine`: the judge took `Set.ext` to be Mathlib's (a membership
  iff) and said "it suffices to show $A \cap B \subseteq B \cap A$ and …" was the wrong
  reduction. Distill's `Set.ext` takes exactly those two inclusions, but the judge was not shown
  it. Fixed in `judge.py`: the faithfulness judge's Lean source now starts with the set
  definitions and the statements of the earlier theorems the proof names. The frozen prompt is
  unchanged.

**Run 2** (the changes above; the 9 cases that failed, the other demo levels, and `l5-apply`
and `l6-scratch-term`, which cite theorems; 16 cases): faithfulness 16/16; blind review 3/3
on levels 1–5, including `l5-exact-direct`. Level 6 still failed at least one of three runs in 7 of
its 8 proofs (counting the demo's), with the same reason (run 2 used the wording "the earlier
theorem that", which the judges read as "earlier in this proof"; run 3 used "previously
proved").

**Run 3** (blind only, the demo levels and the level-6 proofs): levels 1–5 3/3; level 6 3/3 in
`l6-case-reversed`, `l6-exact-ext`, `l6-scratch-term` and `l6-term`, and failing in the demo,
`l6-case`, `l6-refine`, `l6-seq-apply` and `l6-underscores`.

**Decision (the user's): level 6's remaining blind failures are accepted.** Their only
complaint is that the proof cites a previously proved theorem (level 5) that the text does not
re-introduce. Citing an earlier theorem is fine, and wording the English to satisfy this judge
(I tried opening the proof with a sentence restating each cited theorem) would be fitting the
judge rather than improving the translation. When interactivity is added, the structured
output will reference the exact Lean theorem used, which can then be shown in English.

Summary: criterion 3 (faithfulness) passes on every case judged in its latest run. Criterion 2
passes 3/3 on levels 1–5 and on every alternative proof of levels 1–5; level 6 is the accepted
exception above.

## Held-out evaluation

(not run yet)
