import Distill.Informalizer.Extract.Frontend
import Distill.Levels.Demo

/-! The language server elaborates proofs asynchronously. Extraction from the substituted
InfoTree must give the same Proof IR as synchronous elaboration. (Outside the language server
Lean may still elaborate these proofs synchronously, so this does not replace a test through
the server.) -/

open Distill.Informalizer.Extract

private unsafe def formatAll (async : Bool) : IO String := do
  let (proofs, _, env) ← extractSource (← IO.FS.readFile "Distill/Levels/Demo.lean") (async := async)
  proofs.foldlM (init := "") fun s ir => return s ++ (← formatProof env ir)

#eval show IO Unit from do
  let sync ← unsafe formatAll false
  let async ← unsafe formatAll true
  if sync.isEmpty || sync != async then
    throw <| .userError s!"asynchronous extraction differs:\n{sync}\n---\n{async}"
