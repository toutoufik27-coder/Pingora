import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import type { ReactNode } from "react";
import { MonthPicker } from "@/components/period-picker";
import { Alert, Balance, buttonClass, Card, Money, PageHeader, StatCard, TableWrap, tableClass, tdClass, thClass } from "@/components/ui";
import { describeRule } from "@/lib/commission";
import { formatDate, monthPeriod } from "@/lib/dates";
import { PAYOUT_FLOW_LABELS } from "@/lib/domain";
import { formatMoney } from "@/lib/money";
import { monthParam } from "@/lib/search-params";
import type { PropertyStatement, StatementLine } from "@/lib/statement";
import { getAppContext } from "@/server/context";
import { loadOwnerStatement } from "@/server/statements";

export const metadata: Metadata = { title: "Owner statement" };

function describeLine(line: StatementLine): string {
  const tx = line.transaction;
  if (tx.kind === "reservation") return tx.guest || "Reservation";
  return [tx.type, tx.details].filter(Boolean).join(" · ");
}

export default async function OwnerStatementPage({ params, searchParams }: PageProps<"/statements/[ownerId]">) {
  const [{ ownerId }, query] = await Promise.all([params, searchParams]);
  const month = monthParam(query);
  const { db, workspace } = await getAppContext();
  const statement = await loadOwnerStatement(db, workspace, ownerId, monthPeriod(month));
  if (!statement) notFound();
  const { totals, currency } = statement;

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
          </>
        }
      />

      {statement.currencies.length > 1 ? (
        <div className="mb-4">
          <Alert tone="danger" title="Mixed currencies">
            This statement mixes {statement.currencies.join(", ")}; totals add them together.
          </Alert>
        </div>
      ) : null}

      <div className="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Airbnb payouts" value={formatMoney(totals.payoutCents, currency)} hint={`${totals.bookings} bookings · ${totals.nights} nights`} />
        <StatCard label="Your fees" value={formatMoney(totals.cohostFeesCents, currency)} />
        <StatCard
          label="Expenses"
          value={formatMoney(totals.reimbursableExpensesCents + totals.ownerPaidExpensesCents, currency)}
          hint={`${formatMoney(totals.reimbursableExpensesCents, currency)} paid by you`}
        />
        <StatCard label="Owner net income" value={formatMoney(totals.ownerNetCents, currency)} tone="brand" />
      </div>

      <Card className="mb-6">
        <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
          <span className="text-sm text-slate-600">Settlement for {statement.period.label}</span>
          <span className="text-lg">
            <Balance cents={totals.balanceDueToOwnerCents} currency={currency} />
          </span>
        </div>
      </Card>

      <div className="space-y-6">
        {statement.properties.length === 0 ? (
          <Alert tone="info">
            {statement.owner.name} has no properties yet.{" "}
            <Link href="/properties" className="underline">
              Assign a property
            </Link>
            .
          </Alert>
        ) : (
          statement.properties.map((section) => <PropertySection key={section.property.id} section={section} currency={currency} />)
        )}
      </div>
    </>
  );
}

function PropertySection({ section, currency }: { section: PropertyStatement; currency: string }) {
  const { property, totals } = section;
  return (
    <Card
      title={
        <Link href={`/properties/${property.id}`} className="hover:underline">
          {property.name}
        </Link>
      }
      description={`${describeRule(property.rule)} · ${PAYOUT_FLOW_LABELS[property.payoutFlow]}`}
    >
      {section.lines.length === 0 ? (
        <p className="text-sm text-slate-500">No bookings in this period.</p>
      ) : (
        <TableWrap>
          <table className={tableClass}>
            <thead>
              <tr>
                <th className={thClass}>Date</th>
                <th className={thClass}>Guest / item</th>
                <th className={`${thClass} text-right`}>Nights</th>
                <th className={thClass}>Code</th>
                <th className={`${thClass} text-right`}>Gross</th>
                <th className={`${thClass} text-right`}>Airbnb fee</th>
                <th className={`${thClass} text-right`}>Payout</th>
                <th className={`${thClass} text-right`}>Your fee</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {section.lines.map((line) => (
                <tr key={line.transaction.id}>
                  <td className={`${tdClass} whitespace-nowrap`}>{formatDate(line.attributionDate)}</td>
                  <td className={tdClass}>{describeLine(line)}</td>
                  <td className={`${tdClass} tabular text-right`}>{line.transaction.nights ?? ""}</td>
                  <td className={`${tdClass} font-mono text-xs`}>{line.transaction.confirmationCode}</td>
                  <td className={`${tdClass} text-right`}>
                    <Money cents={line.grossCents} currency={currency} />
                  </td>
                  <td className={`${tdClass} text-right`}>
                    <Money cents={-line.transaction.serviceFeeCents} currency={currency} />
                  </td>
                  <td className={`${tdClass} text-right`}>
                    <Money cents={line.transaction.amountCents} currency={currency} />
                  </td>
                  <td className={`${tdClass} text-right`}>
                    <Money cents={line.fee.totalCents} currency={currency} />
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot className="border-t-2 border-slate-200 font-semibold text-slate-900">
              <tr>
                <td className={tdClass} colSpan={2}>
                  Total · {totals.bookings} booking{totals.bookings === 1 ? "" : "s"}
                </td>
                <td className={`${tdClass} tabular text-right`}>{totals.nights}</td>
                <td className={tdClass} />
                <td className={`${tdClass} text-right`}>
                  <Money cents={totals.grossCents} currency={currency} />
                </td>
                <td className={`${tdClass} text-right`}>
                  <Money cents={-totals.serviceFeeCents} currency={currency} />
                </td>
                <td className={`${tdClass} text-right`}>
                  <Money cents={totals.payoutCents} currency={currency} />
                </td>
                <td className={`${tdClass} text-right`}>
                  <Money cents={totals.commissionCents + totals.flatFeesCents + totals.cleaningFeesToCohostCents} currency={currency} />
                </td>
              </tr>
            </tfoot>
          </table>
        </TableWrap>
      )}

      {section.expenses.length > 0 ? (
        <div className="mt-5">
          <h3 className="mb-2 text-sm font-semibold text-slate-900">Expenses</h3>
          <ul className="divide-y divide-slate-100 text-sm">
            {section.expenses.map((e) => (
              <li key={e.id} className="flex items-center justify-between gap-3 py-1.5">
                <span>
                  {formatDate(e.date)} · {e.category}
                  {e.description ? ` · ${e.description}` : ""}{" "}
                  <span className="text-slate-500">({e.paidBy === "cohost" ? "paid by you" : "paid by owner"})</span>
                </span>
                <Money cents={e.amountCents} currency={currency} />
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      <dl className="mt-5 grid gap-1 border-t border-slate-100 pt-4 text-sm sm:ml-auto sm:max-w-sm">
        {totals.monthlyFeesCents !== 0 ? (
          <Row label="Monthly management fee">
            <Money cents={totals.monthlyFeesCents} currency={currency} />
          </Row>
        ) : null}
        <Row label="Your fees">
          <Money cents={totals.cohostFeesCents} currency={currency} />
        </Row>
        <Row label="Owner net income">
          <Money cents={totals.ownerNetCents} currency={currency} />
        </Row>
        <Row label="Settlement">
          <Balance cents={totals.balanceDueToOwnerCents} currency={currency} />
        </Row>
      </dl>
    </Card>
  );
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <dt className="text-slate-600">{label}</dt>
      <dd>{children}</dd>
    </div>
  );
}
