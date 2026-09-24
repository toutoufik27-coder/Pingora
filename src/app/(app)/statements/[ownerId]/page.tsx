import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ActionForm } from "@/components/action-form";
import { MonthPicker } from "@/components/period-picker";
import { StatementView } from "@/components/statement-view";
import { Alert, Badge, buttonClass, Card, Field, inputClass, PageHeader } from "@/components/ui";
import { formatDate, monthPeriod } from "@/lib/dates";
import { monthParam } from "@/lib/search-params";
import { emailStatementAction, markStatementSentAction } from "@/server/actions/statements";
import { getAppContext } from "@/server/context";
import { isEmailConfigured } from "@/server/email";
import { getOwner } from "@/server/owners";
import { sendsForOwnerPeriod, snapshotChanged } from "@/server/statement-sends";
import { loadOwnerStatement } from "@/server/statements";

export const metadata: Metadata = { title: "Owner statement" };

export default async function OwnerStatementPage({ params, searchParams }: PageProps<"/statements/[ownerId]">) {
  const [{ ownerId }, query] = await Promise.all([params, searchParams]);
  const month = monthParam(query);
  const { db, workspace } = await getAppContext();
  const [statement, owner, sends] = await Promise.all([
    loadOwnerStatement(db, workspace, ownerId, monthPeriod(month)),
    getOwner(db, workspace.id, ownerId),
    sendsForOwnerPeriod(db, workspace.id, ownerId, month),
  ]);
  if (!statement || !owner) notFound();
  const lastSend = sends[0];
  const changed = lastSend ? snapshotChanged(lastSend.snapshot, statement) : false;

  return (
    <>
      <PageHeader
        title={`${statement.owner.name} · ${statement.period.label}`}
        description={
          <>
            Owner statement from {workspace.name}.{" "}
            <Link href={`/statements?month=${month}`} className="underline">
              All statements
            </Link>
          </>
        }
        actions={
          <>
            <MonthPicker month={month} basePath={`/statements/${ownerId}`} />
            <a href={`/statements/${ownerId}/pdf?month=${month}`} className={buttonClass("primary")}>
              Download PDF
            </a>
            <a href={`/statements/${ownerId}/csv?month=${month}`} className={buttonClass("secondary")}>
              CSV
            </a>
          </>
        }
      />

      <Card title="Send to owner" className="mb-6">
        {lastSend ? (
          <div className="mb-4 flex flex-wrap items-center gap-2 text-sm text-ink-600">
            <Badge tone="brand">Sent</Badge>
            {lastSend.method === "email" ? `Emailed to ${lastSend.sentTo}` : "Marked as sent"} on {formatDate(lastSend.createdAt.toISOString().slice(0, 10))}
            {sends.length > 1 ? ` (${sends.length} times)` : ""}.
          </div>
        ) : null}
        {changed ? (
          <div className="mb-4">
            <Alert title="The figures changed after this statement was sent">
              A later import, expense or fee change moved the totals. Send the updated statement so the owner has the right numbers.
            </Alert>
          </div>
        ) : null}
        {!isEmailConfigured() ? (
          <div className="mb-4">
            <Alert tone="info">Email delivery isn&apos;t configured on this installation yet: sending records the statement as sent without emailing it.</Alert>
          </div>
        ) : null}
        {owner.email ? (
          <ActionForm
            action={emailStatementAction.bind(null, owner.id, month)}
            submitLabel={lastSend ? "Send again" : `Email PDF to ${owner.email}`}
            pendingLabel="Sending…"
            className="space-y-3"
          >
            <Field label="Personal note (optional)" htmlFor="note">
              <textarea id="note" name="note" rows={2} maxLength={2000} placeholder="Thanks for a great summer season!" className={inputClass} />
            </Field>
          </ActionForm>
        ) : (
          <p className="text-sm text-ink-600">
            <Link href={`/owners/${owner.id}`} className="font-medium text-brand-700 underline">
              Add {owner.name}&apos;s email
            </Link>{" "}
            to send statements from here, or download the PDF and send it yourself.
          </p>
        )}
        {!lastSend ? (
          <form action={markStatementSentAction.bind(null, owner.id, month)} className="mt-3">
            <button type="submit" className="text-sm text-ink-600 underline hover:text-ink-900">
              I sent it myself — mark as sent
            </button>
          </form>
        ) : null}
      </Card>

      <StatementView statement={statement} viewer="cohost" />
    </>
  );
}
