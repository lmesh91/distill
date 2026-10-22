# API

## Code submissions

`POST /api/submissions` accepts an authenticated Clerk session and a JSON body:

```json
{ "source": "import Distill\nexample : hello = \"world\" := rfl\n" }
```

Each submission starts a fresh `lean --stdin` compiler inside a Linux Bubblewrap
sandbox. The server uses `lake env` on the trusted project to resolve the pinned
toolchain and prebuilt imports; submitted code is only sent to the sandboxed
compiler. This runs independently of the editor's WebSocket relay; the relay does
not need to be running. Run `lake build Distill` from `lean/`
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

Lean can execute arbitrary code during compilation, including through `#eval`,
macros, and elaborators. Each submission therefore gets fresh temporary `/work`
and `/tmp` filesystems, isolated network/PID/IPC/user namespaces, no capabilities,
and a clean environment. Only the trusted Lean toolchain, compiled import paths,
and system library directories (`/usr/lib`, `/usr/lib64`, `/lib`, `/lib64`) are
mounted from the host, all read-only. Keep these dependencies free of secrets.
The app source, credentials, home directory, and host sockets are not mounted.
The compiler's descendants and temporary files are discarded when it exits,
fails, or is killed by the timeout/output guard.

The backend requires Linux, Node, Lean/Lake, and Bubblewrap 0.8+ (`bwrap` on PATH),
with unprivileged user namespaces permitted by the host/container security policy.
Install Bubblewrap with `sudo apt-get install bubblewrap` on Ubuntu/Debian. A
missing sandbox executable or namespace/mount failure returns 503; the service
never retries compilation outside the sandbox. It cannot run on an edge runtime.

This isolates submissions using the host kernel; comprehensive CPU, memory,
process-count, and scratch-space quotas/admission control remain tracked in #77.
The editor's local-only `lake serve` relay still runs outside this sandbox; do not
expose that relay to untrusted clients.

Run `npm run test:submissions` to test the service and API handler against real Lean,
including project imports, invalid proofs, warnings, concurrent scratch files,
blocked host file/credential access, read-only dependencies, network isolation,
child-process cleanup, and fail-closed sandbox startup.
