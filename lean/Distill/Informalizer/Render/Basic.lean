import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation
import Distill.Informalizer.Text

/-!
# Rendering expressions: the pieces

English is a `Text`, in which formulas and Lean code are kept apart from the words. An
expression can be written as more than one *kind of phrase*, and a *translator* says how to write
the expressions headed by one constant as one kind. The built-in renderer asks for three kinds:

* **math** (`Math`): a LaTeX formula, `A \cap B`;
* a **noun** (`Noun`), for a type: what its elements are called, "a set";
* **prose** (`Prose`), for a proposition: a clause of a sentence, "if $x \in A$, then
  $x \in B$".

A library registers translators for its own definitions with `@[distill_translator c]`, like a
recognizer with `@[distill_recognizer]`. The built-in ones are in
`Distill.Informalizer.Render.Expr`. An expression nothing translates is shown as Lean code.

The kinds are open: a kind is a type with a `TypeName`, so what English needs beyond these three
(adjectives, verbs, …) is added as new types and translators, without changing the ones here.
-/

namespace Distill.Informalizer

open Lean Meta

/-! ## Text -/

/-- `e` as Lean code on one line. -/
def exprCode (e : Expr) : MetaM Text := do
  let s := (← ppExpr e).pretty (width := 10000)
  return .code (" ".intercalate ((s.splitOn "\n").map (·.trimAscii.toString)))

private def greek : List (Char × String) := [
  ('α', "alpha"), ('β', "beta"), ('γ', "gamma"), ('δ', "delta"), ('ε', "varepsilon"),
  ('ζ', "zeta"), ('η', "eta"), ('θ', "theta"), ('ι', "iota"), ('κ', "kappa"), ('μ', "mu"),
  ('ν', "nu"), ('ξ', "xi"), ('π', "pi"), ('ρ', "rho"), ('σ', "sigma"), ('τ', "tau"),
  ('υ', "upsilon"), ('φ', "varphi"), ('χ', "chi"), ('ψ', "psi"), ('ω', "omega"),
  ('Γ', "Gamma"), ('Δ', "Delta"), ('Θ', "Theta"), ('Λ', "Lambda"), ('Ξ', "Xi"),
  ('Π', "Pi"), ('Σ', "Sigma"), ('Φ', "Phi"), ('Ψ', "Psi"), ('Ω', "Omega")]

private def subscriptDigit? (c : Char) : Option Char :=
  if c.isDigit then some c
  else if '₀' ≤ c && c ≤ '₉' then some (Char.ofNat (c.toNat - '₀'.toNat + '0'.toNat))
  else none

/-- A variable name as LaTeX: `α` is `\alpha`, `h₁` and `h1` are `h_{1}`, `x'` is `x'`, and a
name of several letters is set as one word, `\mathit{hAB}`. -/
def nameTex (n : Name) : String :=
  let s := (toString n.eraseMacroScopes).toList.filter (!"✝«»".contains ·)
  let primes := (s.reverse.takeWhile (· == '\'')).length
  let s := s.take (s.length - primes)
  let digits := (s.reverse.takeWhile (subscriptDigit? · |>.isSome)).reverse
  let base := s.take (s.length - digits.length)
  -- A name that is only digits has no base to put them under.
  let (base, digits) := if base.isEmpty then (s, []) else (base, digits)
  let letter (c : Char) : String :=
    match greek.lookup c with
    | some g => s!"\\{g} "
    | none =>
      if "_#%&{}$".contains c then s!"\\{c}"
      else if c == ' ' then "\\ "
      else if "^~\\".contains c then "" else c.toString
  let baseTex := match base with
    | [c] => (letter c).trimAscii.toString
    | cs => s!"\\mathit\{{(String.join (cs.map letter)).trimAscii}}"
  let sub := if digits.isEmpty then "" else
    s!"_\{{String.ofList (digits.filterMap subscriptDigit?)}}"
  s!"{baseTex}{sub}{"".pushn '\'' primes}"

/-! ## Math, nouns and prose -/

/-- A LaTeX formula, without delimiters. -/
structure Math where
  tex : String
  /-- The binding strength of the outermost operator, on the scale of Lean's notations: `50`
  for `=` and `∈`, `1024` for something that never needs parentheses. -/
  prec : Nat := 1024
  deriving Inhabited, Repr, TypeName

/-- The formula as an argument of an operator that needs strength `prec` there. -/
def Math.at (m : Math) (prec : Nat) : String :=
  if m.prec < prec then s!"({m.tex})" else m.tex

/-- The formula as part of a sentence. -/
def Math.text (m : Math) : Text := .math m.tex

/-- What the elements of a type are called: "let $A$ be `article` `singular``qualifier`", "let
$A$ and $B$ be `plural``qualifier`", "for every `singular` $A$`qualifier`". -/
structure Noun where
  /-- "a" or "an". -/
  article : String := "a"
  singular : String
  plural : String
  /-- What follows the noun, starting with a space if not empty: " of elements of $\alpha$". -/
  qualifier : Text := .empty
  deriving Inhabited, Repr, TypeName

