# LeanEditor

`LeanEditor.svelte` provides the reusable CodeMirror editor and owns its Lean connection.
Use `bind:value` for the source text and the optional `onstatus` and `ondiagnostics` callbacks
for runtime results. Parent-driven changes to `value` update both the editor and the Lean document.

Set `--lean-editor-height` on a parent to override the default 400px editing height. Inside a
fixed-height flex column, the editor instead grows or shrinks to fill the available space.

# LevelLayout

`LevelLayout.svelte` is the page structure shared by every level mode (see the #11 wireframes in
`docs/wireframes`). It renders the top bar with the level title plus three columns, and each
mode fills the regions with snippets:

| Snippet       | Region                                                        |
| ------------- | ------------------------------------------------------------- |
| `toolbar`     | Right side of the top bar (save status, hints button)         |
| `help`        | Question-mark help in the top bar                             |
| `goal`        | Left column, under "Your goal"                                |
| `brief`       | Left column, below the goal (proof to translate, description) |
| `editor`      | Middle column                                                 |
| `actions`     | Under the editor (Check proof, Reset code)                    |
| `output`      | Middle column, under "Lean output"                            |
| `translation` | Right column, under "Live English translation"                |

The columns and the editor/output split are resizable with `ResizeHandle.svelte` (drag, or focus a
handle and use the arrow keys). Hovering a section shows a grip icon on each edge it can be resized
from. Vertical panes never shrink past their title bar.

`goal`, `editor` and `output` are required. Headings rendered inside `brief` pick up the panel
heading style.

# ProofCheckStatus

`ProofCheckStatus.svelte` shows where a "Check proof" request is (#57): waiting for a free Lean
worker, checking (with a seconds counter), accepted, rejected with the reason, or an error. It
renders nothing while idle. Pair it with `createProofChecker` from `src/lib/levels/proofCheck.ts`,
which calls `POST /api/submissions`, retries while Lean is busy (503 with `Retry-After`), and
cancels an older check when a new one starts:

```svelte
<script lang="ts">
	import ProofCheckStatus from '$lib/components/ProofCheckStatus.svelte';
	import { createProofChecker, type ProofCheckState } from '$lib/levels/proofCheck';

	let check = $state<ProofCheckState>({ kind: 'idle' });
	const checker = createProofChecker({ onstate: (next) => (check = next) });
</script>

<button
	class="button primary"
	type="button"
	disabled={check.kind === 'waiting' || check.kind === 'running'}
	onclick={() => checker.check(data.level.slug, code)}
>
	Check proof
</button>
<ProofCheckStatus {check} />
```

`check()` resolves with the final state, so a page can react to an accepted proof (for example,
open the post-completion dialog).

The level page wires this into `LevelLayout`'s `actions` snippet (#56). It submits the current
editor text and level slug, and disables the button while checking, loading another level, or
the editor is empty. It calls `checker.cancel()` when the text or level changes and on page
destruction, so pending retries stop and a verdict never refers to an older proof.
