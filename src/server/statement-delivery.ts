import { APP_NAME } from "@/lib/brand";
import { monthPeriod, todayIso } from "@/lib/dates";
import { formatMoney } from "@/lib/money";
import { renderStatementPdf } from "@/lib/pdf/statement-pdf";
import { hasActivity, type OwnerStatement } from "@/lib/statement";
import type { AppContext } from "./context";
import { emailHtml, sendEmail } from "./email";
import { appUrl } from "./env";
import { getOwner } from "./owners";
import { recordStatementSend } from "./statement-sends";
import { loadOwnerStatement } from "./statements";

export function slugify(value: string): string {
  return (
    value
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "") || "owner"
  );
}

export function statementFileName(statement: OwnerStatement, extension: "pdf" | "csv"): string {
  return `${slugify(statement.owner.name)}-statement-${statement.period.key}.${extension}`;
}

export function statementPdf(statement: OwnerStatement, businessName: string): Promise<Uint8Array> {
  return renderStatementPdf(statement, { businessName, generatedOn: todayIso(), appName: APP_NAME });
}

function balanceSentence(statement: OwnerStatement): string {
  const balance = statement.totals.balanceDueToOwnerCents;
  const amount = formatMoney(Math.abs(balance), statement.currency);
  if (balance > 0) return `Balance due to you: ${amount}.`;
  if (balance < 0) return `Balance due from you: ${amount}.`;
  return "Nothing is due either way this month.";
}

export type DeliveryResult = { ok: true; sentTo: string; delivered: boolean } | { ok: false; error: string };

/** Emails an owner their statement as a PDF and records the delivery. */
export async function emailStatement(context: AppContext, ownerId: string, month: string, note = ""): Promise<DeliveryResult> {
  const { db, workspace, user } = context;
  const owner = await getOwner(db, workspace.id, ownerId);
  if (!owner) return { ok: false, error: "This owner no longer exists." };
  if (!owner.email) return { ok: false, error: `Add an email address for ${owner.name} first.` };
  const statement = await loadOwnerStatement(db, workspace, ownerId, monthPeriod(month));
  if (!statement) return { ok: false, error: "This owner no longer exists." };

  const pdf = await statementPdf(statement, workspace.name);
  const portal = owner.portalToken ? `${appUrl()}/o/${owner.portalToken}` : null;
  const lines = [
    `Hi ${owner.name},`,
    `Attached is your owner statement for ${statement.period.label} from ${workspace.name}.`,
    `${statement.totals.bookings} booking${statement.totals.bookings === 1 ? "" : "s"}, payouts of ${formatMoney(statement.totals.payoutCents, statement.currency)}. ${balanceSentence(statement)}`,
    ...(note.trim() ? [note.trim()] : []),
    `Reply to this email with any questions.\n${user.name}, ${workspace.name}`,
  ];
  const result = await sendEmail({
    to: owner.email,
    subject: `${statement.period.label} owner statement from ${workspace.name}`,
    fromName: workspace.name,
    replyTo: user.email,
    text: [...lines, ...(portal ? [`All your statements: ${portal}`] : [])].join("\n\n"),
    html: emailHtml(lines, portal ? { label: "View all statements online", url: portal } : undefined),
    attachments: [{ filename: statementFileName(statement, "pdf"), content: pdf }],
  });
  if (!result.ok) return { ok: false, error: `The email could not be sent: ${result.error}` };
  await recordStatementSend(db, workspace.id, statement, "email", owner.email);
  return { ok: true, sentTo: owner.email, delivered: result.delivered };
}

export interface BulkDeliveryResult {
  sent: string[];
  skipped: { owner: string; reason: string }[];
}

/** Emails every owner with activity in the month who hasn't been sent this month's statement yet. */
export async function emailAllStatements(
  context: AppContext,
  month: string,
  statements: OwnerStatement[],
  alreadySent: ReadonlySet<string>,
): Promise<BulkDeliveryResult> {
  const result: BulkDeliveryResult = { sent: [], skipped: [] };
  for (const statement of statements) {
    if (!hasActivity(statement)) continue;
    if (alreadySent.has(statement.owner.id)) {
      result.skipped.push({ owner: statement.owner.name, reason: "already sent" });
      continue;
    }
    const outcome = await emailStatement(context, statement.owner.id, month);
    if (outcome.ok) result.sent.push(statement.owner.name);
    else result.skipped.push({ owner: statement.owner.name, reason: outcome.error });
  }
  return result;
}
