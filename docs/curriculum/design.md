# References
The [Lean 4 Game Server](https://adam.math.hhu.de/) hosts multiple games that people have created that are in the same style as the Natural Number Game, i.e. each level requires using tactics to prove a statement in Lean. The courses available on here cover a wide variety of different content, and could be useful as references for creating the levels for Distill:

| Game                     | Topics Covered                                                                                                   |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| Natural Number Game      | Properties of natural numbers, from the Peano axioms                                                             |
| Scribble                 | Wide variety of topics, sticking to roughly what you'd learn in Sets and Logic                                   |
| Real Analysis, The Game  | Real Analysis                                                                                                    |
| Set Theory Game          | Set Theory                                                                                                       |
| A Lean Intro to Logic    | Propositional Logic                                                                                              |
| Reintroduction to Proofs | Lower-level Lean concepts (mostly things like logic and functions), aims to give a more conceptual understanding |
| Knights and Knaves Game  | Propositional Logic, through logic puzzles                                                                       |
| Linear Algebra Game      | Linear Algebra                                                                                                   |
# Mathematical Topics
For the initial version of Distill, we should stick to the material that is covered in [Richard Hammack's Book of Proof](https://richardhammack.github.io/BookOfProof/). This leaves us with content that should be familiar even with students who have just started tackling proof-based mathematics, and still allows us to cover all of the common proof techniques. A quick summary of what this textbook covers:
- Set Theory and Propositional Logic
- Direct Proof, Contrapositive Proof, Proof by Contradiction, Induction
- Relations, Functions, Cardinality
# Lean Topics
Any type that we use should be defined within Distill rather than using the Lean equivalent. This prevents users from using pre-existing theorems from levels they haven't completed. We also shouldn't use Mathlib at all in our initial version.

Here are the tactics I think we should and shouldn't support initially. This is roughly organized based on implementation difficulty. In general for now we should only support tactics that represent a single logical step in English.

| Tactic             | What It Does                                                                                      | Support?                               |
| ------------------ | ------------------------------------------------------------------------------------------------- | -------------------------------------- |
| `rfl`              | Proves `x ~ x` via the reflexive property                                                         | Yes                                    |
| `rw`               | Substitute `y` for `x` based on a statement of the form `x ~ y`                                   | Yes                                    |
| `assumption`       | Shows the goal is equal to one of the hypotheses                                                  | Yes                                    |
| `have`             | Defines an auxiliary term that must be proven.                                                    | Yes                                    |
| `intro`            | Introduces any hypotheses (e.g. in a `x -> y`, we suppose that `x`)                               | Yes                                    |
| `contradiction`    | Proves something because we have a contradiction                                                  | Yes                                    |
| `induction`        | Proves something by induction                                                                     | Yes                                    |
| `constructor`      | Uses the constructor for an object to create subgoals                                             | Yes                                    |
| `cases`            | Splits an expression into cases based on its form (e.g. `a or b` means either `a` or `b` is true) | Yes                                    |
| `left`/`right`     | Choose what side of an `or` to prove                                                              | Yes                                    |
| `use`              | Picks a witness for an existential quantifier                                                     | Yes                                    |
| Term Mode          | A proof term that doesn't use tactics                                                             | No, requires conversion into tactics   |
| `exact`            | Shows the goal is exactly a proof term                                                            | No, requires term mode support         |
| `apply`            | Uses part of a function/implication, then we must prove the rest                                  | No, requires term mode support         |
| `calc`             | Uses a sequence of equalities/inequalities to prove something                                     | No, requires special handling          |
| Automation Tactics | Uses an algorithm to prove statements of a certain form                                           | No, requires a trace for detailed info |

# Structuring Levels, Paths, and Worlds
- Users should eventually be allowed (and sometimes encouraged) to create lemmas for their theorem, however for our initial version we should stick to requiring a single Lean theorem.
- There should be a mix of levels that do and don't use a guided translation. Harder levels that are required for progression should always use a guided translation.
- Every path should connect concepts that are conceptually related if not dependent on previous theorems.
- Each world should cover a large mathematical topic, e.g. a Basics world, Linear Algebra, Real Analysis, etc.
- Users are only allowed to use tactics and theorems defined/unlocked in levels they have completed.
# Initial Curriculum Structure
For now, we can stick to one world, covering Sets and Logic content. I would divide it into a few different chapters/paths

A. Introduction - a few very basic problems to get warmed up
B. Set Theory - how sets are defined in Lean, proofs involving sets
C. Propositional Logic
D. Proof Techniques - direct proof, proof by contrapositive, proof by contradiction
E. Relations and Functions
F. Quantifiers
G. Induction
H. Cardinality

The structure of how these are unlocked can be pretty open:
```
     A
   / | \
  B  C  D
  |<>|<>|
  E  F  G
   \ | /
     H
  
```

I use the `<>` to indicate that the three branching paths will depend on each other at various sections (for instance, injectivity requires quantifiers, proof by contraposition requires some propositional logic, etc.)

Tactics are always introduced when they need to be used for the first time.
