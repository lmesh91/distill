# Intermediate Representations

This file serves to document the intermediate representations used by Distill's informalization system.
- The **Proof IR** describes every logical step of a proof in Lean. It stores the sequence of steps (tactics) that were used in the proof as well as all of the extra context created during the proof-checking process.
- The **Presentation IR** describes every logical step of a written proof. Some Lean tactics may need multiple logical steps in the Presentation IR, or vice versa.

For this document, I will use this proof as an example:

```lean
theorem intersection_subset {α : Type}
    (A B C : α → Prop)
    (hAB : ∀ x, A x → B x) :
    ∀ x, (A x ∧ C x) → (B x ∧ C x) := by
  intro x hx
  have hBx : B x := hAB x hx.1
  exact ⟨hBx, hx.2⟩
```

It proves that for any sets $A,B,C$, if $A \subseteq B$, then $A \cap C \subseteq B \cap C$. Note that in this proof, sets are represented by functions that map every element of a type to a proposition whose truth value determines whether the element is in the set. For instance $A=\{x \in \mathbb{N} \mid x>5 \}$ could be represented in Lean as
`def A (x : Nat) : Prop := x > 5`.

## Background - How Tactics Work

Before explaining the IRs, it is important to understand the basics of how mathematical proofs work inside of Lean.

Everything inside of Lean has a type, including propositions. We can prove a proposition by constructing an object whose type is the statement we want to prove. For example, within the example proof, `hAB x hx.1` is a term of type `B x` (aka $x \in B$), and `⟨hBx, hx.2⟩` is a term of type `B x ∧ C x` (aka $x \in B \text{ and } x \in C$).

However, for more complicated proofs, a term may end up becoming very long and difficult to understand. Therefore, proofs in Lean can be created using *tactics*, which are commands that tell the program how to construct a proof term and are designed to add a layer of abstraction which makes proofs easier to write. At each stage of a proof, there is a list of *goals* that we need to prove in order to complete the proof. These goals are *holes* in the proof term, which are the remaining things that need to be proved in order to fully create the term. Tactics are designed to fill in these holes with a term that may contain new holes, which create new goals. Our example proof starts with a single goal:

```
α : Type
A B C : α → Prop
hAB : ∀ (x : α), A x → B x
⊢ ∀ (x : α), A x ∧ C x → B x ∧ C x
```

The term next to the `⊢` is the *target*: we want to prove that $A\cap C\subseteq B\cap C$. The other terms are the *hypotheses*: that $\alpha$ is a type, $A,B,C$ are sets on that type, and $A\subseteq B$. Note that these are not all mathematical hypotheses; they also include objects such as the sets themselves and the type of their elements.

Let's look at the tactics used in our example:
- The `intro` tactic introduces new hypotheses based on the goal's type. In Lean, universal quantifiers and implications correspond to functions, so `intro x hx` creates a hypothesis `x` of type `α` and a hypothesis `hx` of `A x ∧ C x`. In an English proof, this would be analogous to saying something like "Let $x$ be an arbitrary element such that $x\in A\cap C$." After this tactic, `x` and `hx` were added as hypotheses, and the goal is now `B x ∧ C x`:
```
α : Type
A B C : α → Prop
hAB : ∀ (x : α), A x → B x
x : α
hx : A x ∧ C x
⊢ B x ∧ C x
```
- The `have` tactic constructs a proof term for a given type that is added as a hypothesis. In this example we create a hypothesis `hBx` of type `B x`, and prove it using `hAB x hx.1`. We use `hx.1` to get the first element of the conjunction `A x ∧ C x`, and apply `x` and this element to `hAB` to construct a term of type `B x`. In an English proof, this would be analogous to saying something like "Since $A\subseteq B$ and $x\in A$, we have that $x\in B$." After this tactic, `hBx` was added as a hypothesis:
```
α : Type
A B C : α → Prop
hAB : ∀ (x : α), A x → B x
x : α
hx : A x ∧ C x
hBx : B x
⊢ B x ∧ C x
```
- The `exact` tactic constructs a proof term for the goal itself. It uses the term `⟨hBx, hx.2⟩`, which uses `hBx` for the left side of the conjunction and the second element of `hx` for the right side of the conjunction. In an English proof, this would be analogous to saying something like "Since $x\in B$ and $x\in C$ (because $x\in A\cap C$), we have that $x\in B\cap C$ as desired. Thus $A\cap C\subseteq B\cap C$."

