# The Pipeline

This file describes how a Lean proof becomes the English the level page shows, stage by stage, and where each stage can be extended. The intermediate representations themselves are described in [ir.md](ir.md).

```mermaid
flowchart LR
    T[InfoTree] -- extract --> P[Proof IR]
    P -- present --> R1[Presentation IR]
    R1 -- normalize --> R2[Presentation IR]
    R2 -- render --> E[English]
```

| Stage | Function | Module |
|---|---|---|
| Extract | `extractProofs` | `Distill.Informalizer.Extract` (see [extraction.md](extraction.md)) |
| Present | `present` | `Distill.Informalizer.Present` |
| Normalize | `normalize` | `Distill.Informalizer.Normalize` |
| Render | `render` | `Distill.Informalizer.Render` |

A fifth function, `verify` (`Distill.Informalizer.Verify`), is not a stage: it checks the Presentation IR against the Proof IR, for tests and debugging.

`informalize` in `Distill.Informalizer.Pipeline` runs the last three on one Proof IR, and `informalizeTree` runs all four on the InfoTree of an elaborated command. Like extraction, the later stages work from InfoTrees alone and do not fail because of the proof they are given.

Every stage has a fallback, so the pipeline produces output for any proof. Supporting a construct means replacing a fallback with something better in the stage it belongs to.

## Present

`present` builds the first Presentation IR of a proof. It says no more than the Proof IR does:

- **Statement.** Each binder of the statement becomes an object in a group of its own, or a hypothesis if it is a proof of a proposition. They stay in the order they were written, except that a hypothesis which a later binder is stated with becomes a property of the object before it. The conclusion is the goal the proof starts with.
- **Proof.** Each surface node becomes an `untranslated` step, in execution order. An `untranslated` step only names its node, and is shown as the Lean the user wrote. Its `evidence` is the part of the Lean proof the node is responsible for.

Translating a tactic means giving its node steps of other kinds here (`fix`, `assume`, `derive`, …).

## Normalize

Normalization is a sequence of *passes*. A pass rewrites a `PresentedDecl` into one that says the same thing and reads better. It does not produce English.

```lean
structure Pass where
  name : Name
  order : Nat := 500
  run : PresentedDecl → NormalizeM PresentedDecl
```

A pass can read the Proof IR, and runs with every hypothesis of the proof in the local context, so it can type-check and compare the expressions it sees.

Passes run in ascending `order`. Built-in passes are listed in `Distill.Informalizer.passes`. A library adds one without changing Distill:

```lean
@[distill_normalizer] def myPass : Pass where
  name := `MyLibrary.myPass
  run d := …
