"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { failure, success, type ActionState } from "@/lib/action-state";
import { isValidMonth, monthPeriod } from "@/lib/dates";
import { generateToken } from "../auth/crypto";
import { getAppContext } from "../context";
import { setOwnerPortalToken } from "../owners";
import { emailAllStatements, emailStatement } from "../statement-delivery";
import { latestSendsForPeriod, recordStatementSend } from "../statement-sends";
import { loadOwnerStatement, loadStatements } from "../statements";
import { idField, readFields } from "./fields";

const monthField = z.string().refine(isValidMonth, "Unknown month.");

export async function emailStatementAction(ownerId: string, month: string, _state: ActionState, formData: FormData): Promise<ActionState> {
  const id = idField.safeParse(ownerId);
  const period = monthField.safeParse(month);
  const note = z.string().max(2000, "Keep the note under 2,000 characters.").safeParse(readFields(formData, ["note"]).note);
  if (!id.success || !period.success) return failure("Unknown statement.");
  if (!note.success) return failure(note.error.issues[0].message);
  const context = await getAppContext();
  const result = await emailStatement(context, id.data, period.data, note.data);
  if (!result.ok) return failure(result.error);
  revalidatePath("/", "layout");
  return success(
    result.delivered
      ? `Statement emailed to ${result.sentTo}.`
      : `Statement recorded as sent to ${result.sentTo}. Email delivery isn't configured yet, so nothing left the app.`,
  );
}

export async function markStatementSentAction(ownerId: string, month: string): Promise<void> {
  const id = idField.parse(ownerId);
  const period = monthField.parse(month);
  const { db, workspace } = await getAppContext();
  const statement = await loadOwnerStatement(db, workspace, id, monthPeriod(period));
  if (statement) await recordStatementSend(db, workspace.id, statement, "manual", null);
  revalidatePath("/", "layout");
}

export async function emailAllStatementsAction(month: string, _state: ActionState): Promise<ActionState> {
  const period = monthField.safeParse(month);
  if (!period.success) return failure("Unknown month.");
  const context = await getAppContext();
  const { statements } = await loadStatements(context.db, context.workspace, monthPeriod(period.data));
  const sent = await latestSendsForPeriod(context.db, context.workspace.id, period.data);
  const result = await emailAllStatements(context, period.data, statements, new Set(sent.keys()));
  revalidatePath("/", "layout");
  const problems = result.skipped.filter((s) => s.reason !== "already sent");
  if (result.sent.length === 0 && problems.length === 0) return success("Every statement with activity was already sent.");
  const parts = [`Sent ${result.sent.length} statement${result.sent.length === 1 ? "" : "s"}.`];
  if (problems.length > 0) parts.push(`Not sent: ${problems.map((p) => `${p.owner} (${p.reason})`).join("; ")}`);
  return problems.length > 0 && result.sent.length === 0 ? failure(parts.join(" ")) : success(parts.join(" "));
}

export async function createPortalLinkAction(ownerId: string): Promise<void> {
  const id = idField.parse(ownerId);
  const { db, workspace } = await getAppContext();
  await setOwnerPortalToken(db, workspace.id, id, generateToken());
  revalidatePath("/", "layout");
}

export async function revokePortalLinkAction(ownerId: string): Promise<void> {
  const id = idField.parse(ownerId);
  const { db, workspace } = await getAppContext();
  await setOwnerPortalToken(db, workspace.id, id, null);
  revalidatePath("/", "layout");
}
