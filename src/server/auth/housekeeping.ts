import { and, isNotNull, lt, or } from "drizzle-orm";
import type { Database } from "../db/client";
import { authTokens, rateLimitHits, sessions } from "../db/schema";

const DAY_MS = 24 * 60 * 60 * 1000;

/** Deletes expired sessions, spent reset tokens and old rate-limit hits. */
export async function cleanUpAuthTables(db: Database, now = new Date()): Promise<void> {
  const dayAgo = new Date(now.getTime() - DAY_MS);
  await db.delete(sessions).where(lt(sessions.expiresAt, now));
  await db.delete(authTokens).where(or(lt(authTokens.expiresAt, dayAgo), and(isNotNull(authTokens.usedAt), lt(authTokens.usedAt, dayAgo))));
  await db.delete(rateLimitHits).where(lt(rateLimitHits.createdAt, dayAgo));
}

/** Runs the clean-up on a small share of sign-ins, so no scheduler is needed. */
export async function maybeCleanUpAuthTables(db: Database, probability = 0.02): Promise<void> {
  if (Math.random() < probability) await cleanUpAuthTables(db);
}
