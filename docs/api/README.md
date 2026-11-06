# API

## Code submissions

`POST /api/submissions` requires an authenticated Clerk session and a JSON body:

```json
{
	"levelSlug": "hello-world",
	"source": "import Distill\ntheorem hello_world : hello = \"world\" := rfl\n"
}
```

The server looks up the published level by slug and uses its trusted verification
configuration. The client cannot choose the challenge, theorem name, or permitted
axioms. Missing or unpublished levels return 404. Existing levels without a valid
verification configuration return 503; there is no compilation-only acceptance path.

### Level configuration

Level authors must store a `verification` field on each submittable level:

```json
{
	"verification": {
		"theoremName": "hello_world",
		"challengeSource": "import Distill\ntheorem hello_world : hello = \"world\" := by sorry\n"
	}
}
```

`challengeSource` is a complete, trusted Lean module specifying the target theorem,
its binders, namespaces, and supporting definitions/imports. Use canonical fully
qualified names such as `Exercise.hello_world` in `theoremName`. The challenge must
define that name as a theorem. Its proof may contain `sorry`; challenge warnings do
not reject a submission. Do not derive this configuration from submitted code or
editable starter code. The level page loader does not send this field to the browser.
`statement` and `expectedGoal` remain display fields, not verification specifications.

### Results

HTTP 200 returns a verification result for both accepted and rejected submissions:

```json
{
	"accepted": true,
	"compiled": true,
	"reason": "accepted",
	"diagnostics": [],
	"verification": {
		"theoremName": "hello_world",
		"dependencies": ["hello", "Eq.refl", "Eq", "String"],
		"axioms": [],
		"introducedAxioms": []
	}
}
```

The dependency list is illustrative; its contents depend on the elaborated proof.
`accepted` is the authoritative verdict. `compiled` only means the compiler exited
successfully. Acceptance requires all of the following:

- No Lean errors or warnings anywhere in the submitted module. Informational
  messages and ordinary `#eval` text do not reject a submission. Malformed
  JSON-like compiler output fails closed rather than silently hiding diagnostics.
- The required name exists and is a theorem with exactly the challenge's type,
  including its binders and universe parameters.
- Lean 4.35.0's `lake comparator` confirms that the definitions behind the target
  statement match the challenge, that the proof uses only `propext`, `Quot.sound`,
  and `Classical.choice`, and that independent kernel replay accepts the export.
- No new axiom declarations appear relative to the challenge's trusted environment,
  even when unused. Existing imported axioms do not grant permission to use them in
  the proof: comparator still enforces the three-axiom allowlist. Suppressing a
  `sorry` warning therefore cannot make a proof using `sorryAx` acceptable.

Rejection reasons are `diagnostics`, `missing_theorem`, `introduced_axioms`, or
`verification_failed`. Verification details are `null` when compilation or export
prevents inspection. Otherwise they include transitive proof dependencies, used
axioms, and newly introduced axioms. A comparator rejection also has a `message`.
These details are explanatory; they never override `accepted`.

Diagnostics use Lean's JSON output, with severity `error`, `warning`, or
`information`, a `message`, and optional `fileName`, `position`, and `endPosition`:

```json
{
	"severity": "warning",
	"message": "declaration uses `sorry`",
	"fileName": "/submission/Solution.lean",
	"position": { "line": 2, "column": 8 },
	"endPosition": { "line": 2, "column": 19 }
}
```

Lines are one-based and columns are zero-based, as emitted by Lean. Source locations
refer to the submitted module without prepended server code. Raw stdout is not a
verification protocol and is not returned by this endpoint. Results are not cached.

Invalid input returns 400, missing authentication 401, bodies over 256 KiB 413,
and unsupported content types 415. Service failures (including sandbox startup,
missing helper/toolchain, timeout, or output limit) return a generic 503. An invalid
trusted challenge is a configuration/service error, not a rejected user proof.
When all worker slots are occupied, the API returns 503 with `Retry-After: 1`.

### Runtime and isolation

