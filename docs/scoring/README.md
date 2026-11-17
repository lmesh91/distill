# Level scoring

Distill does not combine a completed level into one number. It records three stats and shows
all of them. Lower is better for each:

| Stat             | Measures                                   |
| ---------------- | ------------------------------------------ |
| **Attempts**     | Proof checks it took to first solve it     |
| **Time**         | Time from starting to first solving it     |
| **Proof length** | Lean tokens in the shortest accepted proof |

Attempts and time describe the _first_ solve and never change after it. Proof length is the
best over every accepted proof, so a learner can come back and shorten a solved level.

## Definitions

```ts
interface LevelScore {
	attempts: number; // >= 1
	elapsedMs: number; // >= 0
	proofTokens: number | null; // >= 1; null when it could not be counted
}
```

All times are server timestamps. Client clocks are never used.

### Attempts

The number of `LevelAttempt` records for the user and level with `submittedAt` at or before the
first accepted attempt, including that accepted attempt. Every graded check counts, whatever
the rejection reason (compile errors, wrong theorem, introduced axioms).

Note that `UserLevelProgress.attemptCount` keeps counting checks made after completion, so it
is only correct at the moment of first acceptance. Take the value then, or recompute it from
the attempts collection.

### Time

`completedAt − startedAt` on `UserLevelProgress`, where `completedAt` is the first accepted
attempt's `submittedAt`.

`startedAt` is set by the first autosave or proof check, so the clock starts at the learner's
first edit, not when they open the level. It is wall-clock time: it includes breaks and a tab
left open overnight. Measuring only active time would need client heartbeats and is out of
scope. If `startedAt` is missing, use the first attempt's `submittedAt`.

### Proof length

The number of Lean tokens the learner wrote to prove the theorem, counted on an accepted
submission's `source`.

A **token** is an atom or identifier in the syntax tree Lean's parser produces from the
source:

- Keywords and symbols are one token each: `by`, `intro`, `exact`, `:`, `∈`, `∧`, `(`, `⟨`,
  `,`, `fun`, `=>`, `;`, `·`.
- A literal is one token: `0`, `"abc"`.
- A dotted identifier counts each part and each dot: `hx` is 1 token, `hx.left` and
  `Set.mem_inter` are 3. This makes `hx.left` cost the same as `hx.1`, which Lean parses as
  `hx`, `.`, `1`.
- Only text the learner typed counts. Comments, doc comments and whitespace are not in the
  syntax tree. Lean also adds a few nodes with no source text of their own, such as the hygiene
  info inside `(hx)` and the end-of-input marker; skip any atom or identifier whose source info
  is not `original`, and any empty atom.

**What is counted:**

1. The body of the target theorem (the declaration whose full name is
   `verification.theoremName`): its value after `:=`, not counting the `:=` itself but
   including `by`. The theorem's header is not counted, even if the learner edited it.
2. Every other top-level command in the submission that does not appear in `starterCode`
   (compared by token sequence), counted in full. This covers helper lemmas, `def`s, `macro`s,
   `notation` and `open`s the learner added, so work can't be hidden outside the theorem.

Commands that came from `starterCode` unchanged (imports, `open`, `variable`, `namespace`) are
not counted.

Counting tokens rather than tactics means a long hand-written proof term can't beat a few
well-chosen tactics just because it is one "step".

The source must be parsed the way Lean elaborates it, one command at a time in the environment
built so far (for example with `IO.processCommands`, which returns each command's syntax).
Notation from `Distill`, such as set-builder `{x | p x}`, and any notation the learner defines
change how later commands parse, so a parser run without the environment gets the wrong
tokens. This runs in the Lean worker alongside verification, and only for accepted results. If
the target theorem can't be found in the parsed syntax, record `null`. A `null` never counts as
a best and is shown as "—".

## Best result

Keep one `LevelScore` per user and level:

- `attempts` and `elapsedMs` are set at first completion and never updated.
- `proofTokens` is replaced whenever a later accepted proof has fewer tokens.

The stats are never weighted against each other, so there is no single "best overall" ranking.

## Examples

Proofs from `lean/Distill/Levels/Demo.lean`. Only the counted part is shown.

| Level                | Proof                                                     | Tokens |
| -------------------- | --------------------------------------------------------- | ------ |
| `subset_rfl`         | `by intro x hx exact hx`                                  | 6      |
| `subset_rfl`         | `fun x hx => hx`                                          | 5      |
| `inter_subset_left`  | `by intro x hx have h : x ∈ A ∧ x ∈ B := hx exact h.left` | 20     |
| `inter_subset_left`  | `by intro x hx exact hx.left`                             | 8      |
| `inter_subset_left`  | `by intro x hx exact hx.1`                                | 8      |
| `inter_subset_right` | `by intro x hx exact hx.right`                            | 8      |

Line breaks and comments inside the proof don't change these counts. The `have` in
`inter_subset_left` costs 12 tokens: `have h : x ∈ A ∧ x ∈ B := hx`.

**A full score.** A learner makes their first edit to `inter_subset_left` at 10:00:00 and
checks a proof with a typo at 10:02:30 (rejected, diagnostics). They check the 20-token
proof at 10:04:10 (accepted). Score: 2 attempts, 4m 10s, 20 tokens.

The next day they check the 8-token proof (accepted). Their best becomes 2 attempts, 4m 10s,
8 tokens. Attempts and time are unchanged, because the level was already solved.

**A helper lemma.** If the learner adds

```lean
theorem my_left {x : α} {A B : Set α} (h : x ∈ A ∧ x ∈ B) : x ∈ A := h.left
```

and proves the level with `by intro x hx exact my_left hx`, the lemma counts in full. That is
33 tokens for the lemma plus 7 for the body, 40 in total.

**A macro.** Hiding the proof in a tactic macro doesn't help either:

```lean
macro "solve" : tactic => `(tactic| (intro x hx; exact hx.left))
```

costs 17 tokens, and the body `by solve` 2 more, so 19 in total against 8 for writing the
tactics directly.