There are powerful tactics in Lean besides those used in this proof. For instance, some tactics can split a goal into multiple goals (such as `induction`), apply combinations of other tactics (such as `repeat`), or use an advanced algorithm to try constructing a proof term (such as `grind`).


## Proof IR

Here is the structure of the Proof IR:

```lean
structure ProofIR where
  decl : Name
  statement : Statement
  rootGoal : MVarId
  nodes : Array TacticNode
  goals : Std.HashMap MVarId GoalInfo
  hyps : Std.HashMap FVarId HypInfo
```

The core information about the proof is represented in three structures: `nodes` for tactics in the order that they are executed, `goals` for the goals used, and `hyps` for the hypotheses used. Also included is the name of the proof (`decl`), the statement being proven (`statement`), and the original goal before any tactics are applied (`rootGoal`).

Note that an `MVarId` is an identifier Lean gives to holes (so used by goals), while `FVarId` is an identifier Lean gives to local variables or hypotheses.

A `Statement` holds the following information:

```lean
structure Statement where
  binders : Array FVarId
  conclusion : Expr
```

The *binders* are what the statement declares before the colon (in our example, this is `α`, `A`, `B`, `C`, and `hAB`) while the conclusion is the initial goal (e.g. `∀ (x : α), A x ∧ C x → B x ∧ C x`). Note that only an ID for each binder is stored here; more information is stored in the hypotheses structure.

A `GoalInfo` holds the following information:

```lean
structure GoalInfo where
  mvarId : MVarId
  tag : Name
  target : Expr
  context : Array FVarId
  parent? : Option MVarId := none
  assignment? : Option Assignment := none
```

The ID of the goal is stored in `mvarId`, while the target (its type) is stored in `target`. The list of hypotheses is stored in `context`, and the parent goal (the goal that contains this goal as a hole) is in `parent?`.

The `tag` is a name that Lean assigns to each goal. Depending on which tactic created this goal, the name may or may not be useful.

The `Assignment` structure contains both the ID of the innermost tactic that assigned the goal and the "proof" of that goal. Note that when new goals are created, the proof depends on those goals being solved, so it is not necessarily a full proof of the goal. However, keeping these partial proofs is useful as it is the only reliable way of tracking how goals depend on other goals, and are useful when a translation depends on the proof term that was created.

A `HypInfo` holds the following information:

```lean
structure HypInfo where
  fvarId : FVarId
  userName : Name
  type : Expr
  value? : Option Expr := none
  binderInfo : BinderInfo := .default
  replaces? : Option HypLineage := none
```

It includes the ID (`fvarId`) and name (`userName`) of the hypotheses as well as its `type` and `value?` (when assigned to a specific value via `let` or `set`).

Some tactics can be used to rewrite hypotheses. Lean creates a new ID for the rewritten hypothesis, so the `replaces?` variable is used to track these changes.

For hypotheses originating from the proof statement, `binderInfo` documents what type of binder was used to introduce the variable. This often contains useful semantic information; an implicit binder like `{α : Type}` is inferred from the other arguments, so it should usually be omitted in the English translation. Meanwhile an instance binder like `[Finite G]` refers to a quality that `G` satisfies, so is often translated as an adjective in English.

Lastly, a `TacticNode` holds the following information:

