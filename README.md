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
