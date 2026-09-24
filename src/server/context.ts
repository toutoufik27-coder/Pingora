import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { cache } from "react";
import { hasAccess } from "@/lib/billing";
import { SESSION_COOKIE, sessionCookieOptions } from "./auth/cookie";
import { validateSessionToken, type SessionContext } from "./auth/sessions";
import { getDb, type Database } from "./db/client";
import type { User, Workspace } from "./db/schema";
import { appUrl, isBillingEnabled } from "./env";

export interface AppContext {
  db: Database;
  user: User;
  workspace: Workspace;
}

/** The signed-in user for this request, or null. Deduplicated per request. */
export const getSession = cache(async (): Promise<(SessionContext & { db: Database; token: string }) | null> => {
  const token = (await cookies()).get(SESSION_COOKIE)?.value;
  if (!token) return null;
  const db = await getDb();
  const context = await validateSessionToken(db, token);
  return context ? { ...context, db, token } : null;
});

export function workspaceHasAccess(workspace: Workspace, now = new Date()): boolean {
  return hasAccess(workspace, now, isBillingEnabled());
}

/**
 * Entry point for every app page, route and server action that touches data:
 * requires a signed-in user and, unless `allowInactive`, an active trial or
 * subscription. Everything returned is scoped to the user's workspace.
 */
export async function getAppContext(options: { allowInactive?: boolean } = {}): Promise<AppContext> {
  const session = await getSession();
  if (!session) redirect("/login");
  if (!options.allowInactive && !workspaceHasAccess(session.workspace)) redirect("/billing");
  return { db: session.db, user: session.user, workspace: session.workspace };
}

export async function setSessionCookie(token: string): Promise<void> {
  (await cookies()).set(SESSION_COOKIE, token, sessionCookieOptions(appUrl()));
}

export async function clearSessionCookie(): Promise<void> {
  (await cookies()).set(SESSION_COOKIE, "", { ...sessionCookieOptions(appUrl()), maxAge: 0 });
}

/** Only same-site relative paths are followed after sign-in. */
export function safeNextPath(next: string | null | undefined, fallback = "/dashboard"): string {
  if (!next || !next.startsWith("/") || next.startsWith("//") || next.startsWith("/\\")) return fallback;
  return next;
}
