import Distill.Informalizer.Render.Basic
import Distill.Informalizer.Render.Expr

/-!
# Rendering: Presentation IR ⟶ English

`render` writes a `PresentedDecl` as English: one sentence or two for the statement, and one
piece of text per proof step. The text is a `Text`, which keeps formulas and Lean code apart from
the words, so that the web app, or anything else that shows it, can lay them out its own way.

Rendering decides wording only. What is said, and in which order, is the Presentation IR's
business: the statement introduces the object groups in order, each with its properties, then
states the hypotheses and the conclusion. How an expression is written is up to the translators
of `Distill.Informalizer.Render.Expr`.

Whatever has no English yet is shown as the Lean it came from, so no part of a proof is ever
left out.
-/

namespace Distill.Informalizer

open Lean Meta
open Distill.Informalizer.IR

/-- The English of one proof step. -/
structure RenderedStep where
  /-- The step's id. -/
  step : Nat
  /-- The Proof IR nodes the step came from (`StepOrigin.nodes`), which locate it in the
  source. -/
  nodes : Array Nat
  text : Text
  deriving Inhabited, Repr

/-- The English of one declaration. -/
structure Rendered where
  /-- `none` if there is no theorem to state: the proof is a `by` block inside a declaration, or
  what it builds is not a proof of a proposition (`def n : Nat := by exact 1`). -/
  statement? : Option Text
  /-- In presentation order. Read one after the other they are the proof as continuous prose. -/
  steps : Array RenderedStep
  deriving Inhabited, Repr

/-- The proof as one paragraph: its steps in presentation order. -/
def Rendered.proofText (r : Rendered) : Text :=
  Text.intercalate " " (r.steps.toList.map (·.text))

def roleLabel : DeclRole → String
  | .theorem => "Theorem"
  | .lemma => "Lemma"
  | .example => "Example"

/-! ## Statements -/

/-- How the properties of one object are said where it is introduced. -/
private structure Described where
  adjectives : Array Adjective := #[]
  accessories : Array Accessory := #[]
  /-- The properties that are neither, after "such that". -/
  clauses : Array Text := #[]
  deriving Inhabited

/-- Sorts the properties of `o` into adjectives, accessories and clauses; all into clauses if
not `words`. -/
private def describe (o : MathObject) (words : Bool) : RenderM Described :=
  withReader ({ · with subject? := some o.fvar }) do
    let mut d : Described := {}
    for p in o.properties do
      let prop ← instantiateMVars p.prop.expr
      -- A property that does not mention the object is not a word for it, whatever a translator
      -- says.
      if words && prop.containsFVar o.fvar then
        if let some a ← Render.renderer.phrase? Adjective prop then
          unless d.adjectives.contains a do
            d := { d with adjectives := d.adjectives.push a }
          continue
        if let some a ← Render.renderer.phrase? Accessory prop then
          unless d.accessories.contains a do
            d := { d with accessories := d.accessories.push a }
          continue
      d := { d with clauses := d.clauses.push (← Render.prose prop).text }
    return d

/-- The clause that introduces the objects of a group: "let $A$ and $B$ be sets", "let
$x \in A$", and in general "let `names` be `article` `adjectives` `noun` with `accessories` such
that `clauses`". `none` if the text introduces none of them. -/
private def groupClause (g : ObjectGroup) : RenderM (Option Text) := do
  let omitted := (← read).omitted
  let objects := g.objects.filter (!omitted.contains ·.fvar)
  let some first := objects[0]? | return none
  let type ← instantiateMVars first.type.expr
  if first.binderInfo.isInstImplicit then
    mention type
    return some ("fix an instance of " ++ (← exprCode type))
  let name (o : MathObject) := nameTex o.name
  -- An element of a type the text does not introduce: there is nothing to call it.
  if let .fvar t := type.consumeMData then
    if (← read).plainElements && omitted.contains t && first.properties.isEmpty &&
        first.value?.isNone then
      let names := objects.toList.map fun o => Text.math (name o)
      return some ("let " ++ Text.joinAnd names ++ " be arbitrary")
  if let some value := first.value? then
    let value ← instantiateMVars value.expr
    match ← Render.math value with
    | some m => return some ("let " ++ Text.math s!"{name first} = {m.tex}")
    | none =>
      mention value
      return some ("let " ++ Text.math (name first) ++ " be " ++ (← exprCode value))
  -- "let $x, y \in A$": the set says what the objects are, so their type is left out.
  if let #[property] := first.properties then
    if let some (set, .fvar x) := membership? (← instantiateMVars property.prop.expr) then
      if x == first.fvar && !set.containsFVar x then
        if let some m ← Render.math set then
          return some <|
            "let " ++ Text.math s!"{", ".intercalate (objects.toList.map name)} \\in {m.at 51}"
  let noun ← Render.noun type
  let names := objects.toList.map fun o => Text.math (name o)
  -- One noun phrase describes the whole group, so its words have to fit every object in it.
  let mut described ← objects.mapM (describe · (words := true))
  let shared := described[0]!
  unless described.all fun d =>
      d.adjectives == shared.adjectives && d.accessories == shared.accessories do
    described ← objects.mapM (describe · (words := false))
  let { adjectives, accessories, .. } := described[0]!
  let article := (adjectives[0]?.map (·.article)).getD noun.article
  let adjectives := String.join (adjectives.toList.map (s!"{·.text} "))
  let mut clause := match names with
    | [n] => "let " ++ n ++ s!" be {article} {adjectives}{noun.singular}" ++ noun.qualifier
    | _ => "let " ++ Text.joinAnd names ++ s!" be {adjectives}{noun.plural}" ++ noun.qualifier
  unless accessories.isEmpty do
    clause := clause ++ " with " ++ Text.joinAnd (accessories.toList.map (·.text))
  let clauses := described.flatMap (·.clauses)
  unless clauses.isEmpty do
    clause := clause ++ " such that " ++ Text.joinAnd clauses.toList
  return some clause

