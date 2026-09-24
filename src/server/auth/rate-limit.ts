import { randomUUID } from "node:crypto";
import { and, count, eq, gte, lt } from "drizzle-orm";
import type { Database } from "../db/client";
import { rateLimitHits } from "../db/schema";

/**
 * Fixed-window limiter stored in the database, so it holds across server
 * instances. Records the attempt and reports whether it is within the limit.
 */
export async function consumeRateLimit(
  db: Database,
  key: string,
  limit: number,
  windowMs: number,
  now = new Date(),
): Promise<boolean> {
  const since = new Date(now.getTime() - windowMs);
  const [{ n }] = await db
    .select({ n: count() })
    .from(rateLimitHits)
    .where(and(eq(rateLimitHits.key, key), gte(rateLimitHits.createdAt, since)));
  if (Number(n) >= limit) return false;
  await db.insert(rateLimitHits).values({ id: randomUUID(), key, createdAt: now });
  // Old hits for this key no longer matter.
  await db.delete(rateLimitHits).where(and(eq(rateLimitHits.key, key), lt(rateLimitHits.createdAt, since)));
  return true;
}

export async function resetRateLimit(db: Database, key: string): Promise<void> {
  await db.delete(rateLimitHits).where(eq(rateLimitHits.key, key));
}
