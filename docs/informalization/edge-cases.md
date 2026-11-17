# Edge-case catalog

The demo levels are six proofs, but a user of the level page types many more: another proof of
the same statement, half a proof, a proof with a mistake in it. This catalog lists such inputs.
Each one uses only what the demo levels use (their statements, definitions and tactics) or
something a user would reasonably type while working on them.

Each entry is a Lean source file, `lean/Tests/Catalog/cases/<id>.lean.txt`, that starts with a
header:

```
-- id: l2-obtain
-- level: 2
-- kind: alternative
-- note: `obtain` destructuring the membership
```

The files are not `.lean` so that Lake never compiles them: some do not parse.

## Kinds

| Kind          | What it is                                                             | What the translator owes it                                                         |
| ------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `alternative` | A complete proof of a demo level, using demo constructs.               | A full English proof with no Lean in it. Sent to blind review.                      |
| `partial`     | A proof being typed: unfinished, `sorry`, a hole, a syntax error.      | English for what is there, and readable text for what is missing. Never blank.      |
| `broken`      | A proof with an error: a wrong name, a type mismatch, an extra tactic. | English for the steps Lean accepted, and readable text at the step that failed.     |
| `unsupported` | A complete proof that uses a tactic or theorem from outside the demo.  | A correct translation if there is one, otherwise a readable fallback for that step. |

In every kind, a correct translation is better than a clear fallback, and a fallback is better
than a wrong translation.

## What the alternatives vary

- **Term mode or tactic mode.** `fun x hx => …` as the whole proof, as the argument of `exact`
  or `refine`, and `by` blocks nested in terms.
- **How a conjunction is used.** `h.left`, `h.1`, `And.left h`, `obtain ⟨ha, hb⟩ := h`,
  `rcases`, `cases … with`, `rintro` and `intro` patterns, a pattern-matching `fun`, `have`
  with a pattern.
- **How a conjunction is proved.** `⟨ha, hb⟩`, `And.intro`, `constructor`, `refine ⟨?_, ?_⟩`,
  `apply And.intro`, with the parts given as hypotheses, as nested applications, or as nested
  `by` blocks.
- **How a subset hypothesis is used.** `hCA x hx`, `hCA x` kept for later, `apply hCA x`.
- **How earlier theorems are used.** With explicit arguments, with `_`, with `@`, nested in
  each other, through `apply`, and applied to an element as if they were functions.
- **How goals are organized.** Bullets, `case` (in order and out of order), `<;>`, no
  structure at all.
- **Small things.** Other variable names, unnamed variables, `have` without a type or without
  a name, `show`, `assumption`.

## Held-out entries

About a quarter of the entries, chosen by `scripts/informalization/catalog.py split` with a
fixed seed and in proportion to each kind, were moved to `lean/Tests/HeldOut/` before any of
the translator was written. They are listed in `lean/Tests/Catalog/held-out.txt`. They are
not read or run during development; the final evaluation runs them once, and its results are
in `PROGRESS.md`.

## Entries

The table lists every entry, held out or not.

<!-- entries:begin -->