/-- "a", "a and b", "a, b, and c", for clauses that may contain "and" themselves. -/
private def joinClauses : List Text → Text
  | [a] => a
  | [a, b] => a ++ " and " ++ b
  | clauses => match clauses.getLast? with
    | some last => Text.intercalate ", " (clauses.dropLast ++ ["and " ++ last])
    | none => .empty

/-- The statement with its label, given which objects not to introduce. -/
private def statementText (d : PresentedDecl) : RenderM Text := do
  let clauses ← d.objects.toList.filterMapM groupClause
  let hypotheses ← d.hypotheses.toList.mapM fun h => do
    Render.prose (← instantiateMVars h.prop.expr)
  let conclusion ← Render.prose (← instantiateMVars d.conclusion.prop.expr)
  -- "Then if …" would stack two connectives.
  let conditional := conclusion.text.startsWith "if "
  let sentence (t : Text) : Text := t.capitalize ++ "."
  let mut sentences : List Text := [s!"{roleLabel d.role}."]
  unless clauses.isEmpty do
    sentences := sentences ++ [sentence (joinClauses clauses)]
  if hypotheses.isEmpty then
    let then_ := if clauses.isEmpty || conditional then "" else "then "
    sentences := sentences ++ [sentence (then_ ++ conclusion.text)]
  else if conclusion.simple && Prose.joinable hypotheses then
    sentences := sentences ++ [sentence <|
      "if " ++ Text.joinAnd (hypotheses.map (·.text)) ++ ", then " ++ conclusion.text]
  else
    sentences := sentences ++ [
      sentence ("suppose " ++ Text.joinAnd (hypotheses.map ("that " ++ ·.text))),
      sentence ((if conditional then "" else "then ") ++ conclusion.text)]
  return Text.intercalate " " sentences

/--
The statement: "Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$,
then $C \subseteq A \cap B$."

An implicit object (`{α : Type}`) is introduced only if the rest of the text names it, or if it
has properties, which are stated where it is introduced. Which
objects that leaves out is not known before the text is written, so the text is written again
until none of the objects it leaves out is named.
-/
def renderStatement (d : PresentedDecl) : MetaM Text := do
  let implicit := d.objects.flatMap fun g => g.objects.filterMap fun o =>
    if (o.binderInfo == .implicit || o.binderInfo == .strictImplicit) && o.properties.isEmpty
    then some o.fvar else none
  let mut omitted : FVarIdSet := implicit.foldl (·.insert ·) {}
  -- Every round but the last introduces an object more.
  for _ in [0:implicit.size] do
    let (text, state) ← (statementText d).run { omitted } |>.run {}
    let named := omitted.toList.filter state.mentioned.contains
    if named.isEmpty then return text
    omitted := named.foldl (·.erase ·) omitted
  (statementText d).run { omitted } |>.run' {}

/-! ## Goal states -/

