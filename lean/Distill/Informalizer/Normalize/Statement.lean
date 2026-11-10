import Distill.Informalizer.Normalize.Basic

/-!
# Passes for statements

These arrange the objects and hypotheses of a statement the way a written theorem introduces
them. They only move things: no expression changes. An object can be introduced earlier than
the statement binds it as long as everything its type and properties mention is introduced
before it, which is what `Distill.Informalizer.verify` checks afterwards.
-/

namespace Distill.Informalizer.Normalize

open Lean Meta
open Distill.Informalizer.IR

/-- The objects introduced before each group: `result[i]` are those of groups `0`, …, `i - 1`. -/
private def introducedBefore (groups : Array ObjectGroup) : Array FVarIdSet := Id.run do
  let mut seen : FVarIdSet := {}
  let mut out := #[]
  for g in groups do
    out := out.push seen
    seen := g.objects.foldl (·.insert ·.fvar) seen
  return out

/-- Whether every free variable of `e` other than `self` is in `known`. -/
private def onlyMentions (known : FVarIdSet) (self : FVarId) (e : Expr) : Bool :=
  !e.hasAnyFVar fun f => f != self && !known.contains f

/-- Whether the description of an object of `g` mentions `x`. -/
private def groupMentions (g : ObjectGroup) (x : FVarId) : Bool :=
  g.objects.any fun o =>
    (o.type.expr :: (o.value?.map (·.expr)).toList ++ o.properties.toList.map (·.prop.expr)).any
      (·.containsFVar x)

/--
A hypothesis `x ∈ S` about an object `x` becomes a property of `x`, so that the two are
introduced together: "let `x ∈ S`". Only the first such hypothesis of an object is moved.

`S` has to be introduced before `x`. If it is not, as in `(x : α) (A : Set α) (hx : x ∈ A)`, `x`
is moved to after the objects `S` is made of, unless one of the objects it would move past
mentions it.
-/
def membershipAsProperty : Pass where
  name := `Distill.Normalize.membershipAsProperty
  order := 100
  run d := do
    let mut groups := d.objects
    let mut hypotheses := #[]
    for h in d.hypotheses do
      let prop ← instantiateMVars h.prop.expr
      let moved? : Option (Array ObjectGroup) := do
        let (set, .fvar x) ← membership? prop | none
        let gi ← groups.findIdx? (·.objects.any (·.fvar == x))
        let oi ← groups[gi]!.objects.findIdx? (·.fvar == x)
        let o := groups[gi]!.objects[oi]!
        guard (o.properties.isEmpty && o.value?.isNone && !o.binderInfo.isInstImplicit)
        guard !(set.containsFVar x)
        -- A set defined with a hypothesis can only be named after the hypotheses.
        guard !(set.hasAnyFVar fun f => !groups.any (·.objects.any (·.fvar == f)))
        let o := { o with properties := #[h] }
        -- The last group that `S` needs.
        let last? := (List.range groups.size).reverse.find? fun i =>
          groups[i]!.objects.any fun o' => o'.fvar != x && set.containsFVar o'.fvar
        match last? with
        | some last =>
          if last < gi then
            return groups.modify gi fun g => { g with objects := g.objects.set! oi o }
          guard (((List.range (last + 1)).drop gi).all fun i =>
            !groupMentions { objects := groups[i]!.objects.filter (·.fvar != x) } x)
          let rest := groups[gi]!.objects.eraseIdx! oi
          let before := groups.extract 0 gi ++ (if rest.isEmpty then #[] else #[{ objects := rest }])
          return before ++ groups.extract (gi + 1) (last + 1) ++ #[{ objects := #[o] }] ++
            groups.extract (last + 1) groups.size
        | none => return groups.modify gi fun g => { g with objects := g.objects.set! oi o }
      match moved? with
      | some moved => groups := moved
      | none => hypotheses := hypotheses.push h
    return { d with objects := groups, hypotheses }

/-- What two objects must have in common to be introduced together: their type, and their
properties with the object itself abstracted (`x ∈ A` and `y ∈ A` are the same property). -/
private def groupKey (o : MathObject) : Expr × Array Expr :=
  (o.type.expr, o.properties.map (·.prop.expr.abstract #[.fvar o.fvar]))

/--
Objects that are described the same way are introduced together: `(A : Set α) (x : α)
(B : Set α)` reads "let `A` and `B` be sets and let `x` …". An object joins the first group it
fits in, provided everything its description mentions is introduced before that group.
-/
def groupObjects : Pass where
  name := `Distill.Normalize.groupObjects
  order := 900
  run d := do
    let mut groups : Array ObjectGroup := #[]
    for o in d.objects.flatMap (·.objects) do
      let o := { o with
        type.expr := ← instantiateMVars o.type.expr
        properties := ← o.properties.mapM fun p =>
          return { p with prop.expr := ← instantiateMVars p.prop.expr } }
      let key := groupKey o
      let before := introducedBefore groups
      let fits (i : Nat) : Bool :=
        let first := groups[i]!.objects[0]!
        groupKey first == key && first.value?.isNone && !first.binderInfo.isInstImplicit &&
          onlyMentions before[i]! o.fvar key.1 &&
          o.properties.all fun p => onlyMentions before[i]! o.fvar p.prop.expr
      let simple := o.value?.isNone && !o.binderInfo.isInstImplicit
      match if simple then (List.range groups.size).find? fits else none with
      | some i => groups := groups.modify i fun g => { g with objects := g.objects.push o }
      | none => groups := groups.push { objects := #[o] }
    return { d with objects := groups }

end Distill.Informalizer.Normalize
