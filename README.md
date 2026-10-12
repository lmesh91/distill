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

Use `npm run check` for Svelte and TypeScript checks, and `npm run build` for a production build.

## Lean

Proofs are checked with the Lake project in `lean/`, which pins the Lean version in `lean/lean-toolchain`. Install [elan](https://github.com/leanprover/elan) so that `lake` is on your PATH, and use Node 24.

The browser talks to Lean's language server through a WebSocket relay, which starts `lake serve` in `lean/` for each connection and forwards messages in both directions. The dev server proxies `/lean` to the relay, so run it alongside `npm run dev`:

```sh
npm run relay
```

Then open `/app/lean` to try it. `npm run test:relay` checks the relay against a real Lean server.
