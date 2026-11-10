# Extracting the Proof IR

`Distill.Informalizer.Extract.extractProofs (tree : InfoTree) : IO (Array ProofIR)` turns the InfoTree of an elaborated command into Proof IR. It only needs the InfoTree, so it runs wherever InfoTrees are available: in the language server on a document's snapshots, or after elaborating source text (`Extract.Frontend`).

Extraction records what Lean did, not what it means. Deciding that an `intro` fixes a variable or assumes a hypothesis, or that a step unfolds a definition, is left to translation.

## How it works

Each proof goes through five steps:

1. **Find the proofs** (`Extract/Tree.lean`). A declaration body that proves a proposition gives one `ProofIR`, whether it is a `by` block or a term. A term body is treated as if the proof started with a `refine` of that term, with each `by` block in it as a goal the `refine` left.
2. **Drop what was undone.** Lean records every tactic it ran, including ones that failed or were backtracked over. A node whose work did not reach the state execution continued from is discarded.
3. **Give each node a role.** *Surface* nodes are the tactics the user wrote. *Structural* nodes only pass goals to user-written tactics nested in them (`·`, `first`, tactic sequences). *Inner* nodes ran on behalf of a surface node, such as a macro's expansion.
4. **Build the goal graph** (`Extract/Goals.lean`). Every goal records the node that assigned it and its proof, one level deep: subgoals stay as metavariables, so the proofs form a tree.
5. **Fill in the details** (`Extract/Recognizers.lean`). A recognizer for the tactic's syntax kind says what it did, such as which hypotheses `intro` added. A tactic with no recognizer is still fully present in the goal graph.

For example,

```lean
theorem two_blocks (A B : Set α) : A ∩ B ⊆ A ∧ A ∩ B ⊆ B :=
  ⟨by intro x hx; exact hx.1, fun x hx => by exact hx.2⟩
```

gives one proof, whose first node has the detail `.term .refine ⟨?g1, fun x hx => ?g4 x hx⟩`. Its goals are `?g1` and `?g4`, and the nodes of each `by` block are nested under it.

