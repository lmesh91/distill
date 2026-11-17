import Lean

/-!
# Which definitions a step relies on

Lean accepts `intro x hx` on a goal `A ⊆ B`, and `hx.left` for `hx : x ∈ A ∩ B`, because it
unfolds `⊆` and `∩` on the way. A reader has to be told: "by the definition of subset". The
functions here run a `MetaM` computation and report which constants Lean unfolded in it, using
the counters of Lean's own diagnostics (`set_option diagnostics true`).
-/

namespace Distill.Informalizer.Present

open Lean Meta

/-- Runs `x`, and returns its result with the constants Lean unfolded while running it, in
alphabetical order. The caches are emptied first, since a cached result unfolds nothing. -/
def unfoldedIn {α : Type} (x : MetaM α) : MetaM (α × Array Name) := do
  let saved ← get
  try
    withTheReader Core.Context ({ · with diag := true }) do
      modify fun s => { s with cache := {}, diag := {} }
      let a ← x
      let names := (← get).diag.unfoldCounter.toList.map (·.1)
      return (a, (names.toArray.qsort (·.toString < ·.toString)))
  finally
    modify fun s => { s with cache := saved.cache, diag := saved.diag }

/-- Whether `n` is a definition a reader knows by name: not an instance, not the projection of a
class (`Membership.mem`, which only says which instance's `∈` is meant), and not something Lean
generated (matchers, recursors, auxiliary definitions). -/
def isNamedDefinition (n : Name) : MetaM Bool := do
  let env ← getEnv
  if n.isInternal || n.hasMacroScopes then return false
  if ← isInstance n then return false
  if (env.getProjectionFnInfo? n).any (·.fromClass) then return false
  if isMatcherCore env n || isAuxRecursor env n || isNoConfusion env n then return false
  if ← isMatcher n then return false
  match env.find? n with
  | some (.defnInfo _) | some (.thmInfo _) | some (.opaqueInfo _) => return true
  | _ => return false

/-- The definitions (`isNamedDefinition`) among `names`. -/
def namedDefinitions (names : Array Name) : MetaM (Array Name) :=
  names.filterM isNamedDefinition

/-- `e` with metavariables instantiated and without annotations or a beta-redex at its head. -/
def tidy (e : Expr) : MetaM Expr :=
  return (← instantiateMVars e).consumeMData.headBeta

/-- How the propositions `a` and `b` are the same: `some #[]` if they are the same term or
become it without unfolding a definition, `some defs` if Lean has to unfold the definitions
`defs` to see it, and `none` if they are not definitionally equal. -/
def sameUpToDefinitions (a b : Expr) : MetaM (Option (Array Name)) := do
  let a ← tidy a
  let b ← tidy b
  if a == b then return some #[]
  let (ok, names) ← unfoldedIn (withNewMCtxDepth (isDefEq a b))
  if ok then return some (← namedDefinitions names) else return none

/-- `e` in weak head normal form, with the definitions unfolded to get there. -/
def whnfWithDefinitions (e : Expr) : MetaM (Expr × Array Name) := do
  let (e', names) ← unfoldedIn (whnf e)
  return (e', ← namedDefinitions names)

end Distill.Informalizer.Present
