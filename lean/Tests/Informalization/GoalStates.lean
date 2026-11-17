import Distill.Informalizer.Frontend
import Distill.Translate

/-! #91: every goal state of every demo proof, its objects, hypotheses and target, in English.
The last line checks that none of them contains Lean code. -/

open Lean Distill.Informalizer

unsafe def printGoalStates (path : System.FilePath) : IO Unit := do
  let (trees, _, _) ← Extract.elabSource (← IO.FS.readFile path) path.toString
  let mut withCode := 0
  for tree in trees do
    let some ctx := commandContext? tree | continue
    for ir in ← Extract.extractProofs tree do
      IO.println s!"{ir.decl}"
      let texts ← ctx.runMetaM {} <| ir.withContext do
        ir.goalOrder.mapM fun g => return (ir.goalNumbering g, ← renderGoalState ir g)
      for (name, text) in texts do
        IO.println s!"  ?{name}: {text.toMarkup}"
        if text.leaves.any (· matches .code _) then withCode := withCode + 1
  IO.println s!"goal states with Lean code: {withCode}"

/--
info: Distill.Levels.Demo.subset_rfl
  ?g0: Let $A$ be a set. We need to show that $A \subseteq A$.
  ?g1: Let $A$ be a set and let $x$ be arbitrary. We need to show that if $x \in A$, then $x \in A$.
  ?g2: Let $A$ be a set and let $x \in A$. We need to show that $x \in A$.
Distill.Levels.Demo.inter_subset_left
  ?g0: Let $A$ and $B$ be sets. We need to show that $A \cap B \subseteq A$.
  ?g1: Let $A$ and $B$ be sets and let $x$ be arbitrary. We need to show that if $x \in A \cap B$, then $x \in A$.
  ?g2: Let $A$ and $B$ be sets and let $x \in A \cap B$. We need to show that $x \in A$.
  ?g3: Let $A$ and $B$ be sets and let $x \in A \cap B$. Suppose that $x \in A$ and $x \in B$. We need to show that $x \in A$.
Distill.Levels.Demo.inter_subset_right
  ?g0: Let $A$ and $B$ be sets. We need to show that $A \cap B \subseteq B$.
  ?g1: Let $A$ and $B$ be sets and let $x$ be arbitrary. We need to show that if $x \in A \cap B$, then $x \in B$.
  ?g2: Let $A$ and $B$ be sets and let $x \in A \cap B$. We need to show that $x \in B$.
Distill.Levels.Demo.subset_inter
  ?g0: Let $A$, $B$ and $C$ be sets. Suppose that $C \subseteq A$ and that $C \subseteq B$. We need to show that $C \subseteq A \cap B$.
  ?g1: Let $A$, $B$ and $C$ be sets and let $x$ be arbitrary. Suppose that $C \subseteq A$ and that $C \subseteq B$. We need to show that if $x \in C$, then $x \in A \cap B$.
  ?g2: Let $A$, $B$ and $C$ be sets and let $x \in C$. Suppose that $C \subseteq A$ and that $C \subseteq B$. We need to show that $x \in A \cap B$.
  ?g3: Let $A$, $B$ and $C$ be sets and let $x \in C$. Suppose that $C \subseteq A$, that $C \subseteq B$ and that $x \in A$. We need to show that $x \in A \cap B$.
  ?g4: Let $A$, $B$ and $C$ be sets and let $x \in C$. Suppose that $C \subseteq A$, that $C \subseteq B$, that $x \in A$ and that $x \in B$. We need to show that $x \in A \cap B$.
Distill.Levels.Demo.inter_subset_inter_comm
  ?g0: Let $A$ and $B$ be sets. We need to show that $A \cap B \subseteq B \cap A$.
  ?g1: Let $A$ and $B$ be sets. Suppose that $A \cap B \subseteq A$. We need to show that $A \cap B \subseteq B \cap A$.
  ?g2: Let $A$ and $B$ be sets. Suppose that $A \cap B \subseteq A$ and that $A \cap B \subseteq B$. We need to show that $A \cap B \subseteq B \cap A$.
Distill.Levels.Demo.inter_comm
  ?g0: Let $A$ and $B$ be sets. We need to show that $A \cap B = B \cap A$.
  ?g1: Let $A$ and $B$ be sets. We need to show that $A \cap B \subseteq B \cap A$.
  ?g2: Let $A$ and $B$ be sets. We need to show that $B \cap A \subseteq A \cap B$.
goal states with Lean code: 0
-/
#guard_msgs in
#eval printGoalStates "Distill/Levels/Demo.lean"
