# API

## Code submissions

`POST /api/submissions` accepts an authenticated Clerk session and a JSON body:

```json
{ "source": "import Distill\nexample : hello = \"world\" := rfl\n" }
```

Each submission starts a fresh `lake env lean --stdin` compiler in `lean/`. It uses
the pinned toolchain and project imports independently of the editor's WebSocket
relay; the relay does not need to be running. Run `lake build Distill` from `lean/`
before submitting code to build the project's imports. Start the app from the
repository root, or export `LEAN_PROJECT_DIR` in the server's process environment
with the absolute project directory.

The endpoint waits for compilation and returns HTTP 200 for both successful and
failed compilations:

```json
{ "compiled": true, "exitCode": 0, "stdout": "", "stderr": "" }
```

Compiler output is preserved as text; source locations refer to `<stdin>`.
`compiled` means Lean exited successfully, not that the proof meets a level's
requirements. Lean warnings (including `sorry`) remain in the output. Structured
diagnostics and proof acceptance rules are tracked in #78–#85.

Invalid input returns 400, missing authentication 401, bodies over 256 KiB 413,
and unsupported content types 415. A runtime failure returns 503. The compiler
has basic guards of 30 seconds and 1 MiB of combined output.

Lean can execute arbitrary code during compilation. This service runs with the
server's permissions and is only suitable for trusted development submissions
until the isolated execution and resource controls in #76/#77 are implemented.
It requires a Node host with Lean/Lake installed; it cannot run on an edge runtime.

Run `npm run test:submissions` to test the service and API handler against real Lean,
including project imports, invalid proofs, warnings, and concurrent submissions.
