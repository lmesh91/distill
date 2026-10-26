import Distill.Informalizer.IR.Common
import Distill.Informalizer.IR.Proof
import Distill.Informalizer.IR.Presentation

/-!
# Informalizer intermediate representations

```
InfoTree ──▶ Proof IR ──▶ Presentation IR ──▶ English / LaTeX / interactive
```

* `Distill.Informalizer.IR.Proof`: how the Lean proof was constructed (tactic nodes in
  execution order, the goal graph, the hypothesis table).
* `Distill.Informalizer.IR.Presentation`: the mathematical argument to present
  (`ProofStep`s in presentation order).
* `Distill.Informalizer.IR.Common`: types both use.
-/