Nothing in these steps lists the tactics it knows about. Steps 2 and 3 go by the shape of the InfoTree and the proof states, so a library's tactics and combinators are handled the same way as Lean's, and step 5 can be extended by [registering a recognizer](#recognizers). The details below are only needed when working on one of these steps.

## Details

### Which proofs are extracted

Bodies are found through the `BodyInfo` nodes Lean puts in the InfoTree, which also cover the declarations of a `mutual` block, definitions by equations, and `where` and `let rec` bodies. Each of those is its own `ProofIR`.

The outcome depends on the body:

| Body | Proof IR |
| --- | --- |
| a `by` block | one `ProofIR`, `isDeclBody` true (also for data: `def x : Nat := by exact 0`) |
| a term of a proposition | one `ProofIR`, `isDeclBody` true, with a made-up first node |
| a term of a type that is not a proposition | one `ProofIR` for each outermost `by` block in it, `isDeclBody` false |

`decreasing_by` proofs are not extracted.

When `isDeclBody` is false, `statement` is only the goal of the block, and its binders include the variables the surrounding term bound. A `by` block in any other position outside a body gets the same treatment.

The first node of a term proof stands in for a tactic that assigned the body to the goal. Lean has no metavariable for a declaration's body, so that goal is made up too (`termProofGoal`). The node is a surface node whose detail is `.term .exact e`, or `.term .refine e` when the body has `by` blocks, whose goals are then its `goalsAfter`. The `by` blocks' nodes are nested in it, as they are in a tactic like `exact ⟨by …, by …⟩`.

### Undone tactics

Nothing in the InfoTree says that a tactic failed. A node is discarded, along with all nodes inside it, if the proof states show one of these:

- It, or a `by` block inside it, assigned a goal that is unassigned in the state execution continued from: the next sibling's starting state, or the parent's final state for the last child. This finds the alternatives of `first`, the last iteration of `repeat`, everything inside `fail_if_success`, and the same in any library combinator that backtracks. A `by` block is compared with its parent's final state only, as terms choose the order `by` blocks run in.
- It assigned a goal that has a different assignment in the end. This finds a tactic that undoes a run and then closes the goal another way (`try?`).
- It left its goals as they were and assigned nothing, and neither did any node inside it. A tactic that failed before changing anything looks like this. So do `skip` and `done`, which lose nothing by being dropped. Syntax tokens that have nodes of their own (`;`) are exempt, and so are `by` blocks, since an unfinished one is the only node to report its goal.

A discarded node is inner and has no detail, and goals only discarded nodes mention are left out of the goal table. A recognizer registered for a tactic that changes nothing therefore never runs. A `by` block in a `simp` argument counts as undone too: `simp` rolls back its goal after abstracting its proof into the lemma, so the block's nodes are inner and the proof stays inlined.

### Roles

A node *delegates* if all of these hold:

- it elaborated no term and assigned no goal itself, other than renaming one (`case`) or closing it with an error (`·`, on recovering from a failure);
- none of its live children that are not user-written tactics assigned a goal;
- at least one user-written tactic is below it, through other delegating nodes.

That separates `· intro x` from the macro `intro x hx`: both do nothing themselves, but the work in the macro is done by its expansion, which the user did not write. So `first`, `try`, `repeat`, `all_goals`, `<;>`, `with_reducible` and library combinators are structural without being listed anywhere, and `linarith` or a macro like `macro "auto" : tactic => …` remains surface.

Only the `tactic` syntax category counts as user-written tactics, so the steps inside `conv` are inner.

Then:

- A user-written tactic that does not delegate is surface, also when nested in another tactic (the tactics of `have h : t := by …`).
- A node that delegates is structural if the user wrote it or no surface node encloses it.
- Anything else inside a surface node is inner. `ProofIR.nestedSurface` finds the surface nodes inside a node, looking through the others.

### Assignments

A goal is assigned by the innermost node that assigned it, which can be an inner node (`intro x hx` assigns its goal in the inner `intro x`). The proof is the assigned term with everything instantiated except other goals. A subgoal occurs applied to terms for the hypotheses it adds (`ProofIR.newHyps`), in order:

| Tactic or term | Proof |
| --- | --- |
| `intro x` | `fun x => ?g1 x` |
| `have h : t := v` | `have h := v; ?g2 h` |
| `ext` | `Set.ext ?g1 ?g2` |
| `exact ⟨by …, by …⟩` | `⟨?g3, ?g4⟩` |
| `cases h with \| inl hp => …` | `Or.casesOn … (fun hp h => ?g1 hp) …` |
| `rw [e] at h1 h2` | `?g1 (Eq.mp … h1) (Eq.mp … h2)` (the terms the new hypotheses stand for) |

`ProofIR.withContext` declares each goal as a function of its new hypotheses, so that these terms type-check.

Lean assigns a goal the term with its nested `by` blocks already filled in. Extraction recovers the version with their goals from the terms the tactic elaborated, or, for terms a tactic builds itself (`calc` gives `trans ?g1 ?g3`), by finding the nested goal's proof in it. A proof that occurs more than once in the term (`rw [show b = c by exact h2] at h1` with `h2` used again) stays inlined; the goal's parent is then still the goal it is inlined in.

### Parents and tags

A goal's parent is the goal whose proof mentions it. A goal no proof mentions (inlined, or created by a tactic that then failed) gets the goal of the innermost tactic around it.

A goal's case tag is the one it had where it first appears (`case` and `next` clear it afterwards).

### Recognizers

Recognizers fill in `detail`. A library registers one for its tactic the way it registers an elaborator:

```lean
@[distill_recognizer myIntro] def recognizeMyIntro : Recognizer := fun r => do
  let some before := r.mainGoal? | return none
  let [after] := r.newGoals | return none
  return some (.intro (RecognizerInput.newHyps before after))
```

A recognizer can return any `TacticDetail`, including `.custom` with its own data for a translation handler to read. Registered recognizers for a syntax kind are tried first, the most recent first, then the built-in one; returning `none` or throwing moves on to the next. The registering module must be imported by the file being extracted. The built-in recognizers are not attributes, so they work in files that import nothing from Distill.

| Tactic | Detail |
| --- | --- |
| `intro`, `intros` (names only, no patterns) | `.intro hyps`: the hypotheses added to the goal |
| `have h : t := e` | `.have h (some e) none` |
| `have h : t := by tac` | `.have h none (some g)`, where `g` is the goal `tac` proves |
| `exact e`, `apply e`, `refine e` | `.term mode e`, with `e` as assigned to the goal (implicit arguments filled in) |
| `ext` (no patterns) | `.term .apply e`, like `apply` of the extensionality lemma |

A recognizer only reports a term the node itself assigned. A node with no recognizer that succeeds gets `.unrecognized`, and its goals and assignments are still recorded.

### Hypotheses

A recursive proof calls the declaration being defined, and a proof can call its `where` and `let rec` helpers; while the proof is elaborated these are local hypotheses. One that a proof uses is in the `hyps` table with `isRecursive` set, and in no goal's context. A `let rec` written as a tactic is lifted out only after the `by` block ends, so its use stays an unassigned metavariable in the IR.

`value?` is set for `let`-style hypotheses. `replaces?` links a hypothesis to the one it replaces: from Lean's own alias information when there is some, otherwise inferred (`fromAlias := false`) when a tactic whose `at` clause names a hypothesis (`rw … at h`, `at *`) leaves a goal with a new hypothesis of that name in place of the old one. Other tactics that reuse a name (`induction n with | succ n ih`) are not linked.

### Unfinished proofs and errors

Unfinished proofs, `sorry` and elaboration errors still give a Proof IR: an unfinished goal at the top level has no assignment, and `sorry` or an error appears as a `sorryAx` term. Inside `·`, `case`, `have … := by` or a nested `by`, Lean's error recovery closes an unfinished goal with `sorryAx _ true` (synthetic), which tells it apart from a `sorry` the user wrote.

### Using the result

Parts of the tree that asynchronous elaboration left as holes must be substituted before extraction (`InfoState.substituteLazy`).

Expressions in a `ProofIR` refer to its hypotheses and goals by id. `ProofIR.withContext` runs a `MetaM` action with all of them declared, so the expressions can be type-checked or pretty-printed, and `ProofIR.proofTerm?` puts the assignments back together into the proof term.