/-- The objects and hypotheses of a local context, grouped the way a statement's are: objects
of the same type with nothing said about them share a group, and a hypothesis right after an
object saying which set it is in (`x : α`, `hx : x ∈ A`) is a property of that object. -/
private def contextObjects (hyps : Array LocalDecl) :
    MetaM (Array ObjectGroup × Array Claim) := do
  let mut groups : Array ObjectGroup := #[]
  let mut hypotheses : Array Claim := #[]
  let mut lastObject? : Option FVarId := none
  for (d, i) in hyps.zipIdx do
    if ← isProp d.type then
      let claim : Claim := { id := i, prop := { expr := d.type }, hyp? := some d.fvarId }
      -- "let $x \in A$": a membership right after the object it is about.
      if let some x := lastObject? then
        if (membership? d.type).any fun (set, e) => e == .fvar x && !set.containsFVar x then
          lastObject? := none
          groups := groups.modify (groups.size - 1) fun g =>
            { g with objects := g.objects.modify (g.objects.size - 1) fun o =>
                { o with properties := o.properties.push claim } }
          continue
      hypotheses := hypotheses.push claim
      lastObject? := none
    else
      let o : MathObject := {
        fvar := d.fvarId, name := d.userName, type := { expr := d.type }
        value? := d.value?.map ({ expr := · }), binderInfo := d.binderInfo }
      lastObject? := some d.fvarId
      -- "Let $A$ and $B$ be sets": the previous object had the same type and nothing said.
      if let some g := groups.back? then
        if let some prev := g.objects.back? then
          if prev.type.expr == d.type && prev.properties.isEmpty && prev.value?.isNone &&
              d.value?.isNone && prev.binderInfo == d.binderInfo then
            groups := groups.modify (groups.size - 1) fun g => { g with objects := g.objects.push o }
            continue
      groups := groups.push { objects := #[o] }
  return (groups, hypotheses)

/-- The goal state as text, given which objects not to introduce. -/
private def goalStateText (groups : Array ObjectGroup) (hypotheses : Array Claim)
    (target : Expr) : RenderM Text := do
  let clauses ← groups.toList.filterMapM groupClause
  let hypotheses ← hypotheses.toList.mapM fun h => do Render.prose (← instantiateMVars h.prop.expr)
  let target ← Render.prose (← instantiateMVars target)
  let sentence (t : Text) : Text := t.capitalize ++ "."
  let mut sentences : List Text := []
  unless clauses.isEmpty do sentences := sentences ++ [sentence (joinClauses clauses)]
  unless hypotheses.isEmpty do
    sentences := sentences ++
      [sentence ("suppose " ++ Text.joinAnd (hypotheses.map ("that " ++ ·.text)))]
  sentences := sentences ++ [sentence ("we need to show that " ++ target.text)]
  return Text.intercalate " " sentences

/--
A goal state in English (#91): its objects, its hypotheses and its target. "Let $A$ and $B$ be
sets and let $x \in A \cap B$. We need to show that $x \in A$." Objects of an implicit type
(`α`) are introduced only if something names them, as in statements. Runs inside
`ir.withContext`.
-/
def renderGoalState (ir : ProofIR) (g : MVarId) : MetaM Text := ir.withGoalContext g do
  let some gi := ir.goal? g | return "A goal of the Lean proof."
  let lctx ← getLCtx
  let decls := gi.context.filterMap fun h =>
    (lctx.find? h).filter fun d => !d.isAuxDecl && !d.binderInfo.isInstImplicit
  let (groups, hypotheses) ← contextObjects decls
  let implicit := groups.flatMap fun g => g.objects.filterMap fun o =>
    if (o.binderInfo == .implicit || o.binderInfo == .strictImplicit) && o.properties.isEmpty
    then some o.fvar else none
  let text := goalStateText groups hypotheses gi.target
  let mut omitted : FVarIdSet := implicit.foldl (·.insert ·) {}
  for _ in [0:implicit.size] do
    let (out, state) ← text.run { omitted, plainElements := true } |>.run {}
    let named := omitted.toList.filter state.mentioned.contains
    if named.isEmpty then return out
    omitted := named.foldl (·.erase ·) omitted
  text.run { omitted, plainElements := true } |>.run' {}

/-! ## Proof steps -/

private def firstLine (ir : ProofIR) (n : Nat) : Option Text :=
  (ir.node? n).map (Text.code <| syntaxFirstLine ·.stx)

/-- The Lean a step came from, for a presentation that does not verify. -/
def renderUntranslated (ir : ProofIR) (nodes : Array Nat) : Text :=
  let sources := nodes.toList.filterMap (firstLine ir)
  if sources.isEmpty then "A step of the Lean proof that is not translated into English yet."
  else "The Lean proof continues with " ++ Text.joinAnd sources ++ "."

/-- What steps are written with, besides the step. -/
private structure ProofContext where
  ir : ProofIR
  /-- Every fact of the presentation, by id. -/
  claims : Std.HashMap Nat Claim

private partial def blockClaims (b : Block) (m : Std.HashMap Nat Claim) : Std.HashMap Nat Claim :=
  let add (m : Std.HashMap Nat Claim) (c : Claim) := m.insert c.id c
  let m := b.goal?.elim m (add m)
  b.steps.foldl (init := m) fun m s =>
    match s.kind with
    | .fix os => os.foldl (fun m o => o.properties.foldl add m) m
    | .assume cs _ | .derive cs => cs.foldl add m
    | .obtain os cs => cs.foldl add (os.foldl (fun m o => o.properties.foldl add m) m)
    | .claim c proof => blockClaims proof (add m c)
    | .suffices c | .conclude c | .gap c _ | .witness _ c => add m c
    | .split _ bs => bs.foldl (init := m) fun m b => blockClaims b.body (b.assumptions.foldl add m)
    | _ => m

private def declClaims (d : PresentedDecl) : Std.HashMap Nat Claim :=
  let m : Std.HashMap Nat Claim := d.hypotheses.foldl (fun m c => m.insert c.id c) {}
  let m := d.objects.foldl (init := m) fun m g => g.objects.foldl (init := m) fun m o =>
    o.properties.foldl (fun m c => m.insert c.id c) m
  blockClaims d.proof (m.insert d.conclusion.id d.conclusion)

/-- The facts a step establishes, which the next step can refer to with "hence". -/
private def established : StepKind → Array Nat
  | .fix os => os.flatMap (·.properties.map (·.id))
  | .assume cs _ | .derive cs => cs.map (·.id)
  | .obtain os cs => os.flatMap (·.properties.map (·.id)) ++ cs.map (·.id)
  | .claim c _ => #[c.id]
  | _ => #[]

/-- "P and Q", or "that P and that Q" when a clause is a sentence of its own. -/
private def statements (ps : List Prose) : Text :=
  if ps.all (·.simple) then Text.joinAnd (ps.map (·.text))
  else Text.joinAnd (ps.map ("that " ++ ·.text))

/-- The proposition `e` as something to list with others after "since": a clause if it is a
simple one, and otherwise a formula if it has one ("since $x \in C \to x \in A$ and
$x \in C$"). -/
private def listed (e : Expr) : RenderM Prose := do
  let p ← Render.prose e
  if p.simple then return p
  match ← Render.math e with
  | some m => return { text := m.text }
  | none => return p

/-- The theorem `decl` as a proof cites it: what its `Citation` says, or else its statement,
"the earlier theorem that for all sets $A$ and $B$, $A \cap B \subseteq A$", followed by what it is
applied to (`args`: its arguments that are not proofs) when those are not its own variables.
`none` for a rule that is not named. -/
def citation (decl : Name) (args : Array Expr) : RenderM (Option Text) := do
  if let some c ← Render.renderer.phrase? Citation (mkConst decl) then
    return if c.text.isEmpty then none else some c.text
  let info ← getConstInfo decl
  forallTelescope info.type fun xs conclusion => do
    let mut objects : Array Expr := #[]
    let mut hypotheses : Array Expr := #[]
    let mut omitted := (← read).omitted
    for x in xs do
      let decl ← x.fvarId!.getDecl
      if ← isProp decl.type then hypotheses := hypotheses.push decl.type
      else if (← isClass? decl.type).isSome then pure ()
      else
        objects := objects.push x
        -- `{α : Type}` is not something a written statement quantifies over.
        if decl.type.isSort && !decl.type.isProp && !decl.binderInfo.isExplicit then
          omitted := omitted.insert x.fvarId!
    withReader ({ · with omitted }) do
      let shown := objects.filter (!omitted.contains ·.fvarId!)
      -- "for all sets $A$ and $B$ and every element $x$ of …"
      let mut groups : Array (Expr × Array Expr) := #[]
      for x in shown do
        let type ← inferType x
        match groups.back? with
        | some (t, ys) =>
          if t == type then groups := groups.pop.push (t, ys.push x)
          else groups := groups.push (type, #[x])
        | none => groups := groups.push (type, #[x])
      let name (x : Expr) : RenderM Text := return Text.math (nameTex (← x.fvarId!.getUserName))
      let quantifiers ← groups.toList.mapM fun (type, ys) => do
        let n ← Render.noun type
        let names ← ys.toList.mapM name
        return match names with
          | [one] => s!"every {n.singular} " ++ one ++ n.qualifier
          | _ => s!"all {n.plural} " ++ Text.joinAnd names ++ n.qualifier
      let hypotheses ← hypotheses.toList.mapM (Render.prose ·)
      let conclusion ← Render.prose conclusion
      -- A cited theorem is one proved before this proof, which the reader must be told: a
      -- bare "the theorem that …" reads as a fact the proof never introduced.
      let mut text : Text := match info with
        | .thmInfo _ => "the earlier theorem that "
        | .axiomInfo _ => "the axiom that "
        | _ => "the fact that "
      unless quantifiers.isEmpty do
        text := text ++ "for " ++ Text.joinAnd quantifiers ++ ", "
      if hypotheses.isEmpty then text := text ++ conclusion.text
      else text := text ++ "if " ++ Text.joinAnd (hypotheses.map (·.text)) ++ ", then " ++ conclusion.text
      -- What the theorem is applied to, where that is not said by its own variable names.
      let mut names := #[]
      let mut values := #[]
      for x in objects, a in args do
        unless shown.contains x do continue
        let some value ← Render.math a | continue
        let own := nameTex (← x.fvarId!.getUserName)
        names := names.push (Text.math own)
        values := values.push (value.tex, own)
      if values.any fun (value, own) => value != own then
        text := text ++ ", applied with " ++ Text.joinAnd (values.toList.map (Text.math ·.1)) ++
          " in place of " ++ Text.joinAnd names.toList
      return some text

/-- "the definition of subset", "the definitions of subset and intersection"; just "definition"
(as in "by definition") if none of the definitions has a name. -/
def definitionsText (decls : Array Name) : RenderM (Option Text) := do
  if decls.isEmpty then return none
  let concepts ← decls.filterMapM fun d => Render.renderer.phrase? Concept (mkConst d)
  let named := if concepts.any (!·.background) then concepts.filter (!·.background) else concepts
  let named := named.foldl (init := #[]) fun acc c =>
    if acc.any (·.name == c.name) then acc else acc.push c
  -- The first time a definition is used, the text says what it is.
  let mut parts : List Text := []
  for c in named do
    if (← get).defined.contains c.name then
      parts := parts ++ [Text.plain c.name]
    else
      modify fun s => { s with defined := s.defined.insert c.name }
      parts := parts ++ [c.name ++ " (" ++ c.definition ++ ")"]
  return some <| match parts with
    | [] => "definition"
    | [one] => "the definition of " ++ one
    | several => "the definitions of " ++ Text.joinAnd several

/-- The reasons of a step, sorted: the facts it follows from, what it holds by, and whether it
only says what an untranslated Lean step did. -/
private structure Because where
  /-- Ids of the facts. -/
  facts : Array Nat := #[]
  premises : List Prose := []
  /-- "the definition of subset and the theorem that …", without "by". -/
  cited? : Option Text := none
  definitionsOnly : Bool := false
  automation : Bool := false

/-- Whether `decl` is the only constructor of its type and all its fields are proofs, like
`And.intro`: then its arguments are exactly what proving the goal needs. `Exists.intro` is not
(choosing a witness is one-way), nor is `Or.inl`. -/
private def isSoleConstructor (decl : Name) : RenderM Bool := do
  let some (.ctorInfo c) := (← getEnv).find? decl | return false
  let some (.inductInfo i) := (← getEnv).find? c.induct | return false
  unless i.ctors.length == 1 do return false
  forallTelescopeReducing c.type fun xs _ =>
    (xs.extract c.numParams xs.size).allM fun x => do isProp (← inferType x)

private def because (pc : ProofContext) (reasons : Array Reason) (conclusion : Array Claim)
    (previous : Array Nat := #[]) : RenderM Because := do
  -- An implication the step before just stated, applied to other facts here, is not listed
  -- again: "… we have that if $x \in C$, then $x \in A$. Since $x \in C$, we have $x \in A$."
  let otherFacts := reasons.filter fun | .fact id _ => !previous.contains id | _ => false
  let isJustStatedImplication (id : Nat) : Bool :=
    previous.contains id && !otherFacts.isEmpty &&
      (pc.claims[id]?).any fun c => c.prop.expr.consumeMData.isArrow
  let mut facts := #[]
  let mut premises : Array Prose := #[]
  let mut cited : Array Text := #[]
  let mut definitions := #[]
  let mut automation := false
  -- Whether a lemma is used that makes a `suffices` one-way, written or not. The constructor
  -- of a type with one constructor (`And.intro`) is not: its arguments are exactly what is
  -- needed. Any other (`Or.inl`) is.
  let mut lemma := false
  for r in reasons do
    match r with
    | .fact id _ =>
      let some c := pc.claims[id]? | continue
      -- A premise that is the conclusion says nothing.
      if facts.contains id || conclusion.any (·.prop.expr == c.prop.expr) then continue
      facts := facts.push id
      unless isJustStatedImplication id do
        premises := premises.push (← listed (← instantiateMVars c.prop.expr))
    | .lemma decl args =>
      unless ← isSoleConstructor decl do lemma := true
      if let some t ← citation decl (args.map (·.expr)) then cited := cited.push t
    | .definition decl => definitions := definitions.push decl
    | .term proof => cited := cited.push (← exprCode proof.expr)
    | .automation _ => automation := true
  let definitions? ← definitionsText definitions
  let all := definitions?.toList ++ cited.toList
  return {
    facts, premises := premises.toList, automation
    cited? := if all.isEmpty then none else some (Text.joinAnd all)
    definitionsOnly := !lemma && cited.isEmpty && premises.isEmpty && definitions?.isSome }

/-- An untranslated Lean step: what it is, and what it proves or leaves to prove. -/
private def untranslatedText (ir : ProofIR) (n : Nat) : RenderM Text := do
  let some node := ir.node? n | return renderUntranslated ir #[]
  let source := Text.code (syntaxFirstLine node.stx)
  let target (g : MVarId) : RenderM (Option Text) := do
    let some gi := ir.goal? g | return none
    let t ← instantiateMVars gi.target
    let isProposition : Bool ← try isProp t catch _ => pure false
    if isProposition then return some (← Render.prose t).text else return none
  let some before := node.goalsBefore[0]?
    | return "The Lean proof goes on with " ++ source ++
        ", but nothing is left to prove at that point, so this step proves nothing."
  let after := node.goalsAfter.filter (!node.goalsBefore.contains ·)
  let untranslated : Text := ", which is not translated into English yet"
  if after.isEmpty then
    match ← target before with
    | some t => return "Lean proves " ++ t ++ " here with the step " ++ source ++ untranslated ++ "."
    | none => return "Lean finishes this part with the step " ++ source ++ untranslated ++ "."
  let remaining ← after.toList.filterMapM target
  let text := "The Lean proof continues with the step " ++ source ++ untranslated ++ "."
  match remaining with
  | [] => return text
  | t :: ts =>
    if !ts.isEmpty && ts.all (· == t) then
      return text ++ s!" It splits the proof into {remaining.length} cases, in each of which it remains to show that " ++ t ++ "."
    return text ++ " After it, it remains to show " ++
      Text.joinAnd (remaining.map ("that " ++ ·)) ++ "."

/-- The parts of a conjunction `P ∧ Q ∧ …`. -/
private partial def conjuncts (e : Expr) : List Expr :=
  if e.isAppOfArity ``And 2 then conjuncts e.appFn!.appArg! ++ conjuncts e.appArg! else [e]

/-- Where a step stands in the text, which decides how it starts. -/
structure StepPlace where
  /-- The facts the step before it established. -/
  previous : Array Nat := #[]
  /-- Whether the step before it introduced objects or assumptions ("Let $x \in A$."). -/
  afterIntro : Bool := false
  /-- The goal the sentence before it announced ("First, we show that …", "We claim that …"),
  if this is the first step proving it. -/
  announced? : Option Expr := none

/-- The sentence for one step. `none` for a step that is only structure (`split`: its branches
are introduced one by one). -/
private def stepTextCore (pc : ProofContext) (place : StepPlace) (s : ProofStep) (b : Because) :
    RenderM (Option Text) := do
  let previous := place.previous
  let prose (c : Claim) : RenderM Prose := do Render.prose (← instantiateMVars c.prop.expr)
  let sentence (t : Text) : Option Text := some (t.capitalize ++ ".")
  let by_ : Text := match b.cited? with
    | some t => " by " ++ t
    | none => .empty
  -- "Hence" when the step follows from what was just said, "since …" when it has to be recalled.
  let hence := !b.facts.isEmpty && b.facts.all previous.contains
  let then_ : Text := if place.afterIntro then "then " else "hence "
  let since := statements b.premises
  -- Its goal is the one just announced: say how it holds, not what it is again.
  let announced := match s.kind, place.announced? with
    | .conclude c, some g | .gap c _, some g => c.prop.expr == g
    | _, _ => false
  -- The goal is part of a conjunction the step before it established.
  let particular := match s.kind, b.facts, b.cited? with
    | .conclude goal, #[id], none =>
      previous.contains id && (pc.claims[id]?).any fun c =>
        let parts := conjuncts c.prop.expr
        (parts.length > 1 && parts.contains goal.prop.expr) ||
          (c.prop.expr == goal.prop.expr && previous.size > 1)
    | _, _, _ => false
  match s.kind with
  | .fix objects =>
    let clauses ← objects.toList.filterMapM fun o => groupClause { objects := #[o] }
    return sentence (joinClauses clauses)
  | .assume facts _ =>
    return sentence ("suppose " ++ Text.joinAnd (← facts.toList.mapM fun c => return "that " ++ (← prose c).text))
  | .derive facts =>
    let what := statements (← facts.toList.mapM prose)
    if b.automation then return sentence ("here we also know " ++
      Text.joinAnd (← facts.toList.mapM fun c => return "that " ++ (← prose c).text))
    -- "we have that if P, then Q by T" would leave unclear what "by T" belongs to.
    let proses ← facts.toList.mapM prose
    if !proses.all (·.simple) then
      if let some t := b.cited? then
        let lead : Text := if b.premises.isEmpty then .empty else "since " ++ since ++ ", "
        return sentence (lead ++ "by " ++ t ++ ", " ++ Text.joinAnd (proses.map (·.text)))
    if hence then return sentence (then_ ++ what ++ by_)
    if b.premises.isEmpty then return sentence ("we have " ++ what ++ by_)
    return sentence ("since " ++ since ++ ", we have " ++ what ++ by_)
  | .obtain objects facts =>
    let names := Text.joinAnd (objects.toList.map fun o => Text.math (nameTex o.name))
    let what := names ++ " such that " ++ statements (← facts.toList.mapM prose) ++ by_
    if hence then return sentence (then_ ++ "we obtain " ++ what)
    if b.premises.isEmpty then return sentence ("we obtain " ++ what)
    return sentence ("since " ++ since ++ ", we obtain " ++ what)
  | .claim fact _ => return sentence ("we claim that " ++ (← prose fact).text)
  | .conclude goal =>
    let what := (← prose goal).text
    if particular && !announced then return sentence ("in particular, " ++ what)
    if announced then
      if let #[.fact id _] := s.reasons then
        if (pc.claims[id]?).any (·.prop.expr == goal.prop.expr) then
          return sentence "we already know this"
      if s.reasons.isEmpty || (hence && b.cited?.isNone) then
        return sentence "this follows from what we have shown"
      if b.premises.isEmpty || hence then return sentence ("this holds" ++ by_)
      return sentence ("this follows from " ++ since ++ by_)
    -- `exact h`: the goal is a fact already.
    if let #[.fact id _] := s.reasons then
      if (pc.claims[id]?).any (·.prop.expr == goal.prop.expr) then
        return sentence ("we already know that " ++ what ++ ", which is what we needed to show")
    if s.reasons.isEmpty then return sentence ("therefore, " ++ what)
    if hence then return sentence (then_ ++ what ++ by_)
    if b.premises.isEmpty then return sentence ("we conclude that " ++ what ++ by_)
    return sentence ("since " ++ since ++ ", we conclude that " ++ what ++ by_)
  | .suffices goal =>
    let what := (← prose goal).text
    if b.definitionsOnly then return sentence ("by " ++ b.cited?.getD .empty ++ ", we need to show that " ++ what)
    let lead : Text := match b.premises.isEmpty, b.cited? with
      | true, none => .empty
      | true, some t => "by " ++ t ++ ", "
      | false, none => "since " ++ since ++ ", "
      | false, some t => "since " ++ since ++ ", by " ++ t ++ " "
    return sentence (lead ++ "it suffices to show that " ++ what)
  | .gap goal cause =>
    if announced then
      return some <| match cause with
        | .unfinished => "The Lean proof does not prove this yet."
        | .sorry => "The Lean proof leaves this out with " ++ Text.code "sorry" ++ "."
        | .error => "Lean reports an error here, so this is not proved yet."
    let what := "it remains to show that " ++ (← prose goal).text
    return some <| match cause with
      | .unfinished => what.capitalize ++ ", which the Lean proof does not do yet."
      | .sorry => what.capitalize ++ ": the Lean proof leaves this out with " ++ Text.code "sorry" ++ "."
      | .error => what.capitalize ++ ": Lean reports an error at this point, so this is not proved yet."
  | .untranslated n => return some (← untranslatedText pc.ir n)
  | .split .. => return none
  | _ => return some (renderUntranslated pc.ir s.origin.nodes)

/-- The sentence for one step (see `stepTextCore`). A definition counts as given (its
explanation is not repeated) only if the sentence cites it. -/
private def stepText (pc : ProofContext) (place : StepPlace) (s : ProofStep) :
    RenderM (Option Text) := do
  let conclusion := match s.kind with
    | .derive cs | .obtain _ cs => cs
    | .conclude c | .suffices c => #[c]
    | _ => #[]
  let defined := (← get).defined
  let b ← because pc s.reasons conclusion place.previous
  let text? ← stepTextCore pc place s b
  let cited := (b.cited?.map (·.toMarkup)).getD ""
  unless !cited.isEmpty && text?.any fun t => (t.toMarkup.splitOn cited).length > 1 do
    modify fun st => { st with defined }
  return text?

/-- The nodes of the first step of `steps` that has any. -/
private partial def firstNodes (steps : Array ProofStep) : Array Nat :=
  steps.foldl (init := #[]) fun acc s =>
    if !acc.isEmpty then acc
    else if !s.origin.nodes.isEmpty then s.origin.nodes
    else match s.kind with
      | .claim _ b => firstNodes b.steps
      | .split _ bs => bs.foldl (init := #[]) fun acc b =>
          if !acc.isEmpty then acc else firstNodes b.body.steps
      | _ => #[]

/-- The sentence that opens the `i`-th branch of a split: what is shown, or assumed, in it. -/
private def branchText (kind : IR.SplitKind) (i : Nat) (b : Branch) (sameGoals : Bool) :
    RenderM (Option Text) := do
  let prose (c : Claim) : RenderM Text := return (← Render.prose (← instantiateMVars c.prop.expr)).text
  let assumptions ← b.assumptions.toList.mapM fun c => return "that " ++ (← prose c)
  match kind with
  | .cases _ | .induction _ =>
    if assumptions.isEmpty then return none
    let lead : Text := if i == 0 then "First, suppose " else "Now suppose instead "
    return some (lead ++ Text.joinAnd assumptions ++ ".")
  | _ =>
    let some goal := b.body.goal? | return none
    -- Cases of one goal, which an untranslated step made: they differ in what they know.
    if sameGoals then
      return some (if i == 0 then "Consider the first case." else "Now consider the next case.")
    let lead : Text := if i == 0 then "First, we show that " else "Next, we show that "
    return some (lead ++ (← prose goal) ++ ".")

/-- The sentences of a block, in order. Nested proofs keep their own steps and source
locations. -/
private partial def renderBlock (pc : ProofContext) (b : Block) (announced? : Option Expr := none) :
    RenderM (Array RenderedStep × Bool) := do
  let mut out := #[]
  let mut place : StepPlace := { announced? }
  -- Whether something in the block is not proved: then nothing after it is concluded for free.
  let mut gapped := false
  for s in b.steps, i in [0:b.steps.size] do
    let free := s.reasons.isEmpty && match s.kind with | .conclude _ => true | _ => false
    unless gapped && free do
      if let some text ← stepText pc place s then
        out := out.push { step := s.id, nodes := s.origin.nodes, text }
    place := { previous := established s.kind
               afterIntro := match s.kind with | .fix _ | .assume .. => true | _ => false }
    match s.kind with
    | .gap .. => gapped := true
    | .claim fact proof =>
      let (steps, g) ← renderBlock pc proof (some fact.prop.expr)
      out := out ++ steps
      -- What follows uses the claim: say that it rests on something not proved.
      if g && i + 1 < b.steps.size then
        out := out.push { step := s.id, nodes := s.origin.nodes
                          text := "We go on as if this were proved." }
      gapped := gapped || g
    | .split kind branches =>
      for branch in branches, i in [0:branches.size] do
        let nodes := match firstNodes branch.body.steps with
          | #[] => s.origin.nodes
          | nodes => nodes
        let goals := branches.filterMap (·.body.goal?.map (·.prop.expr))
        let sameGoals := goals.size > 1 && goals.all (· == goals[0]!)
        let header? ← branchText kind i branch sameGoals
        if let some text := header? then
          out := out.push { step := s.id, nodes, text }
        let announced? := if header?.isSome && branch.assumptions.isEmpty && !sameGoals
          then branch.body.goal?.map (·.prop.expr) else none
        let (steps, g) ← renderBlock pc branch.body announced?
        out := out ++ steps
        gapped := gapped || g
      place := {}
    | _ => pure ()
  return (out, gapped)

/-- Every step as the Lean it came from. -/
private partial def quotedBlock (ir : ProofIR) (b : Block) : Array RenderedStep :=
  b.steps.flatMap fun s =>
    let own : Array RenderedStep :=
      if s.origin.nodes.isEmpty || s.origin.relation == .synthesized then #[]
      else #[{ step := s.id, nodes := s.origin.nodes, text := renderUntranslated ir s.origin.nodes }]
    own ++ match s.kind with
      | .claim _ proof => quotedBlock ir proof
      | .split _ branches => branches.flatMap (quotedBlock ir ·.body)
      | _ => #[]

/-- `ir` as the Lean it is, for a proof whose presentation `d` does not verify: the statement of
the declaration as Lean code, and each step as its source. Nothing here was translated, so
nothing can say something else than the Lean does. Runs inside `ir.withContext`. -/
def renderQuoted (ir : ProofIR) (d : PresentedDecl) : MetaM Rendered := do
  let env ← getEnv
  let statement? ← match if ir.isDeclBody then env.find? ir.decl else none with
    | some info => pure (some ((s!"{roleLabel d.role}. " : Text) ++ (← exprCode info.type) ++ "."))
    | none => pure none
  -- One sentence for a tactic, however many steps it was presented as.
  let steps := (quotedBlock ir d.proof).foldl (init := #[]) fun acc s =>
    if acc.any (·.nodes == s.nodes) then acc else acc.push s
  let steps := if steps.isEmpty then
      #[{ step := 0, nodes := #[], text := renderUntranslated ir #[] }]
    else steps
  return { statement?, steps }

/-- The English of `d`, the presentation of `ir`, when only its statement verifies: the
statement in English, and the steps as their source. Runs inside `ir.withContext`. -/
def renderStatementOnly (ir : ProofIR) (d : PresentedDecl) : MetaM Rendered := do
  let statement? ← ir.withGoalContext ir.rootGoal do
    if ir.isDeclBody && (← isProp d.conclusion.prop.expr) then some <$> renderStatement d
    else pure none
  return { (← renderQuoted ir d) with statement? }

/-- The objects of the statement that its text does not introduce unless something names them:
the implicit ones without properties (`{α : Type}`). -/
private def implicitObjects (d : PresentedDecl) : FVarIdSet :=
  d.objects.foldl (init := {}) fun acc g => g.objects.foldl (init := acc) fun acc o =>
    if (o.binderInfo == .implicit || o.binderInfo == .strictImplicit) && o.properties.isEmpty
    then acc.insert o.fvar else acc

/-- The English of the steps of `d`. Runs inside `ir.withContext`. -/
def renderProof (ir : ProofIR) (d : PresentedDecl) : MetaM (Array RenderedStep) :=
  d.withLocals do
    let pc : ProofContext := { ir, claims := declClaims d }
    (Prod.fst <$> renderBlock pc d.proof).run { omitted := implicitObjects d, plainElements := true } |>.run' {}

/-- The English of `d`, the presentation of `ir`. Runs inside `ir.withContext`. -/
def render (ir : ProofIR) (d : PresentedDecl) : MetaM Rendered := do
  let statement? ← ir.withGoalContext ir.rootGoal do
    if ir.isDeclBody && (← isProp d.conclusion.prop.expr) then some <$> renderStatement d
    else pure none
  return { statement?, steps := ← renderProof ir d }

end Distill.Informalizer