```lean
structure TacticNode where
  id : Nat
  stx : Syntax
  elaborator : Name
  origin : SyntaxOrigin
  role : NodeRole
  goalsBefore : Array MVarId
  goalsAfter : Array MVarId
  children : Array Nat
  infoTreePath : Array Nat
  detail : TacticDetail := .unrecognized
```

It includes an ID (`id`), the syntax of the tactic (`stx`), the goals before and after the tactic was applied (`goalsBefore`, `goalsAfter`), the children of the tactic in the InfoTree (`children`), and the path to get to the tactic in the InfoTree (`infoTreePath`).

The `elaborator` is the name of the function that ran to process this tactic.

The `origin` is a `SyntaxOrigin` structure that includes information on what section of the code this tactic was written, and whether it was written in the original proof or generated by another tactic.

The `role` is a `NodeRole` enumeration that describes whether the tactic is structural (only hands goals to its children), surface (written by the user), or inner (generated by another tactic).

The `detail` contains any extra information needed for certain families of tactics. This part of the implementation is subject to heavy modification as more tactics are supported by the informalizer, but it can include things like evidence not present in the InfoTree from tactics like `grind`, or custom information that can be defined by those who want to extend the informalizer (e.g. for Mathlib-specific tactics).

Most tactics will have their own information defined in the `detail` field. As an example, the values of `detail` used in this proof are:
`.intro [x, hx]`
`.have hBx (some (hAB x hx.1)) none`
`.term .exact ⟨hBx, hx.2⟩`

## Presentation IR

Here is the structure of the Presentation IR:

```lean
structure PresentedDecl where
  decl : Name
  role : DeclRole
  objects : Array MathObject
  hypotheses : Array Claim
  conclusion : Claim
  proof : Block
```

The `decl` is the name of the proof in Lean, while the `role` is what type of proof it is (either a theorem, example, or lemma). Unlike in Lean, the objects and propositions in the "hypotheses" are separated into different structures (`objects` and `hypotheses`), while the `conclusion` is also a proposition. The `proof` is the proof itself.

A `Claim` holds the following information:

```lean
structure Claim where
  id : Nat
  prop : MathExpr
  hyp? : Option FVarId := none
```

It includes a unique ID, as well as its Lean proposition and optionally what hypothesis it was in the Lean proof.

Note that a `MathExpr` is used rather than a Lean expression (`Expr`). This type also stores a ledger of what changes were made to the expression, as well as a proof that the changes are correct, when it is not due to definitional equality.

A `MathObject` holds the following information:

```lean
structure MathObject where
  fvar : FVarId
  name : Name
  type : MathExpr
  value? : Option MathExpr := none
  instances : Array MathExpr := #[]
  properties : Array Claim := #[]
```

It stores the original Lean ID (`fvar`) and `name`, as well as its `type` and `value?` (if relevant).

The `instances` is a list of expressions corresponding to instances satisfied by the object (e.g. "G is a finite group"), while the `properties` is a list of properties of the object that can be treated as adjectives (e.g. "p is prime"). During normalization, properties are moved to be within the MathObject they are describing, resulting in a more natural English translation.

A `Block` is a sequence of steps, in the order they should appear in the English proof, that proves a goal (described in `goal?`).
```lean
structure Block where
  goal? : Option Claim := none
  steps : Array ProofStep
```

The information in a `ProofStep` itself is more interesting:

```lean
structure ProofStep where
  id : Nat
  kind : StepKind
  reasons : Array Reason := #[]
  origin : StepOrigin
  expansion? : Option Block := none
```

The `id` is a unique ID for this step. The `kind` is one of many possible kinds of steps, along with its associated information. These kinds represent individual sentences/steps you would see in a written English proof. The `reasons` are a list of facts that support the validity of this step, such as prior propositions that we know are true, previous definitions or theorems, or a complicated tactic. The `origin` relates the step back to the Lean proof: what tactics and/or hypotheses it corresponds with, and whether it is from a single tactic, part of a tactic, multiple tactics, or inferred from a proof term. The `expansion?` contains an additional proof block that goes into more detail, if necessary.