/-- A proposition as part of a sentence. It does not start with a capital or end with a period. -/
structure Prose where
  text : Text
  /-- Whether the text can be joined to others with "and", or put after "if", without becoming
  hard to read. A formula is; a clause with "if" or "for every" in it is not. -/
  simple : Bool := true
  /-- Whether the text is an "or" of clauses. It is then not joined to others with "and", which
  would not say how the two group. -/
  disjunction : Bool := false
  deriving Inhabited, Repr, TypeName

/-- Whether the clauses can be listed with "and": "P, Q and R". -/
def Prose.joinable (ps : List Prose) : Bool :=
  ps.all (·.simple) && (ps.length ≤ 1 || ps.all (!·.disjunction))

/-! ## The monad -/

structure RenderContext where
  /-- Objects of the statement that the text does not introduce. A translator leaves out
  anything optional that would mention one: a set is "a set", not "a set of elements of
  $\alpha$", when `α` is implicit. -/
  omitted : FVarIdSet := {}

structure RenderState where
  /-- The local variables the text written so far names. -/
  mentioned : FVarIdSet := {}

abbrev RenderM := ReaderT RenderContext (StateRefT RenderState MetaM)

/-- Records that the text names the free variables of `e`. `Renderer.math` and the fallbacks do
this themselves; a translator that writes a variable's name on its own has to call it, or an
implicit object it names is not introduced. -/
def mention (e : Expr) : RenderM Unit :=
  modify fun s => { s with mentioned := (collectFVars {} e).fvarIds.foldl (·.insert ·) s.mentioned }

/-! ## Translators -/

/-- How to render subexpressions; every translator is handed one. -/
structure Renderer where
  /-- `none` if some part of the expression has no formula. -/
  math : Expr → RenderM (Option Math)
  noun : Expr → RenderM Noun
  prose : Expr → RenderM Prose
  /-- The expression as a phrase of the kind with this `TypeName`; see `Renderer.phrase?`. -/
  translate? : Name → Expr → RenderM (Option Dynamic)
  deriving Inhabited

/-- `e` as a phrase of kind `α`, if a translator of that kind handles it. This is how phrases of
a kind that the renderer has no field for are asked for. -/
def Renderer.phrase? (r : Renderer) (α : Type) [TypeName α] (e : Expr) : RenderM (Option α) :=
  return (← r.translate? (TypeName.typeName α) e).bind (·.get? α)

/--
How to write the expressions headed by one constant as one kind of phrase.
`@[distill_translator c] def t : Translator := .math fun r e => …` registers it for the constant
`c`.

The kinds are not a fixed list. `Math`, `Noun` and `Prose` are the ones the built-in renderer
asks for; any other type with a `TypeName` is a kind too (an adjective, a verb phrase, a name for
a theorem, …): translators for it are made with `Translator.of`, and whoever wants such a phrase
asks for it with `Renderer.phrase?`.
-/
structure Translator where
  /-- The `TypeName` of the kind of phrase. -/
  kind : Name
  /-- `none` for an expression the translator does not handle; the next one for the same
  constant and kind is tried then. -/
  run : Renderer → Expr → RenderM (Option Dynamic)
  deriving Inhabited

abbrev MathTranslator := Renderer → Expr → RenderM (Option Math)
abbrev NounTranslator := Renderer → Expr → RenderM (Option Noun)
abbrev ProseTranslator := Renderer → Expr → RenderM (Option Prose)

namespace Translator

def of {α : Type} [TypeName α] (f : Renderer → Expr → RenderM (Option α)) : Translator where
  kind := TypeName.typeName α
  run r e := return (← f r e).map Dynamic.mk

/-- Writes applications of a constant as LaTeX. -/
def math (f : MathTranslator) : Translator := .of f

/-- Names the elements of a type. -/
def noun (f : NounTranslator) : Translator := .of f

/-- Writes a proposition in words. -/
def prose (f : ProseTranslator) : Translator := .of f

end Translator

private def constKey (_ : Bool) (stx : Syntax) : AttrM Name := do
  let id ← Attribute.Builtin.getIdent stx
  Elab.realizeGlobalConstNoOverloadWithInfo id

/-- `@[distill_translator c] def t : Translator := …` has Distill write the expressions headed by
the constant `c` with `t`. -/
unsafe initialize translatorAttribute : KeyedDeclsAttribute Translator ←
  KeyedDeclsAttribute.init {
    builtinName := `builtin_distill_translator
    name := `distill_translator
    descr := "how Distill writes the expressions headed by a constant"
    valueTypeName := ``Translator
    evalKey := constKey }

end Distill.Informalizer
