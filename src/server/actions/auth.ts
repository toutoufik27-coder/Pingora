"use server";

import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";
import { failure, success, type ActionState } from "@/lib/action-state";
import { APP_NAME } from "@/lib/brand";
import {
  authenticate,
  createPasswordResetToken,
  normalizeEmail,
  PASSWORD_MIN_LENGTH,
  resetPassword,
  signUp,
} from "../auth/accounts";
import { SESSION_COOKIE } from "../auth/cookie";
import { maybeCleanUpAuthTables } from "../auth/housekeeping";
import { consumeRateLimit, resetRateLimit } from "../auth/rate-limit";
import { createSession, invalidateSession } from "../auth/sessions";
import { clearSessionCookie, safeNextPath, setSessionCookie } from "../context";
import { getDb } from "../db/client";
import { emailHtml, sendEmail } from "../email";
import { appUrl } from "../env";
import { firstIssue, readFields } from "./fields";

const MINUTE = 60 * 1000;

async function clientIp(): Promise<string> {
  const h = await headers();
  return h.get("x-forwarded-for")?.split(",")[0]?.trim() || h.get("x-real-ip") || "unknown";
}

const email = z
  .string()
  .trim()
  .max(320)
  .refine((v) => z.email().safeParse(v).success, "Enter a valid email address.");
const newPassword = z
  .string()
  .min(PASSWORD_MIN_LENGTH, `Use at least ${PASSWORD_MIN_LENGTH} characters for your password.`)
  .max(200, "That password is too long.");

const signUpSchema = z.object({
  name: z.string().trim().min(1, "Enter your name.").max(200),
  businessName: z.string().trim().min(1, "Enter your business name.").max(200),
  email,
  password: newPassword,
  terms: z.literal("on", "Please accept the terms of service and privacy policy."),
});

export async function signUpAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const parsed = signUpSchema.safeParse(readFields(formData, ["name", "businessName", "email", "password", "terms"]));
  if (!parsed.success) return failure(firstIssue(parsed.error));
  const db = await getDb();
  if (!(await consumeRateLimit(db, `signup:${await clientIp()}`, 10, 60 * MINUTE))) {
    return failure("Too many sign-ups from your network. Try again in an hour.");
  }
  const user = await signUp(db, parsed.data);
  if (user === "email_taken") return failure("An account already uses this email. Log in instead.");
  const { token } = await createSession(db, user.id);
  await setSessionCookie(token);
  redirect("/dashboard");
}

const logInSchema = z.object({ email, password: z.string().min(1, "Enter your password.").max(200), next: z.string().max(500) });

export async function logInAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const parsed = logInSchema.safeParse(readFields(formData, ["email", "password", "next"]));
  if (!parsed.success) return failure(firstIssue(parsed.error));
  const db = await getDb();
  const emailKey = `login:${normalizeEmail(parsed.data.email)}`;
  const allowed =
    (await consumeRateLimit(db, `login-ip:${await clientIp()}`, 50, 15 * MINUTE)) &&
    (await consumeRateLimit(db, emailKey, 10, 15 * MINUTE));
  if (!allowed) return failure("Too many attempts. Wait 15 minutes or reset your password.");

  const user = await authenticate(db, parsed.data.email, parsed.data.password);
  if (!user) return failure("Wrong email or password.");
  await resetRateLimit(db, emailKey);
  await maybeCleanUpAuthTables(db);
  const { token } = await createSession(db, user.id);
  await setSessionCookie(token);
  redirect(safeNextPath(parsed.data.next));
}

export async function logOutAction(): Promise<void> {
  const token = (await cookies()).get(SESSION_COOKIE)?.value;
  if (token) await invalidateSession(await getDb(), token);
  await clearSessionCookie();
  redirect("/login");
}

export async function requestPasswordResetAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const parsed = z.object({ email }).safeParse(readFields(formData, ["email"]));
  if (!parsed.success) return failure(firstIssue(parsed.error));
  const db = await getDb();
  const allowed =
    (await consumeRateLimit(db, `reset-ip:${await clientIp()}`, 20, 60 * MINUTE)) &&
    (await consumeRateLimit(db, `reset:${normalizeEmail(parsed.data.email)}`, 3, 60 * MINUTE));
  // Same answer whether or not the account exists, so emails can't be probed.
  const done = success("If an account uses that email, a reset link is on its way. It expires in one hour.");
  if (!allowed) return done;

  const issued = await createPasswordResetToken(db, parsed.data.email);
  if (issued) {
    const link = `${appUrl()}/reset-password?token=${encodeURIComponent(issued.token)}`;
    await sendEmail({
      to: issued.user.email,
      subject: `Reset your ${APP_NAME} password`,
      text: `Hi ${issued.user.name},\n\nUse this link to choose a new password (valid for one hour):\n${link}\n\nIf you didn't ask for this, you can ignore this email.`,
      html: emailHtml(
        [`Hi ${issued.user.name},`, "Use the button below to choose a new password. The link is valid for one hour.", "If you didn't ask for this, you can ignore this email."],
        { label: "Choose a new password", url: link },
      ),
    });
  }
  return done;
}

const resetSchema = z
  .object({ token: z.string().min(1).max(200), password: newPassword, confirm: z.string() })
  .refine((v) => v.password === v.confirm, "The two passwords don't match.");

export async function resetPasswordAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const parsed = resetSchema.safeParse(readFields(formData, ["token", "password", "confirm"]));
  if (!parsed.success) return failure(firstIssue(parsed.error));
  const db = await getDb();
  const user = await resetPassword(db, parsed.data.token, parsed.data.password);
  if (!user) return failure("This reset link has expired or was already used. Ask for a new one.");
  const { token } = await createSession(db, user.id);
  await setSessionCookie(token);
  redirect("/dashboard");
}
