import { defineConfig } from "drizzle-kit";

// `npm run db:generate` turns changes in the schema into SQL migrations under ./drizzle.
// Migrations are applied automatically for the local PGlite database and with
// `npm run db:migrate` for a hosted Postgres database (DATABASE_URL).
export default defineConfig({
  dialect: "postgresql",
  schema: "./src/server/db/schema.ts",
  out: "./drizzle",
});