```

A pass that throws is skipped, so a pass only has to handle the proofs it was written for.

A pass must not change what the presentation says. It may:

- **Move things**: regroup objects, turn a hypothesis into a property of an object, reorder. An object can be introduced earlier or later than Lean binds it, as long as everything its type and properties mention is introduced before it.
- **Restate an expression** as one that reads better, recording the old expression in `MathExpr.history` (a `Restatement`). Without a proof the two must be definitionally equal; otherwise the pass gives a proof of `before = after` or `before ↔ after`.
- **Change steps**, taking their `evidence` along.

[`verify`](#verify) checks all of this, so a test of a pass should show that its output verifies.

### Built-in passes

| Pass | Order | What it does |
|---|---|---|
| `membershipAsProperty` | 100 | A hypothesis `x ∈ S` about an object `x` becomes a property of `x`, so the two are introduced together ("let $x \in S$"). If `x` is bound before `S`, it is moved after it. |
| `groupObjects` | 900 | Objects with the same type and the same properties are put in one group ("let $A$, $B$ and $C$ be sets", "let $x, y \in A$"), even when other binders separate them. |

## Render

`render` writes the Presentation IR as English: a few sentences for the statement and one piece of text per step. The text is the rich text the web app displays, in which `$…$` is LaTeX and `` `…` `` is Lean code.

Rendering only decides wording. What is said, and in which order, was decided by the Presentation IR.

### Statements

The statement introduces the object groups in order, then states the hypotheses and the conclusion:

> Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.

- A group is introduced by its noun ("let $A$ and $B$ be sets"), or by its membership property alone ("let $x, y \in A$"). Other properties follow with "such that".
- An implicit object (`{α : Type}`) is introduced only if the rest of the text names it or it has properties. A set is then "a set of elements of $\alpha$" instead of "a set".
- Hypotheses that are plain formulas are joined into "If … and …, then …". Otherwise they are stated as "Suppose that … and that …. Then …".
- Only a proof of a proposition has a statement: `def n : Nat := by …` has steps and nothing else.

### Expressions

An expression can be written three ways, and a *translator* says how for the expressions headed by one constant:

| | For | Result | Example |
|---|---|---|---|
| Math | any expression | a LaTeX formula with its precedence | `A ∩ B` ⟶ `A \cap B` |
| Noun | a type | what its elements are called | `Set α` ⟶ "a set", "sets" |
| Prose | a proposition | a clause | `p ∧ q` ⟶ "$p$ and $q$" |

A proposition is written by its prose translator if it has one, else as a formula, else as Lean code. A formula is all or nothing: if any part of an expression has no LaTeX, the whole expression is shown as code.

The built-in translators (`Distill.Informalizer.Render.Expr`) cover the constructs of the demo levels:

| Construct | Rendering |
|---|---|
| `Set α` | "a set", or "a set of elements of $\alpha$" / "a set of sets" when the elements are named |
| `Type`, `Prop` | "a type", "a proposition" |
| any other type `T` | "an element of $T$", or "a term of type `T`" if `T` has no formula |
| `x ∈ S`, `A ⊆ B`, `A ∩ B`, `A ∪ B`, `a = b` | `x \in S`, `A \subseteq B`, `A \cap B`, `A \cup B`, `a = b`; `∩` and `∪` are parenthesized when mixed |
| `{x \| p x}` | `\{x \mid p\}` |
| `p ∧ q`, `p ∨ q` | "$p$ and $q$", "$p$ or $q$"; `\land`, `\lor` inside a formula or when the two are mixed. An "or" clause is never listed with "and" |
| `p → q` | "if $p$, then $q$"; `\to` inside a formula |
| `∀ x, p x` | "for every set $S$, …", "for all sets $S$ and $T$, …", and "for every $x \in A$, …" for `∀ x, x ∈ A → …`; `\forall x \in A,\ …` inside a formula |
| a variable | its name: `α` ⟶ `\alpha`, `h₁` ⟶ `h_{1}`, `hAB` ⟶ `\mathit{hAB}` |

A library adds translators for its own definitions without changing Distill. Each is handed a `Renderer` to write subexpressions with, and returns `none` for an expression it does not handle, in which case the next translator for the constant is tried. `r.math` records which variables the text names; a translator that writes a variable's name itself calls `mention`, or an implicit object it names is not introduced.

```lean
@[distill_math Set.compl] def mathCompl : MathTranslator := fun r e => do
  unless e.isAppOfArity ``Set.compl 2 do return none
  let some a ← r.math e.appArg! | return none
  return some { tex := s!"{a.at 1024}^c", prec := 1023 }

@[distill_prose Disjoint] def proseDisjoint : ProseTranslator := fun r e => do
  let some a ← r.math (e.getArg! 1) | return none
  let some b ← r.math (e.getArg! 2) | return none
  return some { text := s!"${a.tex}$ and ${b.tex}$ are disjoint" }

@[distill_noun Nat] def nounNat : NounTranslator := fun _ _ =>
  return some { singular := "natural number", plural := "natural numbers" }
```

### Steps

Proof steps are still rendered by the fallback, which shows the Lean:

> Apply `intro x hx`.

## Verify

`verify` checks a `PresentedDecl` against the Proof IR it came from, with Lean's type checker. It is to the Presentation IR what the proof term check of `#proof_ir` is to the Proof IR.

- **Statement.** The presented statement is `∀ objects and their properties, hypotheses → conclusion`, in the order the presentation introduces them. It has to be the original statement: the same term, definitionally equal, or equivalent by a proof of `original ↔ presented` that `verify` builds and type-checks. That proof reorders the binders, and uses the proofs recorded in `MathExpr.history` where a hypothesis or the conclusion was restated.
- **Proof.** The `evidence` of the steps has to add up to a term without holes, and that term, carried over the equivalence, has to prove the presented statement. Only the sum is checked, not which step carries which piece.

A presentation that drops a hypothesis, restates something as a statement that is not equivalent, or loses the evidence of a step does not verify. An unfinished proof is reported as incomplete.

`verify` type-checks whole proof terms, so it is run by `#informalize` and the tests, not by the web app. It does not support restating the *type* of an object other than definitionally.

## The web app

The level page calls the RPC method `Distill.translate` (`lean/Distill/Translate.lean`) through the editor's language server connection once Lean has checked the document. It runs the pipeline on the InfoTree of every command and returns the English line by line: a theorem's statement at the line of its name, and each step at the line its tactic starts on.

## Inspecting and testing

`#informalize` before a command prints the Presentation IR (after normalization), the English of its proofs, and what `verify` finds, with lines relative to the command. `#informalize_statement` prints only the English statement and how the presented statement relates to the original.

```lean
import Distill.Informalizer.Frontend

#informalize
theorem t (p q : Prop) (hp : p) (hq : q) : p ∧ q := by
  exact ⟨hp, hq⟩
```

The golden tests in `lean/Tests/Informalization` use them on proofs and statements of different shapes and on passes and translators from a library, and run the whole pipeline on the demo levels the way the web app does. Run them with `lake test` in `lean/`. When the output changes on purpose, update the docstring above the affected `#guard_msgs`.
