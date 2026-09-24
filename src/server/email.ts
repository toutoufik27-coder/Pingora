import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { emailConfig } from "./env";

/**
 * Outgoing email through Resend (https://resend.com). Without RESEND_API_KEY
 * nothing is sent: the message is logged, and written to EMAIL_OUTBOX_DIR when
 * that is set (used by the end-to-end tests).
 */

export interface EmailAttachment {
  filename: string;
  content: Uint8Array;
}

export interface EmailMessage {
  to: string;
  subject: string;
  text: string;
  html: string;
  replyTo?: string;
  /** Display name shown before the sender address, e.g. the co-host's business. */
  fromName?: string;
  attachments?: EmailAttachment[];
}

export type EmailResult = { ok: true; id: string; delivered: boolean } | { ok: false; error: string };

export function isEmailConfigured(): boolean {
  return emailConfig().resendApiKey !== null;
}

function fromAddress(configured: string, fromName?: string): string {
  if (!fromName) return configured;
  const address = /<([^>]+)>/.exec(configured)?.[1] ?? configured;
  const safeName = fromName.replace(/["<>\r\n]/g, "").slice(0, 80);
  return `"${safeName}" <${address}>`;
}

export async function sendEmail(message: EmailMessage): Promise<EmailResult> {
  const config = emailConfig();
  const from = fromAddress(config.from, message.fromName);

  if (!config.resendApiKey) {
    const id = `dev-${randomUUID()}`;
    console.info(`[email not configured] to=${message.to} subject="${message.subject}"\n${message.text}`);
    if (config.outboxDir) {
      await mkdir(config.outboxDir, { recursive: true });
      await writeFile(
        path.join(config.outboxDir, `${Date.now()}-${id}.json`),
        JSON.stringify({
          id,
          from,
          to: message.to,
          replyTo: message.replyTo ?? null,
          subject: message.subject,
          text: message.text,
          attachments: (message.attachments ?? []).map((a) => ({ filename: a.filename, bytes: a.content.byteLength })),
        }),
      );
    }
    return { ok: true, id, delivered: false };
  }

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${config.resendApiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from,
        to: [message.to],
        subject: message.subject,
        text: message.text,
        html: message.html,
        ...(message.replyTo ? { reply_to: message.replyTo } : {}),
        attachments: (message.attachments ?? []).map((a) => ({
          filename: a.filename,
          content: Buffer.from(a.content).toString("base64"),
        })),
      }),
    });
    const body = (await response.json().catch(() => ({}))) as { id?: string; message?: string };
    if (!response.ok) return { ok: false, error: body.message ?? `Email provider returned ${response.status}` };
    return { ok: true, id: body.id ?? "", delivered: true };
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "Could not reach the email provider" };
  }
}

/** Escapes text for use inside the HTML part of an email. */
export function escapeHtml(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

/** Minimal, widely compatible HTML wrapper for transactional emails. */
export function emailHtml(paragraphs: string[], action?: { label: string; url: string }): string {
  const body = paragraphs.map((p) => `<p style="margin:0 0 16px">${escapeHtml(p).replace(/\n/g, "<br>")}</p>`).join("");
  const button = action
    ? `<p style="margin:24px 0"><a href="${escapeHtml(action.url)}" style="background:#0f766e;color:#ffffff;padding:10px 18px;border-radius:6px;text-decoration:none;font-weight:600">${escapeHtml(action.label)}</a></p>`
    : "";
  return `<!doctype html><html><body style="margin:0;background:#f8fafc;padding:24px;font-family:Arial,Helvetica,sans-serif;color:#0f172a;font-size:15px;line-height:1.5"><div style="max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #e2e8f0;border-radius:10px;padding:28px">${body}${button}</div></body></html>`;
}
