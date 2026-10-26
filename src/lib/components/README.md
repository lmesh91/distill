# LeanEditor

`LeanEditor.svelte` provides the reusable CodeMirror editor and owns its Lean connection.
Use `bind:value` for the source text and the optional `onstatus` and `ondiagnostics` callbacks
for runtime results. Parent-driven changes to `value` update both the editor and the Lean document.

Set `--lean-editor-height` on a parent to override the default 400px editing height. Inside a
fixed-height flex column, the editor instead grows or shrinks to fill the available space.

# LevelLayout

`LevelLayout.svelte` is the page structure shared by every level mode (see the #11 wireframes in
`docs/wireframes`). It renders the top bar from `title` and `mode` plus three columns, and each
mode fills the regions with snippets:

| Snippet       | Region                                                        |
| ------------- | ------------------------------------------------------------- |
| `toolbar`     | Right side of the top bar (save status, hints button)         |
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
