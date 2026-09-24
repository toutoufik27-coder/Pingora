<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->

# Project notes

CoHost Ledger turns Airbnb transaction exports into monthly owner statements for co-hosts. See README.md.

- Checks: `npm test`, `npm run typecheck`, `npm run lint`, `npm run build`. Run all four before committing.
- Pure domain logic lives in `src/lib` and must stay free of database and Next.js imports so it can be unit-tested.
- Data access lives in `src/server`; every query is scoped by `workspaceId`. Pages, routes and server actions get the
  database and workspace from `getAppContext()` in `src/server/context.ts` (the place to add sign-in later).
- Money is integer cents (`src/lib/money.ts`), dates are ISO `YYYY-MM-DD` strings, months are `YYYY-MM`.
- Schema changes: edit `src/server/db/schema.ts`, then `npm run db:generate` to add a migration under `drizzle/`.
- `src/server/db/schema.ts` uses relative imports because drizzle-kit does not resolve the `@/` alias.
