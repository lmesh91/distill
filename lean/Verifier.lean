module
import all Lake.CLI.Check
import LeanExport.Basic
import Lake.Check.Util

/-!
The exporter loads untrusted oleans and MUST run in the submission sandbox. The inspector
only reads inert NDJSON exports, in a fresh sandbox. Acceptance is decided by `lake comparator`,
including its independent kernel replay; the inspector supplies dependency and axiom details.
-/
open Lean LeanExport Lake.Check

-- `primitiveTargets` does not read its context. Reuse core's list instead of duplicating the
-- kernel primitives that comparator must compare against the challenge.
private def exportContext : Lake.Check.Context := {
  projectDir := "", challengeModule := .anonymous, solutionModule := .anonymous,
  theoremNames := #[], definitionNames := #[], legalAxioms := #[], leanPrefix := "",
  leanPath := "", binPath := "", whichSandbox := .noSandbox, whichLake := "",
  lakeHome := "", whichLean4Export := "", whichLeanChecker := "", whichEnvBin := "",
  externalKernels := {}, bundledKernels := #[], moduleStore := {}
}

private def exportModule (mod target : String) : IO Unit := do
  initSearchPath (← findSysroot)
  let env ← importModules #[{ module := mod.toName }] {}
  if mod == "Challenge" then
    unless (env.find? target.toName).any (fun info => info matches .thmInfo _) do
      throw <| IO.userError "the challenge must define the required theorem"
  let mut roots := (← primitiveTargets.run exportContext) ++ standardAxioms ++
    #[`Quot, `Quot.mk, `Quot.lift, `Quot.ind]
  -- Include even unused axioms: comparator normally exports just the theorem's dependencies.
  for (name, info) in env.constants do
    if info matches .axiomInfo _ then roots := roots.push name
  if env.contains target.toName then roots := roots.push target.toName
  dumpEnv env (some roots.toList)

private def readExport (path : String) : IO ExportedEnv := do
  parseStream (.ofHandle (← IO.FS.Handle.mk path .read))

private def inspect (challengePath solutionPath target : String) : IO Unit := do
  let challenge ← readExport challengePath
  let solution ← readExport solutionPath
  let mut introduced : Array String := #[]
  for name in solution.constOrder do
    if let some (.axiomInfo info) := solution.constMap[name]? then
      if challenge.constMap[name]? != some (.axiomInfo info) then
        introduced := introduced.push name.toString
  let mut pending := #[target.toName]
  let mut seen : Std.HashSet Name := {}
  let mut dependencies : Array String := #[]
  let mut axioms : Array String := #[]
  repeat
    if pending.isEmpty then break
    let name := pending.back!
    pending := pending.pop
    if seen.contains name then continue
    seen := seen.insert name
    let some info := solution.constMap[name]? | continue
    if name != target.toName then dependencies := dependencies.push name.toString
    if info matches .axiomInfo _ then axioms := axioms.push name.toString
    let (_, refs) := (runForUsedConsts info fun ref => modify (·.push ref) : StateM (Array Name) Unit).run #[]
    pending := pending ++ refs
  IO.println <| Json.compress <| Json.mkObj [
    ("theoremExists", toJson (solution.constMap.contains target.toName)),
    ("dependencies", toJson dependencies), ("axioms", toJson axioms),
    ("introducedAxioms", toJson introduced)]

public def main (args : List String) : IO Unit := do
  match args with
  | ["export", mod, target] => exportModule mod target
  | ["inspect", challenge, solution, target] => inspect challenge solution target
  | _ => throw <| IO.userError "expected: export MODULE THEOREM | inspect CHALLENGE SOLUTION THEOREM"
