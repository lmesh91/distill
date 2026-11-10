import Distill.Definitions.Sets
import Distill.Informalizer.Render.Basic

/-!
# Rendering expressions

`math`, `noun` and `prose` write an expression as a formula, as the name of a type's elements, or
as a clause. Each asks the translators registered for the expression's head constant, then the
built-in ones below, which cover the constructs of the demo levels: sets, `∈`, `⊆`, `∩`, `∪`,
`{x | p x}`, `=`, `∧`, `∨`, `→` and `∀`.

A formula is all or nothing: if one part of an expression has no LaTeX, the whole expression is
shown as Lean code rather than as a mixture.
-/

namespace Distill.Informalizer.Render

open Lean Meta
open Distill.Informalizer.IR (membership?)

/-- `a op b`, with parentheses around an argument that binds less tightly than `lhs` or `rhs`. -/
def infixMath (r : Renderer) (op : String) (prec lhs rhs : Nat) (a b : Expr) :
    RenderM (Option Math) := do
  let some a ← r.math a | return none
  let some b ← r.math b | return none
  return some { tex := s!"{a.at lhs} {op} {b.at rhs}", prec }

/-- A translator for the binary operator `c`, whose operands are its last two arguments. -/
private def binary (c : Name) (arity : Nat) (op : String) (prec lhs rhs : Nat) :
    Name × MathTranslator :=
  (c, fun r e => do
    unless e.isAppOfArity c arity do return none
    infixMath r op prec lhs rhs (e.getArg! (arity - 2)) (e.getArg! (arity - 1)))

/-- `∩` or `∪`. A chain of one operator needs no parentheses, but there is no convention for
which of the two binds tighter, so an operand made with the other one gets them. -/
private def setOperator (c : Name) (op : String) (prec : Nat) : Name × MathTranslator :=
  (c, fun r e => do
    unless e.isAppOfArity c 4 do return none
    let a := e.getArg! 2
    infixMath r op prec (if a.consumeMData.isAppOf c then prec else 71) 71 a (e.getArg! 3))

/-- `x ∈ S`. The set is the argument before the element. -/
private def mathMem : MathTranslator := fun r e => do
  unless e.isAppOfArity ``Membership.mem 5 do return none
  infixMath r "\\in" 50 51 51 (e.getArg! 4) (e.getArg! 3)

/-- `{x | p x}`. -/
private def mathSetOf : MathTranslator := fun r e => do
  unless e.isAppOfArity ``Distill.Set.mk 2 do return none
  let .lam n t b bi := e.appArg!.consumeMData | return none
  withLocalDecl n bi t fun x => do
    let some body ← r.math (b.instantiate1 x) | return none
    return some { tex := s!"\\\{{nameTex n} \\mid {body.tex}\\}" }

/-- The built-in formulas, by head constant. Precedences are those of Lean's notations. -/
def mathTranslators : Std.HashMap Name MathTranslator := .ofList [
  (``Membership.mem, mathMem),
  (``Distill.Set.mk, mathSetOf),
  binary ``HasSubset.Subset 4 "\\subseteq" 50 51 51,
  setOperator ``Inter.inter "\\cap" 70,
  setOperator ``Union.union "\\cup" 65,
  binary ``Eq 3 "=" 50 51 51,
  binary ``And 2 "\\land" 35 36 35,
  binary ``Or 2 "\\lor" 30 31 30
]

/-- "a set of sets", or just "a set" when the elements are those of a type the text does not
introduce. -/
private def nounSet : NounTranslator := fun r t => do
  unless t.isAppOfArity ``Distill.Set 1 do return none
  let set : Noun := { singular := "set", plural := "sets" }
  if let .fvar f := t.appArg!.consumeMData then
    if (← read).omitted.contains f then return some set
  let elem ← r.noun t.appArg!
  return some { set with qualifier := s!" of {elem.plural}{elem.qualifier}" }

/-- The built-in nouns, by head constant of the type. -/
def nounTranslators : Std.HashMap Name NounTranslator := .ofList [
  (``Distill.Set, nounSet)
]

/-- `a ∧ (b ∧ c)` as `#[a, b, c]`, and the same for any other connective `c`. -/
private partial def operands (c : Name) (e : Expr) : Array Expr :=
  let e := e.consumeMData
  if e.isAppOfArity c 2 then #[e.appFn!.appArg!] ++ operands c e.appArg! else #[e]

/-- "P, Q and R" for `∧` and "P, Q or R" for `∨`. Only for operands that are plain formulas:
mixing the two in words would not say which binds tighter. -/
private def connective (c : Name) (word : String) : Name × ProseTranslator :=
  (c, fun r e => do
    let parts := operands c e
    if parts.size < 2 || parts.any (fun p => p.isAppOf ``And || p.isAppOf ``Or || p.isForall) then
      return none
    let parts ← parts.mapM r.prose
    unless parts.all (·.simple) do return none
    let text := match parts.toList.map (·.text) with
      | [a, b] => s!"{a} {word} {b}"
      | texts => s!"{", ".intercalate texts.dropLast} {word} {texts.getLast!}"
    return some { text, disjunction := c == ``Or })

/-- The built-in clauses, by head constant of the proposition. -/
def proseTranslators : Std.HashMap Name ProseTranslator := .ofList [
  connective ``And "and",
  connective ``Or "or"
]