| Entry                  | Level | Kind        | What it is                                                    |
| ---------------------- | ----- | ----------- | ------------------------------------------------------------- |
| `l1-anonymous`         | 1     | alternative | `intro _ _` leaves the names inaccessible                     |
| `l1-assumption`        | 1     | alternative | `assumption` instead of `exact hx`                            |
| `l1-exact-fun`         | 1     | alternative | `exact` given a whole function                                |
| `l1-intro-separate`    | 1     | alternative | one `intro` per name                                          |
| `l1-rename`            | 1     | alternative | other variable names                                          |
| `l1-show`              | 1     | alternative | `show` restating the goal                                     |
| `l1-show-forall`       | 1     | alternative | `show` unfolding the subset by hand                           |
| `l1-term-fun`          | 1     | alternative | term mode: the proof is a function                            |
| `l1-term-underscore`   | 1     | alternative | term mode with an unnamed element                             |
| `l2-and-left`          | 2     | alternative | `And.left` written as a function                              |
| `l2-cases`             | 2     | alternative | `cases … with`                                                |
| `l2-have-by`           | 2     | alternative | `have` proved by a nested tactic block                        |
| `l2-have-obtain`       | 2     | alternative | the demo's `have`, then destructured                          |
| `l2-have-pattern`      | 2     | alternative | `have` with a pattern                                         |
| `l2-have-this`         | 2     | alternative | anonymous `have`, used as `this`                              |
| `l2-have-untyped`      | 2     | alternative | `have` without a type                                         |
| `l2-intro-pattern`     | 2     | alternative | `intro` with a pattern                                        |
| `l2-obtain`            | 2     | alternative | `obtain` destructuring the membership                         |
| `l2-proj-1`            | 2     | alternative | numeric projection without the `have`                         |
| `l2-refine-fun`        | 2     | alternative | `refine` with a function and a hole                           |
| `l2-rintro`            | 2     | alternative | `rintro` with a pattern                                       |
| `l2-term`              | 2     | alternative | term mode with `.left`                                        |
| `l2-term-pattern`      | 2     | alternative | term mode with a pattern-matching `fun`                       |
| `l3-and-right-term`    | 3     | alternative | term mode with `And.right`                                    |
| `l3-have`              | 3     | alternative | level 2's style on level 3                                    |
| `l3-obtain`            | 3     | alternative | `obtain` ignoring the first part                              |
| `l3-proj-2`            | 3     | alternative | numeric projection                                            |
| `l3-rcases`            | 3     | alternative | `rcases … with`                                               |
| `l3-term`              | 3     | alternative | term mode with `.2`                                           |
| `l4-and-intro`         | 4     | alternative | `And.intro` by name                                           |
| `l4-apply-and`         | 4     | alternative | `apply And.intro` without bullets                             |
| `l4-apply-hyp`         | 4     | alternative | `apply` with a hypothesis applied to the element              |
| `l4-case`              | 4     | alternative | `case` naming the goals of `constructor`                      |
| `l4-constructor`       | 4     | alternative | `constructor` with bullets                                    |
| `l4-exact-nested`      | 4     | alternative | applications nested in the anonymous constructor              |
| `l4-have-by`           | 4     | alternative | `have`s proved by nested tactic blocks                        |
| `l4-have-untyped`      | 4     | alternative | `have` without types                                          |
| `l4-nested-by`         | 4     | alternative | `by` blocks inside the anonymous constructor                  |
| `l4-partial-app`       | 4     | alternative | a hypothesis applied to the element only                      |
| `l4-refine`            | 4     | alternative | `refine ⟨?_, ?_⟩` with bullets                                |
| `l4-refine-partial`    | 4     | alternative | `refine` with one part given and one hole                     |
| `l4-show`              | 4     | alternative | `show` unfolding the intersection by hand                     |
| `l4-term`              | 4     | alternative | term mode one-liner                                           |
| `l5-apply`             | 5     | alternative | `apply subset_inter` with bullets                             |
| `l5-direct`            | 5     | alternative | term mode, lemmas nested                                      |
| `l5-exact-direct`      | 5     | alternative | `exact` with nested lemmas                                    |
| `l5-explicit`          | 5     | alternative | implicit arguments given with `@`                             |
| `l5-have-swapped`      | 5     | alternative | the `have`s in the other order, untyped                       |
| `l5-lemma-as-function` | 5     | alternative | earlier theorems applied to the element                       |
| `l5-obtain`            | 5     | alternative | `obtain`, then the parts swapped                              |
| `l5-pattern-term`      | 5     | alternative | pattern-matching `fun`                                        |
| `l5-scratch`           | 5     | alternative | from scratch, without earlier levels                          |
| `l5-scratch-term`      | 5     | alternative | from scratch in term mode                                     |
| `l5-underscores`       | 5     | alternative | arguments left as `_`                                         |
| `l6-apply-ext`         | 6     | alternative | `apply Set.ext`                                               |
| `l6-bullets`           | 6     | alternative | `ext` with bullets                                            |
| `l6-case`              | 6     | alternative | `case` naming the goals of `ext`                              |
| `l6-case-reversed`     | 6     | alternative | the goals of `ext` proved in the other order                  |
| `l6-exact-ext`         | 6     | alternative | `exact Set.ext …`                                             |
| `l6-have-first`        | 6     | alternative | both inclusions as `have`s first                              |
| `l6-refine`            | 6     | alternative | `refine Set.ext ?_ ?_`                                        |
| `l6-scratch`           | 6     | alternative | from scratch, without earlier levels                          |
| `l6-scratch-term`      | 6     | alternative | from scratch in term mode                                     |
| `l6-seq-apply`         | 6     | alternative | `<;>` running one tactic on both goals                        |
| `l6-term`              | 6     | alternative | term mode                                                     |
| `l6-underscores`       | 6     | alternative | arguments left as `_`                                         |
| `p-done-early`         | 1     | partial     | `done` with a goal left                                       |
| `p-empty-by`           | 1     | partial     | nothing after `by` yet                                        |
| `p-intro-only`         | 1     | partial     | only the introduction so far                                  |
| `p-statement-only`     | 1     | partial     | the statement without a proof                                 |
| `p-have-unfinished`    | 2     | partial     | `have` typed up to `:=`                                       |
| `p-intro-x-only`       | 2     | partial     | only the element introduced                                   |
| `p-sorry-end`          | 2     | partial     | `sorry` as the last step                                      |
| `p-sorry-whole`        | 2     | partial     | `sorry` as the whole proof                                    |
| `p-sorry-term`         | 3     | partial     | `sorry` in term mode                                          |
| `p-constructor-one`    | 4     | partial     | one of the two goals of `constructor` proved                  |
| `p-have-by-empty`      | 4     | partial     | a nested `by` with nothing in it yet                          |
| `p-nested-by-sorry`    | 4     | partial     | `sorry` inside a nested `by`                                  |
| `p-sorry-have`         | 4     | partial     | one `have` proved by `sorry`                                  |
| `p-term-hole`          | 4     | partial     | a `_` hole in a term                                          |
| `p-unclosed-bracket`   | 4     | partial     | an anonymous constructor not closed yet                       |
| `p-ext-one-goal`       | 6     | partial     | one of the two goals of `ext` proved                          |
| `p-ext-only`           | 6     | partial     | `ext` and nothing else                                        |
| `b-two-theorems`       | –     | broken      | two theorems in one file, the second broken                   |
| `b-extra-tactic`       | 1     | broken      | a tactic after the proof is finished                          |
| `b-intros`             | 1     | broken      | `intros` does not unfold the subset, so nothing is introduced |
| `b-too-many-intro`     | 1     | broken      | one name too many in `intro`                                  |
| `b-typo-tactic`        | 1     | broken      | a misspelled tactic                                           |
| `b-unknown-hyp`        | 1     | broken      | a hypothesis name that does not exist                         |
| `b-have-mismatch`      | 2     | broken      | a `have` whose proof does not have its type                   |
| `b-wrong-proj`         | 2     | broken      | the wrong projection: a type mismatch                         |
| `b-missing-arg`        | 4     | broken      | a hypothesis applied to too few arguments                     |
| `b-wrong-order-pair`   | 4     | broken      | the two parts of the pair in the wrong order                  |
| `b-swapped-args`       | 5     | broken      | the arguments of an earlier theorem swapped                   |
| `b-unknown-lemma`      | 5     | broken      | a theorem name that does not exist                            |
| `b-ext-wrong-second`   | 6     | broken      | the second goal of `ext` given the first goal's proof         |
| `u-by-cases`           | 1     | unsupported | a case distinction                                            |
| `u-rename-i`           | 1     | unsupported | `rename_i` after anonymous introductions                      |
| `u-revert`             | 1     | unsupported | `revert` and a second `intro`                                 |
| `u-simp`               | 1     | unsupported | `simp` closing the goal                                       |
| `u-trivial`            | 1     | unsupported | `trivial`                                                     |
| `u-unfold`             | 1     | unsupported | `unfold` after `show`                                         |
| `u-first`              | 2     | unsupported | `first` choosing the alternative that works                   |
| `u-grind`              | 2     | unsupported | `grind`                                                       |
| `u-point-free`         | 2     | unsupported | point-free term                                               |
| `u-suffices`           | 2     | unsupported | `suffices`                                                    |
| `u-and-symm`           | 5     | unsupported | a core theorem outside the demo                               |
| `u-all-goals`          | 6     | unsupported | `all_goals`                                                   |

<!-- entries:end -->
