import { eq, lt } from "drizzle-orm";
import type { Database } from "../db/client";
import { sessions, users, workspaces, type Session, type User, type Workspace } from "../db/schema";
import { generateToken, hashToken } from "./crypto";

export const SESSION_DURATION_MS = 30 * 24 * 60 * 60 * 1000;
/** Sessions used within this window of their expiry are extended by a full duration. */
const RENEW_WITHIN_MS = 15 * 24 * 60 * 60 * 1000;

export interface SessionContext {
  session: Session;
  user: User;
  workspace: Workspace;
}

export async function createSession(db: Database, userId: string, now = new Date()): Promise<{ token: string; expiresAt: Date }> {
  const token = generateToken();
  const expiresAt = new Date(now.getTime() + SESSION_DURATION_MS);
  await db.insert(sessions).values({ id: hashToken(token), userId, expiresAt });
  return { token, expiresAt };
}

/** Resolves a session cookie value to its user and workspace, renewing or deleting the session as needed. */
export async function validateSessionToken(db: Database, token: string, now = new Date()): Promise<SessionContext | null> {
  if (!token || token.length > 200) return null;
  const [row] = await db
    .select({ session: sessions, user: users, workspace: workspaces })
    .from(sessions)
    .innerJoin(users, eq(users.id, sessions.userId))
    .innerJoin(workspaces, eq(workspaces.id, users.workspaceId))
    .where(eq(sessions.id, hashToken(token)));
  if (!row) return null;

  if (now >= row.session.expiresAt) {
    await db.delete(sessions).where(eq(sessions.id, row.session.id));
    return null;
  }
  if (row.session.expiresAt.getTime() - now.getTime() < RENEW_WITHIN_MS) {
    const expiresAt = new Date(now.getTime() + SESSION_DURATION_MS);
    await db.update(sessions).set({ expiresAt }).where(eq(sessions.id, row.session.id));
    row.session = { ...row.session, expiresAt };
  }
  return row;
}

export async function invalidateSession(db: Database, token: string): Promise<void> {
  await db.delete(sessions).where(eq(sessions.id, hashToken(token)));
}

export async function invalidateUserSessions(db: Database, userId: string): Promise<void> {
  await db.delete(sessions).where(eq(sessions.userId, userId));
}

export async function deleteExpiredSessions(db: Database, now = new Date()): Promise<void> {
  await db.delete(sessions).where(lt(sessions.expiresAt, now));
}
