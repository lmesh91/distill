import Distill.Informalizer.Frontend
import Distill.Levels.Demo

/-! Edge cases: one proof per construct a learner might write, each checked against what its
kind requires.

* every kind: the pipeline does not fail, the statement verifies as identical to the original,
  the proof has English (never a blank), and the presentation passes `verify` (a complete or an
  incomplete proof, never a failed check);
* `alternative` (a complete proof using the demo's constructs): moreover the proof verifies as
  complete and its English has no Lean code in it.

`partial` is a proof being typed, `broken` one with an error, and `unsupported` a complete proof
using something outside the demo. Proofs that do not parse are given as source text. -/

open Lean Elab Command Distill Distill.Informalizer Distill.Levels.Demo

/-- The English of one proof and whether it meets what `kind` requires. -/
def edgeCaseReport (kind : String) (p : Informalized) : String := Id.run do
  let mut problems : Array String := #[]
  let mut out := ""
  match p.english.statement? with
  | some st => out := out ++ st.toMarkup
  | none => problems := problems.push "no statement"
  let text := p.english.proofText
  if text.toMarkup.trimAscii.isEmpty then problems := problems.push "no English for the proof"
  out := out ++ s!"\nProof. {text.toMarkup}"
  match p.verification? with
  | some v =>
    out := out ++ s!"\nverify: {v.statement.describe}; {v.proof.describe}"
    unless v.statement matches .identical do problems := problems.push "statement changed"
    if let some reason := v.failure? then problems := problems.push s!"not verified: {reason}"
    if kind == "alternative" then
      unless v.proof matches .complete _ do problems := problems.push "proof not complete"
      if p.english.steps.any (·.text.leaves.any (· matches .code _)) then
        problems := problems.push "Lean code in the English"
  | none => problems := problems.push "not verified"
  out ++ s!"\n{kind}: {if problems.isEmpty then "meets its kind's requirements" else ", ".intercalate problems.toList}"

/-- `#edge_case kind cmd` elaborates `cmd` and reports each of its proofs (`edgeCaseReport`). -/
elab "#edge_case " kind:str cmd:command : command =>
  elabAndDescribe cmd fun ir _ => return edgeCaseReport kind.getString (← informalize ir)

/-- Reports every proof of `source`, a whole Lean file (for proofs that do not parse). -/
unsafe def edgeCaseSource (kind : String) (source : String) : IO Unit := do
  let (trees, _, _) ← Extract.elabSource source "<edge case>"
  let mut proofs := 0
  for tree in trees do
    for p in ← informalizeTree tree do
      proofs := proofs + 1
      IO.println (edgeCaseReport kind p)
  if proofs == 0 then IO.println s!"{kind}: no proofs"

/-! `intro _ _` leaves the names inaccessible (level 1). -/
/--
info: Theorem. Let $A$ be a set. Then $A \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A$, $x \in A$. Let $x \in A$. We already know that $x \in A$, which is what we needed to show.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l1_anonymous (A : Set α) : A ⊆ A := by
  intro _ _
  assumption

/-! Term mode with an unnamed element (level 1). -/
/--
info: Theorem. Let $A$ be a set. Then $A \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A$, $x \in A$. Let $x \in A$. We already know that $x \in A$, which is what we needed to show.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l1_term_underscore (A : Set α) : A ⊆ A :=
  fun _ h => h

/-! `cases … with` (level 2). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$. Let $x \in A \cap B$. Then $x \in A$ and $x \in B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them). We already know that $x \in A$, which is what we needed to show.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l2_cases (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  cases hx with
  | intro ha hb => exact ha

/-! `have` proved by a nested tactic block (level 2). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$. Let $x \in A \cap B$. We claim that $x \in A$ and $x \in B$. This follows from $x \in A \cap B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them). In particular, $x \in A$.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l2_have_by (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  have h : x ∈ A ∧ x ∈ B := by
    exact hx
  exact h.1

/-! `obtain` destructuring the membership (level 2). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$. Let $x \in A \cap B$. Then $x \in A$ and $x \in B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them). We already know that $x \in A$, which is what we needed to show.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l2_obtain (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  obtain ⟨ha, hb⟩ := hx
  exact ha

/-! `rintro` with a pattern (level 2). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$. Let $x \in A \cap B$. Then $x \in A$ and $x \in B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them). We already know that $x \in A$, which is what we needed to show.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l2_rintro (A B : Set α) : A ∩ B ⊆ A := by
  rintro x ⟨ha, hb⟩
  exact ha

