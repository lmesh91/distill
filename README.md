# Distill

![Distill](assets/distill.png)

Distill is a learning software that teaches people how to write proofs in Lean. This is done via interactive exercises that task users with translating an existing proof or solving a proof-based mathematics problem in Lean. Any code written is automatically translated into English to aid in the learning process and give users a better grasp of how Lean's tactics work.

Note that Distill is currently in the early stages of development. Expect incomplete features and many bugs as we work on building this software!

## Development

Distill is a full-stack SvelteKit application. Its pages and server endpoints live together in `src/routes`.

Copy `.env.example` to `.env`, provide the Clerk and MongoDB values, then run:

```sh
npm install
npm run dev
```

### Clerk webhooks

Clerk notifies the app when users are created, updated, or deleted by sending webhooks to `/api/webhooks/clerk`, which keeps the `users` collection in MongoDB in sync. Clerk can't reach `localhost`, so during development you must keep an [ngrok](https://ngrok.com) tunnel running alongside `npm run dev`:

```sh
ngrok http 5173 --url=https://<your-dev-domain>.ngrok-free.app
```

In the Clerk dashboard (development instance), add a webhook endpoint at `https://<your-dev-domain>.ngrok-free.app/api/webhooks/clerk` subscribed to `user.created`, `user.updated`, and `user.deleted`, and put its signing secret in `.env` as `CLERK_WEBHOOK_SIGNING_SECRET`. If the tunnel isn't running, sign-ups still succeed in Clerk but no MongoDB user is created; failed deliveries are retried and can be replayed from the Clerk dashboard.

> **Note:** Once the app is deployed to a real domain, add a separate webhook endpoint at `https://<domain>/api/webhooks/clerk` in the **production** Clerk instance and set its signing secret as `CLERK_WEBHOOK_SIGNING_SECRET` in the production environment.

Use `npm run check` for Svelte and TypeScript checks, and `npm run build` for a production build.

## Lean

Proofs are checked with the Lake project in `lean/`, which pins the Lean version in `lean/lean-toolchain`. Install [elan](https://github.com/leanprover/elan) so that `lake` is on your PATH, and use Node 24.

Submission compilation also requires Linux and [Bubblewrap](https://github.com/containers/bubblewrap)
(`bwrap` on PATH, version 0.8 or newer), with unprivileged user namespaces enabled.
On Ubuntu/Debian, install it with `sudo apt-get install bubblewrap`. Run
`lake build` in `lean/` to build the trusted imports and verification helper. Each submission runs
in an isolated sandbox; there is no unsandboxed fallback. On macOS or Windows,
run the backend in a Linux VM or WSL2 with these prerequisites.

The browser talks to Lean's language server through a WebSocket relay, which starts `lake serve` in `lean/` for each connection and forwards messages in both directions. The dev server proxies `/lean` to the relay, so run it alongside `npm run dev`:

```sh
npm run relay
```

Then open `/app/lean` to try it.

Run `npm run test` to run all tests. This requires Node 24, `lake`, and the Linux
Bubblewrap setup above. The individual tests are as follows:

- `npm run test:relay`: checks connectivity against a Lean server.
- `npm run test:editor`: checks document synchronization, stale-result filtering, and connection cleanup.
- `npm run test:submissions`: check sandbox isolation, structured diagnostics, and proof verification

Submissions use Lean 4.35.0’s `lake comparator` to check the required theorem against a trusted level challenge. Level authors must configure the `verification` field described in the API documentation; existing levels without it return 503 when submitted. Code submissions use a separate HTTP API. See the [API documentation](docs/api/README.md)
for setup, request and response formats, limits, and testing.
