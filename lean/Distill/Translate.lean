import Distill.Informalizer.Pipeline
import Lean.Server.Rpc.RequestHandling

/-!
# The translation the web app shows

`Distill.translate` is the RPC method the level page calls through the editor's language server
connection. It runs the informalization pipeline (`Distill.Informalizer.Pipeline`) on the
document and returns its English line by line: a theorem's statement at the line of its name, and
every proof step at the line its tactic starts on.
-/

open Lean Server Elab

namespace Distill

open Distill.Informalizer Distill.Informalizer.IR

structure LineTranslation where
  /-- zero-based line in the document -/
  line : Nat
  /-- As JSON, a list of `{"kind": "text" | "math" | "code", "text": …}`. -/
  english : Text
  deriving FromJson, ToJson, Repr, BEq

structure TranslateParams where
  deriving FromJson, ToJson

/-- The English of one proof, line by line. `env` is the environment after its declaration. -/
def lineTranslations (env : Environment) (p : Informalized) : Array LineTranslation := Id.run do
  let mut out := #[]
  -- A `by` block that is not a declaration's body has no statement of its own.
  if p.ir.isDeclBody then
    -- The line of the declaration's name, or of the proof if it has none (`example`).
    let nameLine? := (declRangeExt.find? (asyncMode := .local) env p.ir.decl).map
      (·.selectionRange.pos.line)
    if let some line := nameLine? <|> nodeLine? p.ir 0 then
      out := out.push { line := line - 1, english := p.english.statement }
  for s in p.english.steps do
    if let some line := stepLine? p.ir s then
      out := out.push { line := line - 1, english := s.text }
  return out

/-- The English of the proofs in the InfoTree of one elaborated command. -/
def translateTree (tree : InfoTree) : IO (Array LineTranslation) := do
  let some ctx := commandContext? tree | return #[]
  return (← informalizeTree tree).flatMap (lineTranslations ctx.env)

/-- The English of the proofs in a document, given the InfoTrees of its commands, by line. -/
def translateTrees (trees : Array InfoTree) : IO (Array LineTranslation) := do
  let lines ← trees.flatMapM translateTree
  -- Stable, so a line's statement stays before its steps.
  return (lines.toList.mergeSort (·.line ≤ ·.line)).toArray

/-- Called by the level page through the editor's language server connection. -/
@[server_rpc_method]
def translate (_ : TranslateParams) : RequestM (RequestTask (Array LineTranslation)) := do
  let doc ← RequestM.readDoc
  RequestM.mapTaskCostly doc.cmdSnaps.waitAll fun (snaps, _) =>
    translateTrees (snaps.toArray.map (·.infoTree))

end Distill