/-! Term mode with a pattern-matching `fun` (level 2). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$. Let $x \in A \cap B$. Then $x \in A$ and $x \in B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them). We already know that $x \in A$, which is what we needed to show.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l2_term_pattern (A B : Set α) : A ∩ B ⊆ A :=
  fun x ⟨ha, _⟩ => ha

/-! Numeric projection (level 3). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in B$. Let $x \in A \cap B$. Then $x \in A$ and $x \in B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them). In particular, $x \in B$.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l3_proj_2 (A B : Set α) : A ∩ B ⊆ B := by
  intro x hx
  exact hx.2

/-! `apply And.intro` without bullets (level 4). -/
/--
info: Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in C$, $x \in A \cap B$. Let $x \in C$. By the definition of intersection (the intersection of two sets consists of the elements that belong to both of them), we need to show that $x \in A$ and $x \in B$. First, we show that $x \in A$. This follows from $C \subseteq A$ and $x \in C$ by the definition of subset. Next, we show that $x \in B$. This follows from $C \subseteq B$ and $x \in C$ by the definition of subset. Therefore, $x \in A \cap B$.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l4_apply_and {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B := by
  intro x hx
  apply And.intro
  exact hCA x hx
  exact hCB x hx

/-! `case` naming the goals of `constructor` (level 4). -/
/--
info: Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in C$, $x \in A \cap B$. Let $x \in C$. By the definition of intersection (the intersection of two sets consists of the elements that belong to both of them), we need to show that $x \in A$ and $x \in B$. First, we show that $x \in A$. This follows from $C \subseteq A$ and $x \in C$ by the definition of subset. Next, we show that $x \in B$. This follows from $C \subseteq B$ and $x \in C$ by the definition of subset. Therefore, $x \in A \cap B$.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l4_case {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B := by
  intro x hx
  constructor
  case left => exact hCA x hx
  case right => exact hCB x hx

/-! A hypothesis applied to the element only (level 4). -/
/--
info: Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in C$, $x \in A \cap B$. Let $x \in C$. Since $C \subseteq A$, by the definition of subset, if $x \in C$, then $x \in A$. Since $x \in C$, we have $x \in A$. Since $C \subseteq B$ and $x \in C$, we have $x \in B$ by the definition of subset. Since $x \in A$ and $x \in B$, we conclude that $x \in A \cap B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them).
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l4_partial_app {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B := by
  intro x hx
  have hA := hCA x
  exact ⟨hA hx, hCB x hx⟩

/-! `refine` with one part given and one hole (level 4). -/
/--
info: Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in C$, $x \in A \cap B$. Let $x \in C$. Since $C \subseteq A$ and $x \in C$, we have $x \in A$ by the definition of subset. Since $x \in A$, by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them) it suffices to show that $x \in B$. Since $C \subseteq B$ and $x \in C$, we conclude that $x \in B$ by the definition of subset.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l4_refine_partial {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B := by
  intro x hx
  refine ⟨hCA x hx, ?_⟩
  exact hCB x hx

/-! `apply subset_inter` with bullets (level 5). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B \cap A$.
Proof. By the previously proved theorem that for all sets $A$, $B$ and $C$, if $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$, applied with $B$, $A$ and $A \cap B$ in place of $A$, $B$ and $C$, it suffices to show that $A \cap B \subseteq B$ and $A \cap B \subseteq A$. First, we show that $A \cap B \subseteq B$. This holds by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B$. Next, we show that $A \cap B \subseteq A$. This holds by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq A$. Therefore, $A \cap B \subseteq B \cap A$.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l5_apply (A B : Set α) : A ∩ B ⊆ B ∩ A := by
  apply subset_inter
  · exact inter_subset_right A B
  · exact inter_subset_left A B

/-! Earlier theorems applied to the element (level 5). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B \cap A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in B \cap A$. Let $x \in A \cap B$. Then $x \in A$ by the definition of subset and the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq A$. Since $x \in A \cap B$, we have $x \in B$ by the definition of subset and the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B$. Since $x \in B$ and $x \in A$, we conclude that $x \in B \cap A$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them).
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l5_lemma_as_function (A B : Set α) : A ∩ B ⊆ B ∩ A := by
  intro x hx
  have ha : x ∈ A := inter_subset_left A B x hx
  have hb : x ∈ B := inter_subset_right A B x hx
  exact ⟨hb, ha⟩

/-! Arguments left as `_` (level 5). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B \cap A$.
Proof. We have $A \cap B \subseteq B$ by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B$. We have $A \cap B \subseteq A$ by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq A$. Since $A \cap B \subseteq B$ and $A \cap B \subseteq A$, we conclude that $A \cap B \subseteq B \cap A$ by the previously proved theorem that for all sets $A$, $B$ and $C$, if $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$, applied with $B$, $A$ and $A \cap B$ in place of $A$, $B$ and $C$.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l5_underscores (A B : Set α) : A ∩ B ⊆ B ∩ A := by
  exact subset_inter (inter_subset_right _ _) (inter_subset_left _ _)

/-! `apply Set.ext` (level 6). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
Proof. By extensionality for sets (two sets are equal if each is a subset of the other), it suffices to show that $A \cap B \subseteq B \cap A$ and $B \cap A \subseteq A \cap B$. First, we show that $A \cap B \subseteq B \cap A$. This holds by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$. Next, we show that $B \cap A \subseteq A \cap B$. This holds by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$, applied with $B$ and $A$ in place of $A$ and $B$. Therefore, $A \cap B = B \cap A$.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l6_apply_ext (A B : Set α) : A ∩ B = B ∩ A := by
  apply Set.ext
  · exact inter_subset_inter_comm A B
  · exact inter_subset_inter_comm B A

/-! The goals of `ext` proved in the other order (level 6). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
Proof. By extensionality for sets (two sets are equal if each is a subset of the other), it suffices to show that $B \cap A \subseteq A \cap B$ and $A \cap B \subseteq B \cap A$. First, we show that $B \cap A \subseteq A \cap B$. This holds by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$, applied with $B$ and $A$ in place of $A$ and $B$. Next, we show that $A \cap B \subseteq B \cap A$. This holds by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$. Therefore, $A \cap B = B \cap A$.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l6_case_reversed (A B : Set α) : A ∩ B = B ∩ A := by
  ext
  case h₂ => exact inter_subset_inter_comm B A
  case h₁ => exact inter_subset_inter_comm A B

/-! Both inclusions as `have`s first (level 6). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
Proof. We have $A \cap B \subseteq B \cap A$ by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$. We have $B \cap A \subseteq A \cap B$ by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$, applied with $B$ and $A$ in place of $A$ and $B$. Since $A \cap B \subseteq B \cap A$ and $B \cap A \subseteq A \cap B$, we conclude that $A \cap B = B \cap A$ by extensionality for sets (two sets are equal if each is a subset of the other).
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l6_have_first (A B : Set α) : A ∩ B = B ∩ A := by
  have h₁ : A ∩ B ⊆ B ∩ A := inter_subset_inter_comm A B
  have h₂ : B ∩ A ⊆ A ∩ B := inter_subset_inter_comm B A
  exact Set.ext h₁ h₂

/-! `<;>` running one tactic on both goals (level 6). -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
Proof. By extensionality for sets (two sets are equal if each is a subset of the other), it suffices to show that $A \cap B \subseteq B \cap A$ and $B \cap A \subseteq A \cap B$. First, we show that $A \cap B \subseteq B \cap A$. This holds by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$. Next, we show that $B \cap A \subseteq A \cap B$. This holds by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$, applied with $B$ and $A$ in place of $A$ and $B$. Therefore, $A \cap B = B \cap A$.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
alternative: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "alternative"
theorem l6_seq_apply (A B : Set α) : A ∩ B = B ∩ A := by
  ext <;> apply inter_subset_inter_comm

/-! One of the two goals of `constructor` proved. -/
/--
info: Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in C$, $x \in A \cap B$. Let $x \in C$. By the definition of intersection (the intersection of two sets consists of the elements that belong to both of them), we need to show that $x \in A$ and $x \in B$. First, we show that $x \in A$. This follows from $C \subseteq A$ and $x \in C$ by the definition of subset. Next, we show that $x \in B$. The Lean proof does not prove this yet.
verify: identical to the original statement; incomplete (no step proves ?g4)
partial: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "partial"
theorem p_constructor_one {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B := by
  intro x hx
  constructor
  · exact hCA x hx

/-! Nothing after `by` yet. -/
/--
info: Theorem. Let $A$ be a set. Then $A \subseteq A$.
Proof. It remains to show that $A \subseteq A$, which the Lean proof does not do yet.
verify: identical to the original statement; incomplete (no step proves the statement)
partial: meets its kind's requirements
-/
#guard_msgs in
#eval edgeCaseSource "partial" r#"import Distill.Levels.Demo
open Distill Distill.Levels.Demo

theorem subset_rfl (A : Set α) : A ⊆ A := by
"#

/-! `ext` and nothing else. -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
Proof. By extensionality for sets (two sets are equal if each is a subset of the other), it suffices to show that $A \cap B \subseteq B \cap A$ and $B \cap A \subseteq A \cap B$. First, we show that $A \cap B \subseteq B \cap A$. The Lean proof does not prove this yet. Next, we show that $B \cap A \subseteq A \cap B$. The Lean proof does not prove this yet.
verify: identical to the original statement; incomplete (no step proves ?g1, ?g2)
partial: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "partial"
theorem p_ext_only (A B : Set α) : A ∩ B = B ∩ A := by
  ext

/-! `have` typed up to `:=`. -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$. Let $x \in A \cap B$. We claim that $x \in A$ and $x \in B$. Lean reports an error here, so this is not proved yet. We go on as if this were proved. It remains to show that $x \in A$, which the Lean proof does not do yet.
verify: identical to the original statement; incomplete (no step proves ?g3)
partial: meets its kind's requirements
-/
#guard_msgs in
#eval edgeCaseSource "partial" r#"import Distill.Levels.Demo
open Distill Distill.Levels.Demo

theorem inter_subset_left (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  have h : x ∈ A ∧ x ∈ B :=
"#

/-! The statement without a proof. -/
/--
info: Theorem. Let $A$ be a set. Then $A \subseteq A$.
Proof. It remains to show that $A \subseteq A$, which the Lean proof does not do yet.
verify: identical to the original statement; incomplete (no step proves the statement)
partial: meets its kind's requirements
-/
#guard_msgs in
#eval edgeCaseSource "partial" r#"import Distill.Levels.Demo
open Distill Distill.Levels.Demo

theorem subset_rfl (A : Set α) : A ⊆ A
"#

/-! A `_` hole in a term. -/
/--
info: Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in C$, $x \in A \cap B$. Let $x \in C$. Since $C \subseteq A$ and $x \in C$, we have $x \in A$ by the definition of subset. We claim that $x \in B$. Lean reports an error here, so this is not proved yet. We go on as if this were proved. Since $x \in A$ and $x \in B$, we conclude that $x \in A \cap B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them).
verify: identical to the original statement; incomplete (a hole is unfilled)
partial: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "partial"
theorem p_term_hole {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B :=
  fun x hx => ⟨hCA x hx, _⟩

/-! An anonymous constructor not closed yet. -/
/--
info: Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in C$, $x \in A \cap B$. Let $x \in C$. Since $C \subseteq A$ and $x \in C$, we have $x \in A$ by the definition of subset. Since $C \subseteq B$ and $x \in C$, we have $x \in B$ by the definition of subset. Since $x \in A$, by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them) it suffices to show that $x \in B$. It remains to show that $x \in B$: Lean reports an error at this point, so this is not proved yet.
verify: identical to the original statement; incomplete (the proof uses `sorry`)
partial: meets its kind's requirements
-/
#guard_msgs in
#eval edgeCaseSource "partial" r#"import Distill.Levels.Demo
open Distill Distill.Levels.Demo

theorem subset_inter {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B := by
  intro x hx
  have ha : x ∈ A := hCA x hx
  have hb : x ∈ B := hCB x hx
  exact ⟨ha,
"#

/-! The second goal of `ext` given the first goal's proof. -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
Proof. By extensionality for sets (two sets are equal if each is a subset of the other), it suffices to show that $A \cap B \subseteq B \cap A$ and $B \cap A \subseteq A \cap B$. First, we show that $A \cap B \subseteq B \cap A$. This holds by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$. Next, we show that $B \cap A \subseteq A \cap B$. The Lean proof does not prove this yet.
verify: identical to the original statement; incomplete (no step proves ?g2)
broken: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "broken"
theorem b_ext_wrong_second (A B : Set α) : A ∩ B = B ∩ A := by
  ext
  exact inter_subset_inter_comm A B
  exact inter_subset_inter_comm A B

/-! A `have` whose proof does not have its type. -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$. Let $x \in A \cap B$. We claim that $x \in A$. Lean reports an error here, so this is not proved yet. We go on as if this were proved. We already know that $x \in A$, which is what we needed to show.
verify: identical to the original statement; incomplete (the proof uses `sorry`)
broken: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "broken"
theorem b_have_mismatch (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  have h : x ∈ A := hx
  exact h

/-! `intros` does not unfold the subset, so nothing is introduced. -/
/--
info: Theorem. Let $A$ be a set. Then $A \subseteq A$.
Proof. It remains to show that $A \subseteq A$, which the Lean proof does not do yet.
verify: identical to the original statement; incomplete (no step proves the statement)
broken: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "broken"
theorem b_intros (A : Set α) : A ⊆ A := by
  intros
  assumption

/-! A hypothesis applied to too few arguments. -/
/--
info: Theorem. Let $A$, $B$ and $C$ be sets. If $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in C$, $x \in A \cap B$. Let $x \in C$. We claim that $x \in A$. Lean reports an error here, so this is not proved yet. We go on as if this were proved. Since $C \subseteq B$ and $x \in C$, we have $x \in B$ by the definition of subset. Since $x \in A$ and $x \in B$, we conclude that $x \in A \cap B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them).
verify: identical to the original statement; incomplete (the proof uses `sorry`)
broken: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "broken"
theorem b_missing_arg {A B C : Set α} (hCA : C ⊆ A) (hCB : C ⊆ B) : C ⊆ A ∩ B := by
  intro x hx
  have ha : x ∈ A := hCA x
  have hb : x ∈ B := hCB x hx
  exact ⟨ha, hb⟩

/-! Two theorems in one file, the second broken. -/
/--
info: Theorem. Let $A$ be a set. Then $A \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A$, $x \in A$. Let $x \in A$. We already know that $x \in A$, which is what we needed to show.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
broken: meets its kind's requirements
Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$. Let $x \in A \cap B$. It remains to show that $x \in A$, which the Lean proof does not do yet.
verify: identical to the original statement; incomplete (no step proves ?g2)
broken: meets its kind's requirements
-/
#guard_msgs in
#eval edgeCaseSource "broken" r#"import Distill.Levels.Demo
open Distill Distill.Levels.Demo

theorem first (A : Set α) : A ⊆ A := by
  intro x hx
  exact hx
theorem second (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  exact hx
"#

/-! A misspelled tactic. -/
/--
info: Theorem. Let $A$ be a set. Then $A \subseteq A$.
Proof. It remains to show that $A \subseteq A$, which the Lean proof does not do yet.
verify: identical to the original statement; incomplete (no step proves the statement)
broken: meets its kind's requirements
-/
#guard_msgs in
#eval edgeCaseSource "broken" r#"import Distill.Levels.Demo
open Distill Distill.Levels.Demo

theorem subset_rfl (A : Set α) : A ⊆ A := by
  intor x hx
  exact hx
"#

/-! A theorem name that does not exist. -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B \cap A$.
Proof. We claim that $A \cap B \subseteq B$. Lean reports an error here, so this is not proved yet. We go on as if this were proved. We have $A \cap B \subseteq A$ by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq A$. Since $A \cap B \subseteq B$ and $A \cap B \subseteq A$, we conclude that $A \cap B \subseteq B \cap A$ by the previously proved theorem that for all sets $A$, $B$ and $C$, if $C \subseteq A$ and $C \subseteq B$, then $C \subseteq A \cap B$, applied with $B$, $A$ and $A \cap B$ in place of $A$, $B$ and $C$.
verify: identical to the original statement; incomplete (the proof uses `sorry`)
broken: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "broken"
theorem b_unknown_lemma (A B : Set α) : A ∩ B ⊆ B ∩ A := by
  exact subset_inter (inter_subset_second A B) (inter_subset_left A B)

/-! `all_goals`. -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B = B \cap A$.
Proof. By extensionality for sets (two sets are equal if each is a subset of the other), it suffices to show that $A \cap B \subseteq B \cap A$ and $B \cap A \subseteq A \cap B$. First, we show that $A \cap B \subseteq B \cap A$. This holds by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$. Next, we show that $B \cap A \subseteq A \cap B$. This holds by the previously proved theorem that for all sets $A$ and $B$, $A \cap B \subseteq B \cap A$, applied with $B$ and $A$ in place of $A$ and $B$. Therefore, $A \cap B = B \cap A$.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
unsupported: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "unsupported"
theorem u_all_goals (A B : Set α) : A ∩ B = B ∩ A := by
  ext
  all_goals exact inter_subset_inter_comm _ _

/-! A core theorem outside the demo. -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq B \cap A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in B \cap A$. Let $x \in A \cap B$. Then $x \in A$ and $x \in B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them). Hence $x \in B \cap A$ by the definition of intersection and the previously proved theorem that for all propositions $a$ and $b$, if $a$ and $b$, then $b$ and $a$, applied with $x \in A$ and $x \in B$ in place of $a$ and $b$.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
unsupported: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "unsupported"
theorem u_and_symm (A B : Set α) : A ∩ B ⊆ B ∩ A := by
  intro x hx
  exact And.symm hx

/-! A case distinction. -/
/--
info: Theorem. Let $A$ be a set. Then $A \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A$, $x \in A$. Let $x \in A$. The Lean proof continues with the step `by_cases h : x ∈ A`, which is not translated into English yet. It splits the proof into 2 cases, in each of which it remains to show that $x \in A$. Consider the first case. Here we also know that $x \in A$. We already know that $x \in A$, which is what we needed to show. Now consider the next case. Here we also know that $x \notin A$. Lean proves $x \in A$ here with the step `exact absurd hx h`, which is not translated into English yet.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
unsupported: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "unsupported"
theorem u_by_cases (A : Set α) : A ⊆ A := by
  intro x hx
  by_cases h : x ∈ A
  · exact h
  · exact absurd hx h

/-! `simp` closing the goal. -/
/--
info: Theorem. Let $A$ be a set. Then $A \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A$, $x \in A$. Let $x \in A$. Lean proves $x \in A$ here with the step `simp [hx]`, which is not translated into English yet.
verify: identical to the original statement; the steps rebuild a proof of the presented statement
unsupported: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "unsupported"
theorem u_simp (A : Set α) : A ⊆ A := by
  intro x hx
  simp [hx]

/-! `suffices`. -/
/--
info: Theorem. Let $A$ and $B$ be sets. Then $A \cap B \subseteq A$.
Proof. By the definition of subset (one set is a subset of another if every element of the first is an element of the second), we need to show that for every $x \in A \cap B$, $x \in A$. Let $x \in A \cap B$. The Lean proof continues with the step `suffices h : x ∈ A ∧ x ∈ B from h.1`, which is not translated into English yet. After it, it remains to show that $x \in A$ and $x \in B$. Since $x \in A \cap B$, we conclude that $x \in A$ and $x \in B$ by the definition of intersection (the intersection of two sets consists of the elements that belong to both of them).
verify: identical to the original statement; the steps rebuild a proof of the presented statement
unsupported: meets its kind's requirements
-/
#guard_msgs (info, drop error, drop warning) in
#edge_case "unsupported"
theorem u_suffices (A B : Set α) : A ∩ B ⊆ A := by
  intro x hx
  suffices h : x ∈ A ∧ x ∈ B from h.1
  exact hx
