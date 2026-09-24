import type { Metadata } from "next";
import Link from "next/link";
import { YearPicker } from "@/components/period-picker";
import { Alert, Badge, ButtonLink, Card, EmptyState, Money, PageHeader, TableWrap, tableClass, tdClass, thClass } from "@/components/ui";
import { yearPeriod } from "@/lib/dates";
import { formatMoney } from "@/lib/money";
import { yearParam } from "@/lib/search-params";
import { addTotals, emptyTotals } from "@/lib/statement";
import { form1099ThresholdCents } from "@/lib/tax";
import { getAppContext } from "@/server/context";
import { loadStatements } from "@/server/statements";

export const metadata: Metadata = { title: "Annual summary" };

export default async function AnnualSummaryPage({ searchParams }: PageProps<"/reports/annual">) {
  const year = yearParam(await searchParams);
  const { db, workspace } = await getAppContext();
  const { statements } = await loadStatements(db, workspace, yearPeriod(year));
  const threshold = form1099ThresholdCents(year);
  const all = statements.reduce((sum, s) => addTotals(sum, s.totals), emptyTotals());

  return (
    <>
      <PageHeader
        title={`Annual summary · ${year}`}
        description="Totals per owner for the calendar year, for tax season and year-end reviews."
        actions={<YearPicker year={year} basePath="/reports/annual" />}
      />

      {statements.length === 0 ? (
        <EmptyState title="No owners yet" action={<ButtonLink href="/owners">Add an owner</ButtonLink>} />
      ) : (
        <>
          <Card className="mb-6">
            <TableWrap>
              <table className={tableClass}>
                <thead>
                  <tr>
                    <th className={thClass}>Owner</th>
                    <th className={`${thClass} text-right`}>Bookings</th>
                    <th className={`${thClass} text-right`}>Gross revenue</th>
                    <th className={`${thClass} text-right`}>Payouts</th>
                    <th className={`${thClass} text-right`}>Your fees</th>
                    <th className={`${thClass} text-right`}>Expenses</th>
                    <th className={`${thClass} text-right`}>Owner net income</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {statements.map((s) => (
                    <tr key={s.owner.id}>
                      <td className={tdClass}>
                        <Link href={`/owners/${s.owner.id}`} className="font-medium text-slate-900 hover:underline">
                          {s.owner.name}
                        </Link>
                        {s.totals.cohostFeesCents >= threshold ? (
                          <div className="mt-1">
                            <Badge tone="warning">Fees ≥ {formatMoney(threshold)}</Badge>
                          </div>
                        ) : null}
                      </td>
                      <td className={`${tdClass} tabular text-right`}>{s.totals.bookings}</td>
                      <td className={`${tdClass} text-right`}>
                        <Money cents={s.totals.grossCents} currency={s.currency} />
                      </td>
                      <td className={`${tdClass} text-right`}>
                        <Money cents={s.totals.payoutCents} currency={s.currency} />
                      </td>
                      <td className={`${tdClass} text-right`}>
                        <Money cents={s.totals.cohostFeesCents} currency={s.currency} />
                      </td>
                      <td className={`${tdClass} text-right`}>
                        <Money cents={s.totals.reimbursableExpensesCents + s.totals.ownerPaidExpensesCents} currency={s.currency} />
                      </td>
                      <td className={`${tdClass} text-right`}>
                        <Money cents={s.totals.ownerNetCents} currency={s.currency} />
                      </td>
                    </tr>
                  ))}
                </tbody>
                <tfoot className="border-t-2 border-slate-200 font-semibold text-slate-900">
                  <tr>
                    <td className={tdClass}>All owners</td>
                    <td className={`${tdClass} tabular text-right`}>{all.bookings}</td>
                    <td className={`${tdClass} text-right`}>
                      <Money cents={all.grossCents} />
                    </td>
                    <td className={`${tdClass} text-right`}>
                      <Money cents={all.payoutCents} />
                    </td>
                    <td className={`${tdClass} text-right`}>
                      <Money cents={all.cohostFeesCents} />
                    </td>
                    <td className={`${tdClass} text-right`}>
                      <Money cents={all.reimbursableExpensesCents + all.ownerPaidExpensesCents} />
                    </td>
                    <td className={`${tdClass} text-right`}>
                      <Money cents={all.ownerNetCents} />
                    </td>
                  </tr>
                </tfoot>
              </table>
            </TableWrap>
          </Card>

          <Alert tone="info" title="About Form 1099">
            For payments made in {year}, the IRS reporting threshold for Forms 1099-NEC and 1099-MISC is {formatMoney(threshold)}
            {year >= 2026 ? " (raised from $600 by the One Big Beautiful Bill Act)" : ""}. Owners who pay you directly may need to send
            you a 1099-NEC once your fees reach it, and if you collect rent for an owner you may need to send them a 1099-MISC. Airbnb
            reports the payouts it makes on Form 1099-K. This summary is for reference; confirm what to file with a tax professional.
          </Alert>
        </>
      )}
    </>
  );
}
