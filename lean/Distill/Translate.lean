import Lean

open Lean Server

namespace Distill

structure LineTranslation where
  /-- zero-based line in the document -/
  line : Nat
  english : String
  deriving FromJson, ToJson

structure TranslateParams where
  deriving FromJson, ToJson

private def placeholders : Array String := #[
  "We proceed by induction.",
  "Consider an arbitrary natural number.",
  "By the induction hypothesis, the claim holds for the previous case.",
  "Rewriting with the definition simplifies the goal.",
  "It therefore suffices to show the remaining equality.",
  "This follows directly from commutativity.",
  "Both sides are now identical, which completes this case."
]

/--
Translates Lean source line by line into English.
Placeholder: picks a fixed sentence per line text until the real translator exists, so the same
line always maps to the same sentence.
-/
def translateSource (source : String) : Array LineTranslation := Id.run do
  let mut result := #[]
  for text in source.splitOn "\n", line in [0:source.length + 1] do
    let trimmed := text.trimAscii.toString
    if trimmed.isEmpty || trimmed.startsWith "--" || trimmed.startsWith "import " then continue
    let english := placeholders[trimmed.hash.toNat % placeholders.size]!
    result := result.push { line, english }
  return result

/-- Called by the level page through the editor's language server connection. -/
@[server_rpc_method]
def translate (_ : TranslateParams) : RequestM (RequestTask (Array LineTranslation)) := do
  let doc ← RequestM.readDoc
  return .pure (translateSource doc.meta.text.source)

end Distill
