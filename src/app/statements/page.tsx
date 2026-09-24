import type { Metadata } from "next";
import Link from "next/link";
import { MonthPicker } from "@/components/period-picker";
import { Alert, Balance, ButtonLink, Card, EmptyState, Money, PageHeader, TableWrap, tableClass, tdClass, thClass } from "@/components/ui";
import { monthPeriod } from "@/lib/dates";
import { ATTRIBUTION_BASIS_LABELS } from "@/lib/domain";
import { hasActivity } from "@/lib/statement";
import { monthParam } from "@/lib/search-params";
import { getAppContext } from "@/server/context";
import { loadStatements } from "@/server/statements";

export const metadata: Metadata = { title: "Owner statements" };

export default async function StatementsPage({ searchParams }: PageProps<"/statements">) {
  const month = monthParam(await searchParams);
  const period = monthPeriod(month);
  const { db, workspace } = await getAppContext();
  const { statements, unassigned } = await loadStatements(db, workspace, period);
  const totalFees = statements.reduce((sum, s) => sum + s.totals.cohostFeesCents, 0);

  return (
    <>
      <PageHeader
        title={`Owner statements · ${period.label}`}
        description={
          <>
            {ATTRIBUTION_BASIS_LABELS[workspace.attributionBasis]}.{" "}
            <Link href="/settings" className="underline">
              Change
            </Link>
          </>
        }
        actions={<MonthPicker month={month} basePath="/statements" />}
      />

      {unassigned.length > 0 ? (
        <div className="mb-4">
          <Alert title="Bookings missing from statements">
            {unassigned.map((u, i) => (
              <span key={u.propertyId}>
                {i > 0 ? ", " : ""}
                <Link href={`/properties/${u.propertyId}`} className="font-medium underline">
                  {u.propertyName}
                </Link>{" "}
                ({u.lines} lines)
              </span>
            ))}{" "}
            {unassigned.length === 1 ? "has" : "have"} activity in {period.label} but no owner.
          </Alert>
        </div>
      ) : null}

      {statements.length === 0 ? (
        <EmptyState title="No owners yet" action={<ButtonLink href="/owners">Add an owner</ButtonLink>}>
          Add the owners you work for and assign their properties to prepare statements.
        </EmptyState>
      ) : (
        <Card
          title={`${statements.filter(hasActivity).length} of ${statements.length} owners with activity`}
          description={
            <>
              Your fees this month: <Money cents={totalFees} className="font-semibold text-slate-900" />
            </>
          }
        >
          <TableWrap>
            <table className={tableClass}>
              <thead>
                <tr>
                  <th className={thClass}>Owner</th>
                  <th className={`${thClass} text-right`}>Bookings</th>
                  <th className={`${thClass} text-right`}>Airbnb payouts</th>
                  <th className={`${thClass} text-right`}>Your fees</th>
                  <th className={`${thClass} text-right`}>Expenses</th>
                  <th className={thClass}>Settlement</th>
                  <th className={thClass}>
                    <span className="sr-only">Actions</span>
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {statements.map((s) => (
                  <tr key={s.owner.id} className={hasActivity(s) ? "" : "text-slate-400"}>
                    <td className={tdClass}>
                      <Link href={`/statements/${s.owner.id}?month=${month}`} className="font-medium text-slate-900 hover:underline">
                        {s.owner.name}
                      </Link>
                      <div className="text-xs text-slate-500">
                        {s.properties.length} propert{s.properties.length === 1 ? "y" : "ies"}
                      </div>
                    </td>
                    <td className={`${tdClass} tabular text-right`}>{s.totals.bookings}</td>
                    <td className={`${tdClass} text-right`}>
                      <Money cents={s.totals.payoutCents} currency={s.currency} />
                    </td>
                    <td className={`${tdClass} text-right`}>
                      <Money cents={s.totals.cohostFeesCents} currency={s.currency} />
                    </td>
                    <td className={`${tdClass} text-right`}>
                      <Money cents={s.totals.reimbursableExpensesCents + s.totals.ownerPaidExpensesCents} currency={s.currency} />
                    </td>
                    <td className={`${tdClass} whitespace-nowrap`}>
                      <Balance cents={s.totals.balanceDueToOwnerCents} currency={s.currency} />
                    </td>
                    <td className={`${tdClass} text-right whitespace-nowrap`}>
                      <ButtonLink href={`/statements/${s.owner.id}?month=${month}`} variant="secondary" size="sm">
                        View
                      </ButtonLink>{" "}
                      <a href={`/statements/${s.owner.id}/pdf?month=${month}`} className="text-xs font-medium text-brand-700 hover:underline">
                        PDF
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </TableWrap>
        </Card>
      )}
    </>
  );
}
