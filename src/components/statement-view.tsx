import Link from "next/link";
import type { ReactNode } from "react";
import { describeRule } from "@/lib/commission";
import { formatDate } from "@/lib/dates";
import { PAYOUT_FLOW_LABELS, PAYOUT_FLOW_OWNER_LABELS } from "@/lib/domain";
import { formatMoney } from "@/lib/money";
import type { OwnerStatement, PropertyStatement, StatementLine } from "@/lib/statement";
import { Alert, Card, Money, StatCard, TableWrap, tableClass, tdClass, thClass } from "./ui";

/**
 * The body of an owner statement, shared by the co-host's app and the
 * owner's read-only portal. `viewer` switches the wording to the reader's side.
 */
export type StatementViewer = "cohost" | "owner";

function describeLine(line: StatementLine): string {
  const tx = line.transaction;
  if (tx.kind === "reservation") {
    const guest = tx.guest || "Reservation";
    return tx.channel && tx.channel !== "Airbnb" ? `${guest} (${tx.channel})` : guest;
  }
  return [tx.type, tx.details].filter(Boolean).join(" · ");
}

export function SettlementText({ cents, currency, viewer }: { cents: number; currency?: string; viewer: StatementViewer }) {
  if (cents === 0) return <span className="tabular text-slate-500">Settled · {formatMoney(0, currency)}</span>;
  const toOwner = cents > 0;
  const label = viewer === "cohost" ? (toOwner ? "Pay owner " : "Owner pays you ") : toOwner ? "Due to you " : "You owe your co-host ";
  return (
    <span className="tabular">
      <span className={toOwner ? "text-brand-700" : "text-amber-700"}>{label}</span>
      <span className="font-semibold">{formatMoney(Math.abs(cents), currency)}</span>
    </span>
  );
}

export function StatementView({ statement, viewer }: { statement: OwnerStatement; viewer: StatementViewer }) {
  const { totals, currency } = statement;
  return (
    <>
      {statement.currencies.length > 1 ? (
        <div className="mb-4">
          <Alert tone="danger" title="Mixed currencies">
            This statement mixes {statement.currencies.join(", ")}; totals add them together.
          </Alert>
        </div>
      ) : null}

      <div className="mb-6 grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
        <StatCard
          label="Payouts"
          value={formatMoney(totals.payoutCents, currency)}
          hint={`${totals.bookings} bookings · ${totals.nights} nights`}
        />
        <StatCard label={viewer === "cohost" ? "Your fees" : "Co-host fees"} value={formatMoney(totals.cohostFeesCents, currency)} />
        <StatCard
          label="Expenses"
          value={formatMoney(totals.reimbursableExpensesCents + totals.ownerPaidExpensesCents, currency)}
          hint={
            totals.reimbursableExpensesCents
              ? `${formatMoney(totals.reimbursableExpensesCents, currency)} paid by ${viewer === "cohost" ? "you" : "your co-host"}`
              : undefined
          }
        />
        <StatCard
          label={viewer === "cohost" ? "Owner net income" : "Your net income"}
          value={formatMoney(totals.ownerNetCents, currency)}
          tone="brand"
        />
      </div>

      <Card className="mb-6">
        <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
          <span className="text-sm text-slate-600">Settlement for {statement.period.label}</span>
          <span className="text-lg">
            <SettlementText cents={totals.balanceDueToOwnerCents} currency={currency} viewer={viewer} />
          </span>
        </div>
      </Card>

      <div className="space-y-6">
        {statement.properties.length === 0 ? (
          <Alert tone="info">
            {viewer === "cohost" ? (
              <>
                {statement.owner.name} has no properties yet.{" "}
                <Link href="/properties" className="underline">
                  Assign a property
                </Link>
                .
              </>
            ) : (
              "No properties on this statement."
            )}
          </Alert>
        ) : (
          statement.properties.map((section) => (
            <PropertySection key={section.property.id} section={section} currency={currency} viewer={viewer} />
          ))
        )}
      </div>
    </>
  );
}

