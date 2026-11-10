import Distill.Informalizer.Extract.Frontend
import Distill.Levels.Demo

/-! The language server elaborates proofs asynchronously. Extraction from the substituted
InfoTree must give the same Proof IR as synchronous elaboration. (Outside the language server
Lean may still elaborate these proofs synchronously, so this does not replace a test through
the server.) -/

open Distill.Informalizer.Extract

/-- Term proofs, whose first node is built from the context around the body. -/
private def termProofs : String := "
theorem blocks (p q : Prop) (hp : p) (hq : q) : p ∧ q := ⟨by exact hp, by exact hq⟩
theorem under_binders (p q : Prop) : p ∧ q → q ∧ p := fun h => ⟨by exact h.2, h.1⟩
"

private unsafe def formatAll (async : Bool) (input : String) : IO String := do
  let (proofs, _, env) ← extractSource input (async := async)
  proofs.foldlM (init := "") fun s ir => return s ++ (← formatProof env ir)

#eval show IO Unit from do
  for input in [← IO.FS.readFile "Distill/Levels/Demo.lean", termProofs] do
    let sync ← unsafe formatAll false input
    let async ← unsafe formatAll true input
    if sync.isEmpty || sync != async then
      throw <| .userError s!"asynchronous extraction differs:\n{sync}\n---\n{async}"