Similarly to the `detail` information for tactics, there are many kinds of steps, and which ones are used is subject to change during the early development stages of Distill. Here is the initial list of `StepKind`s:
| Kind | Meaning | English example | IR example | Usually comes from |
|---|---|---|---|---|
| `fix` | Introduce arbitrary objects | "Let $x \in A \cap C$." | `fix [x : α  with property f2: x ∈ A ∩ C]` | `intro x` on a `∀` goal |
| `assume` | Assume facts, either to prove an implication or to derive a contradiction | "Suppose $E$ is open." | `assume [f1: IsOpen E] forImplication` | `intro h` on an `→` goal (`forImplication`) or a `¬` goal (`forContradiction`) |
| `derive` | Conclude new facts from known ones (forward reasoning) | "Then $x \in A$ and $x \in C$." | `derive [f3: x ∈ A, f4: x ∈ C]  because fact f2` | `have`, or reading off part of a term such as `hx.1` |
| `obtain` | Get objects and facts out of an existential or a structure | "Then there is an open set $U$ with $U \subseteq E$ and $x \in U$." | `obtain [U] [f5: U ⊆ E, f6: IsOpen U, f7: x ∈ U]  because lemma mem_interior, fact f4` | `obtain`, `rcases`, `cases` |
| `claim` | State an intermediate result and prove it separately | "We claim $x \notin \operatorname{int} E$. *Proof.* …" | `claim f3: x ∉ interior E  proof Block [b1 …, b2 …]` | `have h : P := by …` |
| `suffices` | Replace the goal with one that implies it (backward reasoning) | "It suffices to show $E \subseteq \operatorname{int} E$." | `suffices g2: E ⊆ interior E  because lemma subset_interior_iff_isOpen` | `apply`, `suffices`, `refine` |
| `witness` | Choose a witness for an existential goal | "Take $N$; it remains to show $N \subseteq E$, $N$ is open, and $x \in N$." | `witness [N]  remaining (N ⊆ E ∧ IsOpen N ∧ x ∈ N)` | `use`, `exists`, `refine ⟨N, ?_⟩` |
| `calc` | A chain of equalities or inequalities | "$q^2 = (\sqrt 2)^2 = 2$." | `calc result eR: ↑q ^ 2 = 2  links [↑q ^ 2 = √2 ^ 2 because fact e1, √2 ^ 2 = 2 because lemma Real.sq_sqrt]` | `calc`, or a sequence of `rw` rules |
| `split` | Divide the proof into branches: the two directions of an iff, the parts of an "and", cases, or induction | "(⇒) … (⇐) …" | `split iff [Branch mp …, Branch mpr …]` | `constructor`, `cases`, `rcases … with h \| h`, `induction` |
| `contradiction` | Derive a contradiction from the cited facts | "Then $y \in E$, but also $y \notin E$, a contradiction." | `contradiction  because fact f9, fact f10` | `exact absurd …`, `contradiction`, `omega` on a `False` goal |
| `conclude` | State that the current goal has been reached | "Hence $A \cap C \subseteq B \cap C$." | `conclude f1` | usually added for readability; Lean has no matching step |


## Full Example

Recall that this was our original example:
```lean
theorem intersection_subset {α : Type}
    (A B C : α → Prop)
    (hAB : ∀ x, A x → B x) :
    ∀ x, (A x ∧ C x) → (B x ∧ C x) := by
  intro x hx
  have hBx : B x := hAB x hx.1
  exact ⟨hBx, hx.2⟩
```