Use Node 24, Linux, [elan](https://github.com/leanprover/elan), and Bubblewrap 0.8+
(`bwrap` on PATH), with unprivileged user namespaces enabled. Install Bubblewrap
with `sudo apt-get install bubblewrap` on Ubuntu/Debian. In `lean/`, run `lake build`
to build the trusted imports and `distill-verifier` helper with the pinned Lean
4.35.0 toolchain. Start the app from the repository root, or set `LEAN_PROJECT_DIR`
to the absolute project directory. On macOS/Windows, run the backend in a Linux VM
or WSL2. The backend requires a Node host and cannot run on an edge runtime.

The service resolves only the trusted project with `lake env`. It compiles and
exports the challenge before running submitted code. Challenge and solution have
separate read-only input mounts and writable scratch directories. Compilation,
export, and inspection each use fresh Bubblewrap processes with isolated network,
PID, IPC, and user namespaces, no capabilities, and a clean environment. Only the
trusted toolchain, prebuilt import paths, system libraries, and that stage's inputs
are mounted. The app source, credentials, home directory, and host sockets are absent.

User-produced `.olean` files are loaded only inside the export sandbox. Only bounded,
inert NDJSON exports cross into the trusted comparator. Export includes all axiom
declarations as well as the theorem's dependencies and comparator's kernel primitives.
The dependency inspector reads these exports in another fresh sandbox. Comparator
uses `--challenge-from-export` and `--solution-from-export`, then runs its kernel
checker in its own Bubblewrap sandbox. It never builds the submitted code or loads
user-produced `.olean` files in the process deciding acceptance. There is no
unsandboxed fallback.

### Resource limits

Every submission runs in a transient systemd **user service** containing a trusted
Node worker and all of its Lean, export, inspection, and comparator descendants.
The policy is defined in `src/lib/server/leanLimits.ts`; clients cannot change it.

| Resource                     | Limit                                                                   |
| ---------------------------- | ----------------------------------------------------------------------- |
| Entire job                   | 30 seconds, including toolchain discovery and all verification stages   |
| CPU                          | 100% of one CPU, shared across the worker and its descendants           |
| Memory                       | 1 GiB total; swap disabled                                              |
| Processes and threads        | 64 total                                                                |
| Submission scratch/artifacts | One private 128 MiB tmpfs, at most 8,192 inodes                         |
| Concurrent jobs              | 4 per application process; excess requests are rejected without queuing |
| Compiler output              | 1 MiB combined stdout/stderr per stage; exports allow 32 MiB            |
| Worker response              | 8 MiB maximum, including JSON encoding                                  |

The CPU quota is a rate limit; the shared wall-clock deadline bounds total CPU
consumption. Memory and task limits apply to the complete process tree, including
children that create new sessions. A worker OOM kills its whole unit. Cancellation,
deadline expiry, and excessive output stop the unit before releasing its admission
slot. systemd also enforces the deadline if the web server exits. The private tmpfs
is discarded with the unit, including after forced termination. Compiler `/tmp`
and `/work` directories are bound from that filesystem rather than separately
allocating unbounded scratch filesystems. All descendants also share the memory cap.

These are **per-job** budgets. With four jobs, provision up to 4 GiB plus the web
server and host overhead. Multiple app processes/replicas each have their own four
slots; size deployment-wide capacity accordingly. The limit applies to the Lean
job, not to time spent receiving HTTP input or looking up the level in MongoDB.

The host must provide systemd 254+, a running user manager, cgroup v2 with `cpu`,
`memory`, and `pids` delegated to it, and unprivileged user/mount namespaces.
`/usr/bin/systemd-run`, `/usr/bin/systemctl`, and `/usr/bin/env` must be installed.
For a persistent service account, an administrator can enable its user manager:

```sh
sudo loginctl enable-linger distill
```

If the controllers are not already delegated, configure the account's
`user@<uid>.service` with a `[Service]` drop-in containing
`Delegate=cpu memory pids`, reload systemd, and restart that user manager during
deployment. The app must run as that same user and have access to its session bus
(`XDG_RUNTIME_DIR=/run/user/<uid>` and
`DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<uid>/bus`). CI sets these up explicitly.
Before processing source, each worker checks the actual cgroup limits and tmpfs
capacity; missing controllers, failed namespaces, or missing systemd return 503.

`npm run dev`, `npm run build`, and `npm run test:submissions` build the worker using
`worker/tsconfig.json`. Deploy `dist/lean-worker/` alongside the app and the prebuilt
Lean project, and start the app from the repository root. Rebuild with
`npm run build:worker` after changing worker code during development. A missing
worker build is a service failure. The worker receives only the toolchain environment,
not application credentials.

See systemd's [resource controls](https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html)
and [filesystem isolation](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html)
for the host prerequisites. Persistence of attempts/completion is outside this verifier.

Verification is independent of the editor's WebSocket relay; the relay need not be
running. The local-only `lake serve` relay still runs outside this sandbox.

Run `npm run test:submissions` against real Lean, Bubblewrap, and systemd to test sandbox
isolation, diagnostics, exact theorem and environment checks, used/unused axioms,
forged proofs, memory/process/scratch exhaustion, shared deadlines, cancellation,
admission control, concurrent isolation, cleanup, and API validation.
