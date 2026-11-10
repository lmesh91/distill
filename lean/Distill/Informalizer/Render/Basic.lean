import Distill.Informalizer.IR.Context
import Distill.Informalizer.IR.Presentation

/-!
# Rendering expressions: the pieces

English is rich text: `$…$` is LaTeX and `` `…` `` is Lean code. An expression can be written
three ways, and a *translator* says how for the expressions headed by one constant:

* as **math** (`Math`): a LaTeX formula, `A \cap B`;
* as a **noun** (`Noun`), for a type: what its elements are called, "a set";
* as **prose** (`Prose`), for a proposition: a clause of a sentence, "if $x \in A$, then
  $x \in B$".

A library registers translators for its own definitions with `@[distill_math c]`,
`@[distill_noun c]` and `@[distill_prose c]`, like a recognizer with `@[distill_recognizer]`.
The built-in ones are in `Distill.Informalizer.Render.Expr`. An expression nothing translates is
shown as Lean code.
-/

namespace Distill.Informalizer

open Lean Meta

/-! ## Text -/

/-- `s` as inline code. The fence is longer than any run of backticks in `s`, as in Markdown. -/
def code (s : String) : String :=
  let (longest, _) := s.foldl (init := (0, 0)) fun (longest, run) c =>
    if c == '`' then (max longest (run + 1), run + 1) else (longest, 0)
  let fence := "".pushn '`' (longest + 1)
  let pad := if s.startsWith "`" || s.endsWith "`" then " " else ""
  s!"{fence}{pad}{s}{pad}{fence}"

/-- "a", "a and b", "a, b and c". -/
def joinAnd : List String → String
  | [] => ""
  | [a] => a
  | [a, b] => s!"{a} and {b}"
  | a :: rest => s!"{a}, {joinAnd rest}"

/-- `e` as Lean code on one line. -/
def exprCode (e : Expr) : MetaM String := do
  let s := (← ppExpr e).pretty (width := 10000)
  return code (" ".intercalate ((s.splitOn "\n").map (·.trimAscii.toString)))

/-- `s` with its first letter in upper case. Text that starts with math or code is unchanged. -/
def capitalize (s : String) : String :=
  match s.toList with
  | c :: rest => String.ofList (c.toUpper :: rest)
  | [] => s

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
name of several letters is set upright in italics, `\mathit{hAB}`. -/
def nameTex (n : Name) : String :=
  let s := (toString n.eraseMacroScopes).toList.filter (· != '✝')
  let primes := (s.reverse.takeWhile (· == '\'')).length
  let s := s.take (s.length - primes)
  let digits := (s.reverse.takeWhile (subscriptDigit? · |>.isSome)).reverse
  let base := s.take (s.length - digits.length)
  -- A name that is only digits has no base to put them under.
  let (base, digits) := if base.isEmpty then (s, []) else (base, digits)
  let letter (c : Char) : String :=
    match greek.lookup c with
    | some g => s!"\\{g} "
    | none => if c == '_' then "\\_" else c.toString
  let baseTex := match base with
    | [c] => (letter c).trimAscii.toString
    | cs => s!"\\mathit\{{(String.join (cs.map letter)).trimAscii}}"
  let sub := if digits.isEmpty then "" else
    s!"_\{{String.ofList (digits.filterMap subscriptDigit?)}}"
  s!"{baseTex}{sub}{"".pushn '\'' primes}"

/-! ## Math, nouns and prose -/

/-- A LaTeX formula, without the `$`. -/
structure Math where
  tex : String
  /-- The binding strength of the outermost operator, on the scale of Lean's notations: `50`
  for `=` and `∈`, `1024` for something that never needs parentheses. -/
  prec : Nat := 1024
  deriving Inhabited, Repr

/-- The formula as an argument of an operator that needs strength `prec` there. -/
def Math.at (m : Math) (prec : Nat) : String :=
  if m.prec < prec then s!"({m.tex})" else m.tex

/-- What the elements of a type are called: "let $A$ be `article` `singular``qualifier`", "let
$A$ and $B$ be `plural``qualifier`", "for every `singular` $A$`qualifier`". -/
structure Noun where
  /-- "a" or "an". -/
  article : String := "a"
  singular : String
  plural : String
  /-- What follows the noun, starting with a space if not empty: " of elements of $\alpha$". -/
  qualifier : String := ""
  deriving Inhabited, Repr

/-- A proposition as part of a sentence. It does not start with a capital or end with a period. -/
structure Prose where
  text : String
  /-- Whether the text can be joined to others with "and", or put after "if", without becoming
  hard to read. A formula is; a clause with "if" or "for every" in it is not. -/
  simple : Bool := true
  deriving Inhabited, Repr

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

/-- Records that the text names the free variables of `e`. -/
def mention (e : Expr) : RenderM Unit :=
  modify fun s => { s with mentioned := (collectFVars {} e).fvarIds.foldl (·.insert ·) s.mentioned }

/-! ## Translators -/

/-- How to render subexpressions; every translator is handed one. -/
structure Renderer where
  /-- `none` if some part of the expression has no formula. -/
  math : Expr → RenderM (Option Math)
  noun : Expr → RenderM Noun
  prose : Expr → RenderM Prose
  deriving Inhabited

/-- A translator returns `none` for an expression it does not handle, and the next one for the
same constant is tried. -/
abbrev MathTranslator := Renderer → Expr → RenderM (Option Math)
abbrev NounTranslator := Renderer → Expr → RenderM (Option Noun)
abbrev ProseTranslator := Renderer → Expr → RenderM (Option Prose)

private def constKey (_ : Bool) (stx : Syntax) : AttrM Name := do
  let id ← Attribute.Builtin.getIdent stx
  Elab.realizeGlobalConstNoOverloadWithInfo id

/-- `@[distill_math c] def t : MathTranslator := …` writes applications of the constant `c` as
LaTeX. -/
unsafe initialize mathAttribute : KeyedDeclsAttribute MathTranslator ←
  KeyedDeclsAttribute.init {
    builtinName := `builtin_distill_math
    name := `distill_math
    descr := "how Distill writes applications of a constant as LaTeX"
    valueTypeName := ``MathTranslator
    evalKey := constKey }

/-- `@[distill_noun c] def t : NounTranslator := …` names the elements of the types `c …`. -/
unsafe initialize nounAttribute : KeyedDeclsAttribute NounTranslator ←
  KeyedDeclsAttribute.init {
    builtinName := `builtin_distill_noun
    name := `distill_noun
    descr := "what Distill calls the elements of a type"
    valueTypeName := ``NounTranslator
    evalKey := constKey }

/-- `@[distill_prose c] def t : ProseTranslator := …` writes the propositions `c …` in words. -/
unsafe initialize proseAttribute : KeyedDeclsAttribute ProseTranslator ←
  KeyedDeclsAttribute.init {
    builtinName := `builtin_distill_prose
    name := `distill_prose
    descr := "how Distill writes a proposition in words"
    valueTypeName := ``ProseTranslator
    evalKey := constKey }

end Distill.Informalizer
