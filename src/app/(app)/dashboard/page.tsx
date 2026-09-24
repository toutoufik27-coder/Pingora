import Link from "next/link";
import { Alert, ButtonLink, Card, PageHeader, StatCard } from "@/components/ui";
import { FeesChart } from "@/components/fees-chart";
import { defaultStatementMonth, formatDate, monthPeriod, shiftMonth } from "@/lib/dates";
import { formatMoney } from "@/lib/money";
import { hasActivity } from "@/lib/statement";
import { getAppContext } from "@/server/context";
import { listImports } from "@/server/imports";
import { listOwners } from "@/server/owners";
import { listProperties } from "@/server/properties";
import { loadStatements } from "@/server/statements";

export default async function DashboardPage() {
  const { db, workspace } = await getAppContext();
  const month = defaultStatementMonth();
  const period = monthPeriod(month);
  const [owners, properties, imports, { statements, unassigned }] = await Promise.all([
    listOwners(db, workspace.id),
    listProperties(db, workspace.id),
    listImports(db, workspace.id),
    loadStatements(db, workspace, period),
  ]);
  // Fees for the six months up to the one that just ended.
  const chartMonths = [5, 4, 3, 2, 1, 0].map((back) => shiftMonth(month, -back));
  const history = await Promise.all(
    chartMonths.map(async (m) => {
      const { statements: monthly } = await loadStatements(db, workspace, monthPeriod(m));
      return {
        month: m,
        label: monthPeriod(m).label.slice(0, 3),
        cents: monthly.reduce((total, s) => total + s.totals.cohostFeesCents, 0),
      };
    }),
  );

  const withoutOwner = properties.filter((p) => !p.ownerId);
  const active = statements.filter(hasActivity);
  const sum = (pick: (s: (typeof statements)[number]) => number) => active.reduce((total, s) => total + pick(s), 0);
  const dueToOwners = sum((s) => Math.max(s.totals.balanceDueToOwnerCents, 0));
  const dueFromOwners = sum((s) => Math.max(-s.totals.balanceDueToOwnerCents, 0));

  const steps = [
    { done: imports.length > 0, title: "Import your Airbnb transactions", href: "/import", cta: "Import CSV" },
    { done: owners.length > 0, title: "Add the owners you work for", href: "/owners", cta: "Add owners" },
    {
      done: properties.length > 0 && withoutOwner.length === 0,
      title: "Give every property an owner and your fee",
      href: "/properties",
      cta: "Set up properties",
    },
    { done: false, title: "Send each owner their monthly statement", href: "/statements", cta: "Open statements" },
  ];
  const setupDone = steps.slice(0, 3).every((s) => s.done);

  return (
    <>
      <PageHeader
        title={workspace.name}
        description={`Overview for ${period.label}, the month that just ended.`}
        actions={<ButtonLink href={`/statements?month=${month}`}>Prepare {period.label} statements</ButtonLink>}
      />

      {!setupDone ? (
        <Card title="Get set up" description="Four steps from an Airbnb export to owner statements." className="mb-6">
          <ol className="space-y-3">
            {steps.map((step, i) => (
              <li key={step.title} className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <div className="flex items-center gap-3">
                  <span
                    className={`grid size-7 shrink-0 place-items-center rounded-full text-xs font-semibold ${
                      step.done ? "bg-brand-600 text-white" : "bg-slate-100 text-slate-600"
                    }`}
                  >
                    {step.done ? "✓" : i + 1}
                  </span>
                  <span className={step.done ? "text-slate-500 line-through" : "text-slate-900"}>{step.title}</span>
                </div>
                {!step.done ? (
                  <ButtonLink href={step.href} variant="secondary" size="sm">
                    {step.cta}
                  </ButtonLink>
                ) : null}
              </li>
            ))}
          </ol>
        </Card>
      ) : null}

      <div className="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label={`Your fees · ${period.label}`} value={formatMoney(sum((s) => s.totals.cohostFeesCents))} tone="brand" />
        <StatCard label="Payouts" value={formatMoney(sum((s) => s.totals.payoutCents))} hint={`${sum((s) => s.totals.bookings)} bookings`} />
        <StatCard label="You owe owners" value={formatMoney(dueToOwners)} hint="Where you collect the payouts" />
        <StatCard label="Owners owe you" value={formatMoney(dueFromOwners)} hint="Fees and expenses to invoice" />
      </div>

      {withoutOwner.length > 0 || unassigned.length > 0 ? (
        <div className="mb-6">
          <Alert title="Some properties have no owner">
            {withoutOwner.length} propert{withoutOwner.length === 1 ? "y is" : "ies are"} not assigned to an owner, so their bookings are
            left out of every statement.{" "}
            <Link href="/properties" className="font-medium underline">
              Assign owners →
            </Link>
          </Alert>
        </div>
      ) : null}

      <Card title="Your fees per month" description="Commission, flat and monthly fees across all owners, last six months." className="mb-6">
        <FeesChart points={history} />
      </Card>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card title="Owners" actions={<ButtonLink href="/owners" variant="secondary" size="sm">Manage</ButtonLink>}>
          {active.length === 0 ? (
            <p className="text-sm text-slate-500">No owner activity in {period.label} yet.</p>
          ) : (
            <ul className="divide-y divide-slate-100">
              {active.map((s) => (
                <li key={s.owner.id} className="flex items-center justify-between gap-3 py-2 text-sm">
                  <Link href={`/statements/${s.owner.id}?month=${month}`} className="font-medium text-slate-900 hover:underline">
                    {s.owner.name}
                  </Link>
                  <span className="tabular text-slate-600">
                    {s.totals.bookings} bookings · fees {formatMoney(s.totals.cohostFeesCents, s.currency)}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card title="Recent imports" actions={<ButtonLink href="/import" variant="secondary" size="sm">Import</ButtonLink>}>
          {imports.length === 0 ? (
            <p className="text-sm text-slate-500">Nothing imported yet.</p>
          ) : (
            <ul className="divide-y divide-slate-100">
              {imports.slice(0, 5).map((record) => (
                <li key={record.id} className="flex items-center justify-between gap-3 py-2 text-sm">
                  <span className="truncate text-slate-900">{record.fileName}</span>
                  <span className="shrink-0 text-slate-500">
                    {record.insertedCount} new · {formatDate(record.createdAt.toISOString().slice(0, 10))}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </>
  );
}
