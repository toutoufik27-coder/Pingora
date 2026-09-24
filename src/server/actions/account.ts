"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { failure, success, type ActionState } from "@/lib/action-state";
import { changePassword, deleteAccount, PASSWORD_MIN_LENGTH, updateProfile } from "../auth/accounts";
import { verifyPassword } from "../auth/crypto";
import { createSession } from "../auth/sessions";
import { cancelSubscription, createCheckoutUrl } from "../billing";
import { clearSessionCookie, getAppContext, setSessionCookie } from "../context";
import { isBillingEnabled } from "../env";
import { firstIssue, readFields } from "./fields";

const profileSchema = z.object({
  name: z.string().trim().min(1, "Enter your name.").max(200),
  email: z
    .string()
    .trim()
    .max(320)
    .refine((v) => z.email().safeParse(v).success, "Enter a valid email address."),
});

export async function updateProfileAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const parsed = profileSchema.safeParse(readFields(formData, ["name", "email"]));
  if (!parsed.success) return failure(firstIssue(parsed.error));
  const { db, user } = await getAppContext({ allowInactive: true });
  if ((await updateProfile(db, user.id, parsed.data)) === "email_taken") return failure("Another account already uses this email.");
  return success("Profile saved.");
}

const passwordSchema = z
  .object({
    current: z.string().min(1, "Enter your current password."),
    password: z.string().min(PASSWORD_MIN_LENGTH, `Use at least ${PASSWORD_MIN_LENGTH} characters.`).max(200),
    confirm: z.string(),
  })
  .refine((v) => v.password === v.confirm, "The two new passwords don't match.");

export async function changePasswordAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const parsed = passwordSchema.safeParse(readFields(formData, ["current", "password", "confirm"]));
  if (!parsed.success) return failure(firstIssue(parsed.error));
  const { db, user } = await getAppContext({ allowInactive: true });
  if (!(await changePassword(db, user.id, parsed.data.current, parsed.data.password))) {
    return failure("Your current password is not correct.");
  }
  // Changing the password signs out every session, including this one; start a fresh one.
  const { token } = await createSession(db, user.id);
  await setSessionCookie(token);
  return success("Password changed. Other devices were signed out.");
}

export async function deleteAccountAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const parsed = z
    .object({ password: z.string().min(1, "Enter your password to confirm."), confirm: z.literal("DELETE", 'Type DELETE to confirm.') })
    .safeParse(readFields(formData, ["password", "confirm"]));
  if (!parsed.success) return failure(firstIssue(parsed.error));
  const { db, user, workspace } = await getAppContext({ allowInactive: true });
  // Check the password before touching the subscription.
  if (!(await verifyPassword(parsed.data.password, user.passwordHash))) return failure("Your password is not correct.");

  if (workspace.billingSubscriptionId && isBillingEnabled() && ["active", "on_trial", "past_due", "paused", "unpaid"].includes(workspace.subscriptionStatus)) {
    try {
      await cancelSubscription(workspace.billingSubscriptionId);
    } catch {
      return failure("We couldn't cancel your subscription automatically. Cancel it from Billing first, then delete your account.");
    }
  }
  if (!(await deleteAccount(db, user.id, parsed.data.password))) return failure("Your password is not correct.");
  await clearSessionCookie();
  redirect("/?account=deleted");
}

export async function startCheckoutAction(): Promise<void> {
  const { user, workspace } = await getAppContext({ allowInactive: true });
  if (!isBillingEnabled()) redirect("/billing");
  let url: string;
  try {
    url = await createCheckoutUrl(workspace, user);
  } catch {
    redirect("/billing?checkout=error");
  }
  redirect(url);
}
