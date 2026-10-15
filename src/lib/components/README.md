# LeanEditor

`LeanEditor.svelte` provides the reusable CodeMirror editor and owns its Lean connection.
Use `bind:value` for the source text and the optional `onstatus` and `ondiagnostics` callbacks
for runtime results. Parent-driven changes to `value` update both the editor and the Lean document.

Set `--lean-editor-height` on a parent to override the default 400px editing height.
