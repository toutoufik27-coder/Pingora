import type { Metadata } from "next";
import { ActionForm } from "@/components/action-form";
import { ConfirmButton } from "@/components/confirm-button";
import { MonthPicker } from "@/components/period-picker";
import { Badge, ButtonLink, Card, EmptyState, Field, inputClass, Money, PageHeader, TableWrap, tableClass, tdClass, thClass } from "@/components/ui";
import { formatDate, monthPeriod, todayIso } from "@/lib/dates";
import { EXPENSE_CATEGORIES, EXPENSE_PAYER_LABELS, EXPENSE_PAYERS } from "@/lib/domain";
import { monthParam } from "@/lib/search-params";
import { createExpenseAction, deleteExpenseAction } from "@/server/actions/expenses";
import { getAppContext } from "@/server/context";
import { listExpenses } from "@/server/expenses";
import { listProperties } from "@/server/properties";

export const metadata: Metadata = { title: "Expenses" };

export default async function ExpensesPage({ searchParams }: PageProps<"/expenses">) {
  const month = monthParam(await searchParams);
  const period = monthPeriod(month);
  const { db, workspace } = await getAppContext();
  const [properties, expenses] = await Promise.all([listProperties(db, workspace.id), listExpenses(db, workspace.id, period)]);
  const today = todayIso();
  const defaultDate = today >= period.start && today <= period.end ? today : period.end;
  const reimbursable = expenses.filter((e) => e.paidBy === "cohost").reduce((sum, e) => sum + e.amountCents, 0);

  return (
    <>
      <PageHeader
        title="Expenses"
        description="Cleaning, supplies and repairs for each property. Expenses you paid are reimbursed on the owner statement."
        actions={<MonthPicker month={month} basePath="/expenses" />}
      />

      {properties.length === 0 ? (
        <EmptyState title="Import your properties first" action={<ButtonLink href="/import">Import from Airbnb</ButtonLink>}>
          Expenses belong to a property, and properties are created from your Airbnb import.
        </EmptyState>
      ) : (
        <div className="grid gap-6 lg:grid-cols-3">
          <Card title="Add an expense">
            <ActionForm action={createExpenseAction} submitLabel="Add expense" pendingLabel="Adding…" className="space-y-4">
              <Field label="Property" htmlFor="propertyId">
                <select id="propertyId" name="propertyId" required className={inputClass}>
                  {properties.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
                </select>
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field label="Date" htmlFor="date">
                  <input id="date" name="date" type="date" required defaultValue={defaultDate} className={inputClass} />
                </Field>
                <Field label="Amount ($)" htmlFor="amount">
                  <input id="amount" name="amount" inputMode="decimal" required placeholder="45.00" className={inputClass} />
                </Field>
              </div>
              <Field label="Category" htmlFor="category">
                <select id="category" name="category" className={inputClass}>
                  {EXPENSE_CATEGORIES.map((c) => (
                    <option key={c}>{c}</option>
                  ))}
                </select>
              </Field>
              <Field label="Description" htmlFor="description">
                <input id="description" name="description" placeholder="Turnover clean after checkout" className={inputClass} />
              </Field>
              <fieldset className="space-y-2">
                <legend className="mb-1 text-sm font-medium text-ink-700">Who paid?</legend>
                {EXPENSE_PAYERS.map((payer) => (
                  <label key={payer} className="flex items-center gap-2 text-sm text-ink-700">
                    <input type="radio" name="paidBy" value={payer} defaultChecked={payer === "cohost"} className="accent-brand-600" />
                    {EXPENSE_PAYER_LABELS[payer]}
                  </label>
                ))}
              </fieldset>
            </ActionForm>
          </Card>

          <Card
            title={`${period.label} expenses`}
            description={expenses.length > 0 ? <>To reimburse from owners: <Money cents={reimbursable} /></> : undefined}
            className="lg:col-span-2"
          >
            {expenses.length === 0 ? (
              <p className="text-sm text-ink-500">No expenses recorded for {period.label}.</p>
            ) : (
              <TableWrap>
                <table className={tableClass}>
                  <thead>
                    <tr>
                      <th className={thClass}>Date</th>
                      <th className={thClass}>Property</th>
                      <th className={thClass}>Expense</th>
                      <th className={thClass}>Paid by</th>
                      <th className={`${thClass} text-right`}>Amount</th>
                      <th className={thClass}>
                        <span className="sr-only">Actions</span>
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-ink-100">
                    {expenses.map((e) => (
                      <tr key={e.id}>
                        <td className={`${tdClass} whitespace-nowrap`}>{formatDate(e.date)}</td>
                        <td className={tdClass}>{e.propertyName}</td>
                        <td className={tdClass}>
                          <div className="text-ink-900">{e.category}</div>
                          {e.description ? <div className="text-xs text-ink-500">{e.description}</div> : null}
                        </td>
                        <td className={tdClass}>
                          {e.paidBy === "cohost" ? <Badge tone="brand">You</Badge> : <Badge>Owner</Badge>}
                        </td>
                        <td className={`${tdClass} text-right`}>
                          <Money cents={e.amountCents} />
                        </td>
                        <td className={`${tdClass} text-right`}>
                          <form action={deleteExpenseAction.bind(null, e.id)}>
                            <ConfirmButton label="Delete" confirmMessage="Delete this expense?" />
                          </form>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </TableWrap>
            )}
          </Card>
        </div>
      )}
    </>
  );
}
