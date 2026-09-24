import { mkdir } from "node:fs/promises";
import path from "node:path";
import { PGlite } from "@electric-sql/pglite";
import type { PgDatabase, PgQueryResultHKT } from "drizzle-orm/pg-core";
import { drizzle as drizzleNodePg } from "drizzle-orm/node-postgres";
import { drizzle as drizzlePglite } from "drizzle-orm/pglite";
import { migrate as migratePglite } from "drizzle-orm/pglite/migrator";
import { Pool } from "pg";
import * as schema from "./schema";

/**
 * Works with either driver: a hosted Postgres when DATABASE_URL is set
 * (production), otherwise an embedded PGlite database stored in ./.data
 * so the app runs locally with no database server.
 */
export type Database = PgDatabase<PgQueryResultHKT, typeof schema>;

const MIGRATIONS_FOLDER = path.join(process.cwd(), "drizzle");

/** Opens a PGlite database (in memory when no directory is given) and applies migrations. */
export async function openPgliteDatabase(dataDir?: string): Promise<Database> {
  if (dataDir) await mkdir(dataDir, { recursive: true });
  const client = new PGlite(dataDir);
  const db = drizzlePglite(client, { schema });
  await migratePglite(db, { migrationsFolder: MIGRATIONS_FOLDER });
  return db;
}

export function openPostgresDatabase(connectionString: string): Database {
  return drizzleNodePg(new Pool({ connectionString }), { schema });
}

declare global {
  // Reused across hot reloads in development so PGlite is only opened once.
  var __cohostLedgerDb: Promise<Database> | undefined;
}

export function getDb(): Promise<Database> {
  globalThis.__cohostLedgerDb ??= createDatabase().catch((error: unknown) => {
    globalThis.__cohostLedgerDb = undefined;
    throw error;
  });
  return globalThis.__cohostLedgerDb;
}

async function createDatabase(): Promise<Database> {
  const url = process.env.DATABASE_URL;
  if (url) return openPostgresDatabase(url);
  return openPgliteDatabase(process.env.PGLITE_DATA_DIR ?? path.join(process.cwd(), ".data", "pglite"));
}
