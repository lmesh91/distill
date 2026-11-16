import Lean.Data.Json

/-!
# The text the pipeline writes

English is not a string but a `Text`: a tree whose leaves say what they are (words, a LaTeX
formula, Lean code). Whoever shows it decides how: the web app typesets the formulas, a LaTeX
document would write them out, and `Text.toMarkup` flattens the tree to a string for tests and
debugging.

It is a tree, not a list, so that a part of a sentence can later carry data about what it stands
for (the hypothesis a formula restates, the theorem a phrase cites, the detail a step hides) as
a node around that part. There is no such node yet, and the JSON below is still a flat list of
leaves: the first kind of node that wraps others has to extend it (and its readers) to nest.
-/

namespace Distill.Informalizer

open Lean

inductive Text where
  /-- Words and punctuation. -/
  | plain (s : String)
  /-- A LaTeX formula, without delimiters. -/
  | math (tex : String)
  /-- Lean source, on one line. -/
  | code (lean : String)
  /-- The parts one after the other, with nothing in between. -/
  | seq (parts : Array Text)
  deriving Inhabited, Repr, BEq

namespace Text

instance : Coe String Text := ⟨.plain⟩

instance : Append Text where
  append
    | .seq a, .seq b => .seq (a ++ b)
    | .seq a, b => .seq (a.push b)
    | a, .seq b => .seq (#[a] ++ b)
    | a, b => .seq #[a, b]

def empty : Text := .seq #[]

/-- The leaves in reading order, with neighbouring words merged and empty leaves dropped. -/
partial def leaves (t : Text) : Array Text :=
  go t #[]
where
  go (t : Text) (acc : Array Text) : Array Text :=
    match t with
    | .seq parts => parts.foldl (fun acc p => go p acc) acc
    | .plain "" => acc
    | .plain s =>
      match acc.back? with
      | some (.plain s') => acc.pop.push (.plain (s' ++ s))
      | _ => acc.push t
    | t => acc.push t

def isEmpty (t : Text) : Bool := t.leaves.isEmpty

/-- Whether the text begins with the words `s`. -/
def startsWith (t : Text) (s : String) : Bool :=
  match t.leaves.toList with
  | .plain p :: _ => p.startsWith s
  | _ => false

/-- The text with its first letter in upper case. Text that begins with a formula or with code is
unchanged. -/
partial def capitalize (t : Text) : Text :=
  (go t).getD t
where
  /-- `none` if `t` is empty, so that the first letter is to be looked for after it. -/
  go : Text → Option Text
    | .plain "" => none
    | .plain s => some (.plain s.capitalize)
    | .seq parts => do
      let i ← parts.findIdx? (!·.isEmpty)
      return .seq (parts.set! i (← go parts[i]!))
    | t => some t

/-- The parts with `separator` between them. -/
def intercalate (separator : Text) (parts : List Text) : Text :=
  match parts with
  | [] => empty
  | first :: rest => rest.foldl (fun acc p => acc ++ separator ++ p) first

/-- "a", "a and b", "a, b and c". -/
def joinAnd : List Text → Text
  | [] => empty
  | [a] => a
  | [a, b] => a ++ " and " ++ b
  | a :: rest => a ++ ", " ++ joinAnd rest

/-- `s` between backticks. The fence is longer than any run of backticks in `s`, as in
Markdown. -/
private def fenced (s : String) : String :=
  let (longest, _) := s.foldl (init := (0, 0)) fun (longest, run) c =>
    if c == '`' then (max longest (run + 1), run + 1) else (longest, 0)
  let fence := "".pushn '`' (longest + 1)
  let pad := if s.startsWith "`" || s.endsWith "`" then " " else ""
  s!"{fence}{pad}{s}{pad}{fence}"

/-- The text as one string, with formulas as `$…$` and code as `` `…` ``. For tests, logs and
anything else that wants to read the text rather than lay it out. -/
def toMarkup (t : Text) : String :=
  String.join <| t.leaves.toList.map fun
    | .plain s => s
    | .math tex => s!"${tex}$"
    | .code lean => fenced lean
    | .seq _ => ""

/-- A list of leaves, each `{"kind": "text" | "math" | "code", "text": …}`. -/
instance : ToJson Text where
  toJson t := .arr <| t.leaves.map fun
    | .plain s => json% { kind: "text", text: $s }
    | .math tex => json% { kind: "math", text: $tex }
    | .code lean => json% { kind: "code", text: $lean }
    | .seq _ => .null

instance : FromJson Text where
  fromJson? j := do
    let parts ← (← j.getArr?).mapM fun leaf => do
      let text ← leaf.getObjValAs? String "text"
      match ← leaf.getObjValAs? String "kind" with
      | "text" => pure (Text.plain text)
      | "math" => pure (.math text)
      | "code" => pure (.code text)
      | kind => throw s!"unknown kind of text: {kind}"
    return .seq parts

end Text

end Distill.Informalizer