The generated Proof IR would look something like:
```text
ProofIR intersection_subset
  statement
    binders     [α A B C hAB]
    conclusion  ∀ x, A x ∧ C x → B x ∧ C x        (still contains the ∀ and → that `intro` consumes)

  nodes (execution order)
    #0 byTactic                structural  27:38–30:19  path #[16]   ?g0 ⟶ —     children [#1 #4 #6]
    #1 intro x hx              surface     28:2–28:12               ?g0 ⟶ ?g2   children [#2 #3]   detail .intro [x, hx]
    #2   intro x               inner       28:2–28:9                ?g0 ⟶ ?g1
    #3   intro hx              inner       28:10–28:12              ?g1 ⟶ ?g2
    #4 have hBx : B x := …     surface     29:2–29:30               ?g2 ⟶ ?g3   children [#5]      detail .have hBx (some (hAB x hx.1)) none
    #5   refine …              inner       synthetic 29:2–29:30     ?g2 ⟶ ?g3   (stands for refine_lift ⇒ focus ⇒ refine)
    #6 exact ⟨hBx, hx.2⟩       surface     30:2–30:19               ?g3 ⟶ —     detail .term .exact ⟨hBx, hx.2⟩

  goals
    ?g0 ⊢ ∀ x, A x ∧ C x → B x ∧ C x   ctx [α A B C hAB]
         assigned by #2   fun x => ?g1
    ?g1 ⊢ A x ∧ C x → B x ∧ C x         parent ?g0   new: x
         assigned by #3   fun hx => ?g2
    ?g2 ⊢ B x ∧ C x                     parent ?g1   new: hx
         assigned by #5   let hBx := hAB x hx.1; ?g3
    ?g3 ⊢ B x ∧ C x                     parent ?g2   new: hBx
         assigned by #6   ⟨hBx, hx.2⟩

  hyps
    α : Type {implicit}     A B C : α → Prop     hAB : ∀ x, A x → B x
    x : α     hx : A x ∧ C x     hBx : B x
```

The generated Presentation IR would then look something like this, assuming that we decide to implement normalizers that convert this proof into one about sets:
```text
Document
  PresentedDecl intersection_subset   role theorem
    objects     α : Type
                A, B, C : Set α          ⟸ α → Prop                       [predicateAsSet, defeq]
    hypotheses  f0  A ⊆ B                ⟸ ∀ x, A x → B x                 [predicateAsSet, defeq]   hyp hAB
    conclusion  f1  A ∩ C ⊆ B ∩ C        ⟸ ∀ x, A x ∧ C x → B x ∧ C x     [predicateAsSet, defeq]
    proof Block (goal f1)
      s1 fix [x : α  with property f2: x ∈ A ∩ C ⟸ A x ∧ C x  hyp hx]
                                                origin direct  nodes [#1]  rule foldAssumptionIntoObject
         expansion
           s6 fix [x : α]                         partOf  [#1]
           s7 assume [f2] forImplication          partOf  [#1]
      s2 derive [f3: x ∈ A ⟸ A x,  f4: x ∈ C ⟸ C x]
           because fact f2                      origin inferred      nodes [#4 #6] hyps [hx]
      s3 derive [f5: x ∈ B ⟸ B x  hyp hBx]
           because fact f0 at [x], fact f3      origin direct        nodes [#4]
      s4 derive [f6: x ∈ B ∩ C ⟸ B x ∧ C x]
           because fact f5, fact f4             origin direct        nodes [#6]
      s5 conclude f1                            origin synthesized
```

An English output from this Presentation IR could then look like:

**Theorem.** Let $A$, $B$, $C$ be sets with $A\subseteq B$. Then $A\cap C\subseteq B\cap C$.

**Proof.** Let $x\in A\cap C$. Then $x\in A$ and $x\in C$. Since $A\subseteq B$, we have $x\in B$.
Consequently $x\in B\cap C$, which proves $A\cap C\subseteq B\cap C$. $\square$


## General framework for informalization

Informalization from Lean to English would be done in the following steps:
1) Get the InfoTree of the Lean proof
2) Use the InfoTree to create a Proof IR of the proof
3) Use the Proof IR to create an initial Presentation IR of the proof
4) During normalization, simplify the Presentation IR while preserving accuracy
5) Use the Presentation IR to create a (possibly interactive) English + LaTeX output.