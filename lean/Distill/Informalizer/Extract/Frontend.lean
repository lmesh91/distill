import Distill.Informalizer.Extract
import Distill.Informalizer.IR.Format

/-!
# Running extraction outside the language server

* `elabSource` elaborates a whole Lean file given as a string, and `extractSource` also extracts
  its proofs. The file's imports must already be built.
* `#proof_ir cmd` elaborates `cmd` and logs the Proof IR of its proofs, for debugging in
  the editor and for tests. Its source positions are relative to the start of `cmd`.
-/

namespace Distill.Informalizer.Extract

open Lean Meta Elab Command

/-- Elaborates `input` as a Lean file and returns the InfoTree of every command, with the
messages Lean produced and the final environment.

With `async`, proofs are elaborated in parallel as in the language server, and their InfoTrees
are only substituted into the command's tree once they finish.

Unsafe because importing the file's dependencies has to run their initializers, which register
their syntax. -/
unsafe def elabSource (input : String) (fileName : String := "<input>") (async := false) :
    IO (Array InfoTree × MessageLog × Environment) := do
  enableInitializersExecution
  let inputCtx := Parser.mkInputContext input fileName
  let (header, parserState, messages) ← Parser.parseHeader inputCtx
  let (env, messages) ← processHeader header {} messages inputCtx
  let opts := Elab.async.set {} async
  let cmdState := { Command.mkState env messages opts with infoState := { enabled := true } }
  let s ← IO.processCommands inputCtx parserState cmdState
  let infoState ← IO.wait s.commandState.infoState.substituteLazy
  return (infoState.trees.toArray, s.commandState.messages, s.commandState.env)

/-- Elaborates `input` as a Lean file (see `elabSource`) and returns the Proof IR of every
proof. -/
unsafe def extractSource (input : String) (fileName : String := "<input>") (async := false) :
    IO (Array IR.ProofIR × MessageLog × Environment) := do
  let (trees, messages, env) ← elabSource input fileName async
  return (← trees.flatMapM extractProofs, messages, env)

/-- Formats a Proof IR. `env` must contain the constants it mentions; `openDecls` and
`currNamespace` decide how their names are shortened, and `options` sets pretty-printer options. -/
def formatProof (env : Environment) (ir : IR.ProofIR) (lineOffset : Nat := 0)
    (openDecls : List OpenDecl := []) (currNamespace : Name := .anonymous)
    (options : Options := {}) : IO String := do
  let ctx : ContextInfo := { env, fileMap := default, ngen := {}, openDecls, currNamespace, options }
  ctx.runMetaM {} (ir.format lineOffset)

/--
Whether the assignments in `ir` add up to the proof term Lean stored for the declaration
(`ProofIR.proofTerm?`), as a short description. A check that extraction lost nothing.
-/
def checkProofTerm (env : Environment) (ir : IR.ProofIR) : IO String := do
  let ctx : ContextInfo := { env, fileMap := default, ngen := {} }
  ctx.runMetaM {} <| ir.withContext do
    let some t := ir.proofTerm? | return "incomplete (a goal is unassigned)"
    if t.hasMVar then return "incomplete (a hole is unfilled)"
    unless ir.isDeclBody do return "not compared (the `by` block is not the declaration's body)"
    let some value := (← getEnv).find? ir.decl >>= (·.value? (allowOpaque := true))
      | return "no declaration to compare with"
    let rebuilt ← mkLambdaFVars (ir.statement.binders.map .fvar) t
    -- Lean compiles recursive calls away, so there is nothing to compare them with.
    if t.hasAnyFVar (ir.recursiveHyps.contains ·) then
      -- The recursive references come after the binders their types mention.
      try check (← mkLambdaFVars ((ir.statement.binders ++ ir.recursiveHyps).map .fvar) t) catch e => return s!"DIFFERS: ill-typed: {← e.toMessageData.toString}"
      return "type-checks (not compared: the proof is recursive)"
    if rebuilt == value then return "rebuilds the declaration's proof term"
    if (← Core.betaReduce rebuilt) == (← Core.betaReduce value) then
      return "rebuilds the declaration's proof term up to β-reduction"
    -- Without proof irrelevance, any two proofs of a theorem's statement would be equal.
    try check rebuilt catch e => return s!"DIFFERS: ill-typed: {← e.toMessageData.toString}"
    if ← withoutProofIrrelevance (isDefEq rebuilt value) then
      return "definitionally equal to the declaration's proof term"
    return "DIFFERS from the declaration's proof term"

/-- `#proof_ir cmd` elaborates `cmd` and shows the Proof IR of its proofs. -/
elab "#proof_ir " cmd:command : command => do
  let before := (← getInfoState).trees.size
  withScope (fun scope => { scope with opts := Elab.async.set scope.opts false }) do
    elabCommand cmd
  let trees := (← getInfoState).trees.toArray.extract before
  let proofs ← trees.flatMapM fun t => extractProofs t
  let fileMap ← getFileMap
  let lineOffset := match cmd.raw.getPos? with
    | some pos => (fileMap.toPosition pos).line - 1
    | none => 0
  if proofs.isEmpty then
    logInfoAt cmd m!"no proofs"
  for ir in proofs do
    let text ← formatProof (← getEnv) ir lineOffset (← getOpenDecls) (← getCurrNamespace) (← getOptions)
    logInfoAt cmd (text ++ s!"  proof term: {← checkProofTerm (← getEnv) ir}")

/-- Extracts every proof in a Lean file and prints its Proof IR, for tests. Positions are
absolute. -/
unsafe def printFile (path : System.FilePath) : IO Unit := do
  let (proofs, messages, env) ← extractSource (← IO.FS.readFile path) path.toString
  for m in messages.toList do
    IO.println s!"message: {← m.toString}"
  for ir in proofs do
    IO.print (← formatProof env ir)
    IO.println s!"  proof term: {← checkProofTerm env ir}"

end Distill.Informalizer.Extract
