import { connection } from "next/server";
import { getDb, type Database } from "./db/client";
import type { Workspace } from "./db/schema";
import { ensureWorkspace } from "./workspace";

export interface AppContext {
  db: Database;
  workspace: Workspace;
}

/**
 * Entry point for every page, route and server action that touches data.
 * It opts the request out of static prerendering and resolves the current
 * workspace; when sign-in is added, this is where the session is checked.
 */
export async function getAppContext(): Promise<AppContext> {
  await connection();
  const db = await getDb();
  return { db, workspace: await ensureWorkspace(db) };
}