/-- `p₁ → … → pₙ → q` as `(#[p₁, …, pₙ], q)`, for as long as the `pᵢ` are propositions. -/
private partial def premises (e : Expr) (acc : Array Expr := #[]) : MetaM (Array Expr × Expr) := do
  match e.consumeMData with
  | .forallE _ a b _ =>
    if !b.hasLooseBVars && (← isProp a) then premises b (acc.push a) else return (acc, e)
  | _ => return (acc, e)

mutual

/-- `e` as a LaTeX formula, if every part of it has one. -/
partial def math (e : Expr) : RenderM (Option Math) := do
  let e := e.consumeMData
  match e with
  | .fvar f =>
    let some decl := (← getLCtx).find? f | return none
    mention e
    return some { tex := nameTex decl.userName }
  | .forallE n a b bi =>
    if !b.hasLooseBVars && (← isProp a) then
      return ← infixMath (mkRenderer ()) "\\to" 25 26 25 a b
    -- Only propositions: `α → β` is a type of functions.
    if (← isProp a) || !(← isProp e) then return none
    -- `\forall x \in S,\ p` for `∀ x, x ∈ S → p`, and `\forall x,\ p` otherwise.
    withLocalDecl n bi a fun x => do
      let body := b.instantiate1 x
      let name := nameTex n
      if let .forallE _ p q _ := body.consumeMData then
        if let some (set, elem) := membership? p then
          if elem == x && !q.hasLooseBVars && !set.containsFVar x.fvarId! then
            let some s ← math set | return none
            let some q ← math q | return none
            return some { tex := s!"\\forall {name} \\in {s.at 51},\\ {q.tex}", prec := 0 }
      let some body ← math body | return none
      return some { tex := s!"\\forall {name},\\ {body.tex}", prec := 0 }
  | _ =>
    let .const c _ := e.getAppFn | return none
    for t in mathAttribute.getValues (← getEnv) c ++ mathTranslators[c]?.toList do
      try
        if let some m ← t (mkRenderer ()) e then return some m
      catch _ => pure ()
    return none

/-- What the elements of the type `t` are called. Without a translator they are "elements of
$t$", or "terms of type `t`" if `t` has no formula either. -/
partial def noun (t : Expr) : RenderM Noun := do
  let t := t.consumeMData
  if let .sort u := t then
    if u.isZero then return { singular := "proposition", plural := "propositions" }
    if u.dec.isSome then return { singular := "type", plural := "types" }
  if let .const c _ := t.getAppFn then
    for tr in nounAttribute.getValues (← getEnv) c ++ nounTranslators[c]?.toList do
      try
        if let some n ← tr (mkRenderer ()) t then return n
      catch _ => pure ()
  match ← math t with
  | some m =>
    return { article := "an", singular := "element", plural := "elements", qualifier := s!" of ${m.tex}$" }
  | none =>
    mention t
    return { singular := "term", plural := "terms", qualifier := s!" of type {← exprCode t}" }

/-- The proposition `e` as a clause: in words if a translator has them, else as a formula, else
as Lean code. -/
partial def prose (e : Expr) : RenderM Prose := do
  let e := e.consumeMData
  if let .const c _ := e.getAppFn then
    for t in proseAttribute.getValues (← getEnv) c ++ proseTranslators[c]?.toList do
      try
        if let some p ← t (mkRenderer ()) e then return p
      catch _ => pure ()
  if e.isForall then
    if let some p ← proseForall e then return p
  match ← math e with
  | some m => return { text := s!"${m.tex}$" }
  | none =>
    mention e
    return { text := ← exprCode e }

/-- "if P and Q, then R" for an implication, and "for every set $S$, …" for `∀`. -/
private partial def proseForall (e : Expr) : RenderM (Option Prose) := do
  let (ps, conclusion) ← premises e
  if !ps.isEmpty then
    let ps ← ps.mapM prose
    unless Prose.joinable ps.toList do return none
    return some {
      text := s!"if {joinAnd (ps.toList.map (·.text))}, then {(← prose conclusion).text}"
      simple := false }
  let .forallE _ a _ _ := e | return none
  -- `∀ h : p, q h` has no reading as a sentence.
  if ← isProp a then return none
  some <$> quantified a #[] e

/-- The clause for `∀ xs, body`, where `xs` are of type `a`; first takes the variables that
`body` goes on to bind with the same type, so that they are introduced together. -/
private partial def quantified (a : Expr) (xs : Array Expr) (body : Expr) : RenderM Prose := do
  if let .forallE n a' b bi := body.consumeMData then
    if a' == a && (xs.isEmpty || b.hasLooseBVars) then
      return ← withLocalDecl n bi a fun x => quantified a (xs.push x) (b.instantiate1 x)
  let names ← xs.toList.mapM fun x => return s!"${nameTex (← x.fvarId!.getUserName)}$"
  -- `∀ x, x ∈ S → p x` is "for every $x \in S$, …".
  if let (#[x], .forallE _ p q _) := (xs, body.consumeMData) then
    if let some (set, elem) := membership? p then
      if elem == x && !q.hasLooseBVars && !set.containsFVar x.fvarId! then
        if let some m ← math set then
          let name := nameTex (← x.fvarId!.getUserName)
          return { text := s!"for every ${name} \\in {m.at 51}$, {(← prose q).text}", simple := false }
  let n ← noun a
  let subject := match names with
    | [name] => s!"for every {n.singular} {name}{n.qualifier}"
    | _ => s!"for all {n.plural} {joinAnd names}{n.qualifier}"
  return { text := s!"{subject}, {(← prose body).text}", simple := false }

private partial def mkRenderer (_ : Unit) : Renderer := { math, noun, prose }

end

/-- What translators render subexpressions with. -/
def renderer : Renderer := mkRenderer ()

end Distill.Informalizer.Render