function PropertySection({ section, currency, viewer }: { section: PropertyStatement; currency: string; viewer: StatementViewer }) {
  const { property, totals } = section;
  return (
    <Card
      title={
        viewer === "cohost" ? (
          <Link href={`/properties/${property.id}`} className="hover:underline">
            {property.name}
          </Link>
        ) : (
          property.name
        )
      }
      description={`${describeRule(property.rule)} · ${(viewer === "cohost" ? PAYOUT_FLOW_LABELS : PAYOUT_FLOW_OWNER_LABELS)[property.payoutFlow]}`}
    >
      {section.lines.length === 0 ? (
        <p className="text-sm text-slate-500">No bookings in this period.</p>
      ) : (
        <>
          {/* Phones: one compact card per line instead of an eight-column table. */}
          <ul className="-mx-1 divide-y divide-slate-100 sm:hidden">
            {section.lines.map((line) => (
              <li key={line.transaction.id} className="px-1 py-3 text-sm">
                <div className="flex items-baseline justify-between gap-3">
                  <span className="min-w-0 truncate font-medium text-slate-900">{describeLine(line)}</span>
                  <Money cents={line.transaction.amountCents} currency={currency} className="shrink-0 font-medium text-slate-900" />
                </div>
                <div className="mt-1 flex items-baseline justify-between gap-3 text-xs text-slate-500">
                  <span>
                    {formatDate(line.attributionDate)}
                    {line.transaction.nights ? ` · ${line.transaction.nights} nights` : ""}
                    {line.transaction.confirmationCode ? ` · ${line.transaction.confirmationCode}` : ""}
                  </span>
                  <span className="shrink-0">
                    {viewer === "cohost" ? "Your fee" : "Co-host fee"} <Money cents={line.fee.totalCents} currency={currency} />
                  </span>
                </div>
              </li>
            ))}
            <li className="flex items-baseline justify-between gap-3 px-1 pt-3 text-sm font-semibold text-slate-900">
              <span>
                {totals.bookings} booking{totals.bookings === 1 ? "" : "s"} · {totals.nights} nights
              </span>
              <Money cents={totals.payoutCents} currency={currency} />
            </li>
          </ul>
          <div className="hidden sm:block">
            <TableWrap>
              <table className={tableClass}>
                <thead>
                  <tr>
                    <th className={thClass}>Date</th>
                    <th className={thClass}>Guest / item</th>
                    <th className={`${thClass} text-right`}>Nights</th>
                    <th className={thClass}>Code</th>
                    <th className={`${thClass} text-right`}>Gross</th>
                    <th className={`${thClass} text-right`}>Platform fee</th>
                    <th className={`${thClass} text-right`}>Payout</th>
                    <th className={`${thClass} text-right`}>{viewer === "cohost" ? "Your fee" : "Co-host fee"}</th>
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
                      Total · {totals.bookings} booking
                      {totals.bookings === 1 ? "" : "s"}
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
          </div>
        </>
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
                  <span className="text-slate-500">
                    (
                    {e.paidBy === "cohost"
                      ? viewer === "cohost"
                        ? "paid by you"
                        : "paid by your co-host"
                      : viewer === "cohost"
                        ? "paid by owner"
                        : "paid by you"}
                    )
                  </span>
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
        <Row label={viewer === "cohost" ? "Your fees" : "Co-host fees"}>
          <Money cents={totals.cohostFeesCents} currency={currency} />
        </Row>
        <Row label={viewer === "cohost" ? "Owner net income" : "Your net income"}>
          <Money cents={totals.ownerNetCents} currency={currency} />
        </Row>
        <Row label="Settlement">
          <SettlementText cents={totals.balanceDueToOwnerCents} currency={currency} viewer={viewer} />
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
