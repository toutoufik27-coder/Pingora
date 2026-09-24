import { randomUUID } from "node:crypto";
import { and, eq, gt, isNull } from "drizzle-orm";
import type { Database } from "../db/client";
import { authTokens, users, workspaces, type User } from "../db/schema";
import { createWorkspace } from "../workspace";
import { generateToken, hashPassword, hashToken, verifyPassword } from "./crypto";
import { invalidateUserSessions } from "./sessions";

export const PASSWORD_MIN_LENGTH = 10;
const RESET_TOKEN_TTL_MS = 60 * 60 * 1000;

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

/** Checked when no user matches, so a failed login takes as long whether or not the email exists. */
let dummyHash: Promise<string> | undefined;

export interface SignUpInput {
  name: string;
  email: string;
  password: string;
  businessName: string;
}

export async function signUp(db: Database, input: SignUpInput, now = new Date()): Promise<User | "email_taken"> {
  const email = normalizeEmail(input.email);
  const [existing] = await db.select({ id: users.id }).from(users).where(eq(users.email, email));
  if (existing) return "email_taken";

  const passwordHash = await hashPassword(input.password);
  const workspace = await createWorkspace(db, input.businessName, now);
  try {
    const [user] = await db
      .insert(users)
      .values({ id: randomUUID(), workspaceId: workspace.id, email, name: input.name, passwordHash })
      .returning();
    return user;
  } catch (error) {
    // Lost a race with a sign-up for the same email.
    await db.delete(workspaces).where(eq(workspaces.id, workspace.id));
    const [raced] = await db.select({ id: users.id }).from(users).where(eq(users.email, email));
    if (raced) return "email_taken";
    throw error;
  }
}

export async function authenticate(db: Database, email: string, password: string): Promise<User | null> {
  const [user] = await db.select().from(users).where(eq(users.email, normalizeEmail(email)));
  if (!user) {
    dummyHash ??= hashPassword("not-a-real-password");
    await verifyPassword(password, await dummyHash);
    return null;
  }
  return (await verifyPassword(password, user.passwordHash)) ? user : null;
}

export async function getUserByEmail(db: Database, email: string): Promise<User | null> {
  const [user] = await db.select().from(users).where(eq(users.email, normalizeEmail(email)));
  return user ?? null;
}

/** Issues a one-hour reset token. Returns null when no account uses this email. */
export async function createPasswordResetToken(
  db: Database,
  email: string,
  now = new Date(),
): Promise<{ token: string; user: User } | null> {
  const user = await getUserByEmail(db, email);
  if (!user) return null;
  const token = generateToken();
  await db.insert(authTokens).values({
    id: hashToken(token),
    userId: user.id,
    purpose: "password_reset",
    expiresAt: new Date(now.getTime() + RESET_TOKEN_TTL_MS),
  });
  return { token, user };
}

export async function isPasswordResetTokenValid(db: Database, token: string, now = new Date()): Promise<boolean> {
  const [row] = await db
    .select({ id: authTokens.id })
    .from(authTokens)
    .where(
      and(
        eq(authTokens.id, hashToken(token)),
        eq(authTokens.purpose, "password_reset"),
        isNull(authTokens.usedAt),
        gt(authTokens.expiresAt, now),
      ),
    );
  return !!row;
}

/** Sets a new password with a reset token, signing the user out everywhere. */
export async function resetPassword(db: Database, token: string, newPassword: string, now = new Date()): Promise<User | null> {
  const [claimed] = await db
    .update(authTokens)
    .set({ usedAt: now })
    .where(
      and(
        eq(authTokens.id, hashToken(token)),
        eq(authTokens.purpose, "password_reset"),
        isNull(authTokens.usedAt),
        gt(authTokens.expiresAt, now),
      ),
    )
    .returning({ userId: authTokens.userId });
  if (!claimed) return null;
  const [user] = await db
    .update(users)
    .set({ passwordHash: await hashPassword(newPassword) })
    .where(eq(users.id, claimed.userId))
    .returning();
  await invalidateUserSessions(db, user.id);
  return user;
}

export async function changePassword(db: Database, userId: string, currentPassword: string, newPassword: string): Promise<boolean> {
  const [user] = await db.select().from(users).where(eq(users.id, userId));
  if (!user || !(await verifyPassword(currentPassword, user.passwordHash))) return false;
  await db.update(users).set({ passwordHash: await hashPassword(newPassword) }).where(eq(users.id, userId));
  await invalidateUserSessions(db, userId);
  return true;
}

export async function updateProfile(
  db: Database,
  userId: string,
  input: { name: string; email: string },
): Promise<"ok" | "email_taken"> {
  const email = normalizeEmail(input.email);
  const [other] = await db.select({ id: users.id }).from(users).where(eq(users.email, email));
  if (other && other.id !== userId) return "email_taken";
  await db.update(users).set({ name: input.name, email }).where(eq(users.id, userId));
  return "ok";
}

/** Deletes the user's workspace and everything in it (owners, bookings, statements, sessions). */
export async function deleteAccount(db: Database, userId: string, password: string): Promise<boolean> {
  const [user] = await db.select().from(users).where(eq(users.id, userId));
  if (!user || !(await verifyPassword(password, user.passwordHash))) return false;
  await db.delete(workspaces).where(eq(workspaces.id, user.workspaceId));
  return true;
}
