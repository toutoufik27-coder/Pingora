import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import type { ReactNode } from "react";
import { StatementView } from "@/components/statement-view";
import { buttonClass, EmptyState } from "@/components/ui";
import { APP_NAME } from "@/lib/brand";
import { monthPeriod } from "@/lib/dates";
import { firstParam } from "@/lib/search-params";
import { workspaceHasAccess } from "@/server/context";
import { getDb } from "@/server/db/client";
import { getOwnerByPortalToken } from "@/server/owners";
import { sentPeriodsForOwner } from "@/server/statement-sends";
import { loadOwnerStatement } from "@/server/statements";
import { getWorkspace } from "@/server/workspace";

export const metadata: Metadata = { title: "Your owner statements", robots: { index: false, follow: false } };

/** Read-only statements for one owner, reached through the private link their co-host shared. */
export default async function OwnerPortalPage({ params, searchParams }: PageProps<"/o/[token]">) {
  const [{ token }, query] = await Promise.all([params, searchParams]);
  const db = await getDb();
  const owner = await getOwnerByPortalToken(db, token);
  const workspace = owner ? await getWorkspace(db, owner.workspaceId) : null;
  if (!owner || !workspace) notFound();

  const shell = (children: ReactNode) => (
    <div className="min-h-screen">
      <header className="border-b border-ink-200 bg-white">
        <div className="mx-auto flex max-w-6xl flex-col gap-1 px-4 py-5 md:px-10">
          <div className="text-sm text-ink-500">Owner statements from</div>
          <div className="text-xl font-semibold text-ink-900">{workspace.name}</div>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-6 md:px-10 md:py-8">{children}</main>
      <footer className="px-4 pb-8 text-center text-xs text-ink-400">Powered by {APP_NAME}</footer>
    </div>
  );

  if (!workspaceHasAccess(workspace)) {
    return shell(<EmptyState title="Statements are temporarily unavailable">Please contact {workspace.name}.</EmptyState>);
  }

  const periods = await sentPeriodsForOwner(db, owner.id);
  if (periods.length === 0) {
    return shell(
      <EmptyState title={`Hi ${owner.name}`}>Your statements will appear here as soon as {workspace.name} sends the first one.</EmptyState>,
    );
  }
  const requested = firstParam(query, "month");
  const month = requested && periods.includes(requested) ? requested : periods[0];
  const statement = await loadOwnerStatement(db, workspace, owner.id, monthPeriod(month));
  if (!statement) notFound();

  return shell(
    <>
      <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight text-ink-900">
            {owner.name} · {statement.period.label}
          </h1>
          <nav aria-label="Statement months" className="mt-3 flex flex-wrap gap-2">
            {periods.map((p) => (
              <Link
                key={p}
                href={`/o/${token}?month=${p}`}
                aria-current={p === month ? "page" : undefined}
                className={`rounded-full px-3 py-1 text-sm ${p === month ? "bg-brand-600 text-white" : "bg-white text-ink-700 ring-1 ring-ink-200 hover:bg-ink-50"}`}
              >
                {monthPeriod(p).label}
              </Link>
            ))}
          </nav>
        </div>
        <a href={`/o/${token}/pdf?month=${month}`} className={buttonClass("primary")}>
          Download PDF
        </a>
      </div>
      <StatementView statement={statement} viewer="owner" />
    </>,
  );
}
