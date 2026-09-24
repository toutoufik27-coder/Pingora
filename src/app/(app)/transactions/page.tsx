import type { Metadata } from "next";
import Form from "next/form";
import { ActionForm } from "@/components/action-form";
import { ConfirmButton } from "@/components/confirm-button";
import { MonthPicker } from "@/components/period-picker";
import {
  Badge,
  ButtonLink,
  Card,
  EmptyState,
  Field,
  inputClass,
  Money,
  PageHeader,
  TableWrap,
  tableClass,
  tdClass,
  thClass,
} from "@/components/ui";
import { formatDate, monthPeriod, todayIso } from "@/lib/dates";
import { MANUAL_CHANNELS } from "@/lib/domain";
import { firstParam, monthParam } from "@/lib/search-params";
import { createManualTransactionAction, deleteManualTransactionAction } from "@/server/actions/transactions";
import { getAppContext } from "@/server/context";
import { listProperties } from "@/server/properties";
import { displayDate, listTransactions } from "@/server/transactions";

export const metadata: Metadata = { title: "Bookings" };

const KIND_LABELS: Record<string, string> = {
  reservation: "Booking",
  adjustment: "Adjustment",
  resolution: "Damage / resolution",
  other: "Other",
};

export default async function TransactionsPage({ searchParams }: PageProps<"/transactions">) {
  const query = await searchParams;
  const month = monthParam(query);
  const period = monthPeriod(month);
  const { db, workspace } = await getAppContext();
  const properties = await listProperties(db, workspace.id);
  const propertyFilter = firstParam(query, "property");
  const selected = properties.find((p) => p.id === propertyFilter)?.id;
  const rows = await listTransactions(db, workspace.id, period, selected);
  const today = todayIso();
  const defaultDate = today >= period.start && today <= period.end ? today : period.start;

  return (
    <>
      <PageHeader
        title="Bookings"
        description="Every booking and adjustment from your Airbnb imports, plus direct, VRBO and other bookings you add by hand."
        actions={<MonthPicker month={month} basePath="/transactions" />}
      />

      {properties.length === 0 ? (
        <EmptyState title="No properties yet" action={<ButtonLink href="/import">Import from Airbnb</ButtonLink>}>
          Import your Airbnb transactions first; each listing becomes a property you can also add direct bookings to.
        </EmptyState>
      ) : (
        <div className="grid gap-6 lg:grid-cols-3">
          <Card title="Add a booking by hand" description="For direct, VRBO or other bookings Airbnb doesn't know about.">
            <ActionForm action={createManualTransactionAction} submitLabel="Add" pendingLabel="Adding…" className="space-y-4">
              <Field label="Property" htmlFor="propertyId">
                <select id="propertyId" name="propertyId" defaultValue={selected} required className={inputClass}>
                  {properties.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
                </select>
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field label="Type" htmlFor="kind">
                  <select id="kind" name="kind" className={inputClass}>
                    <option value="reservation">Booking</option>
                    <option value="adjustment">Adjustment / refund</option>
                  </select>
                </Field>
                <Field label="Channel" htmlFor="channel">
                  <select id="channel" name="channel" className={inputClass}>
                    {MANUAL_CHANNELS.map((c) => (
                      <option key={c}>{c}</option>
                    ))}
                  </select>
                </Field>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <Field label="Check-in / date" htmlFor="date">
                  <input id="date" name="date" type="date" required defaultValue={defaultDate} className={inputClass} />
                </Field>
                <Field label="Nights" htmlFor="nights">
                  <input id="nights" name="nights" inputMode="numeric" placeholder="3" className={inputClass} />
                </Field>
              </div>
              <Field label="Guest" htmlFor="guest">
                <input id="guest" name="guest" placeholder="Jordan Lee" className={inputClass} />
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field label="Payout ($)" htmlFor="payout" hint="What was received. Use -60 for a refund.">
                  <input id="payout" name="payout" inputMode="decimal" required placeholder="850.00" className={inputClass} />
                </Field>
                <Field label="Channel fee ($)" htmlFor="channelFee" hint="Optional">
                  <input id="channelFee" name="channelFee" inputMode="decimal" placeholder="0" className={inputClass} />
                </Field>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <Field label="Cleaning fee ($)" htmlFor="cleaningFee" hint="Optional">
                  <input id="cleaningFee" name="cleaningFee" inputMode="decimal" placeholder="0" className={inputClass} />
                </Field>
                <Field label="Reference" htmlFor="confirmationCode" hint="Optional">
                  <input id="confirmationCode" name="confirmationCode" placeholder="VR-12345" className={inputClass} />
                </Field>
              </div>
              <Field label="Note" htmlFor="details">
                <input id="details" name="details" placeholder="Optional" className={inputClass} />
              </Field>
            </ActionForm>
          </Card>

          <Card
            title={`${period.label} · ${rows.length} line${rows.length === 1 ? "" : "s"}`}
            actions={
              <Form action="/transactions" className="flex items-center gap-2">
                <input type="hidden" name="month" value={month} />
                <label htmlFor="property" className="sr-only">
                  Filter by property
                </label>
                <select id="property" name="property" defaultValue={selected ?? ""} className={`${inputClass} w-48 py-1.5`}>
                  <option value="">All properties</option>
                  {properties.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
                </select>
                <button type="submit" className="text-sm font-medium text-brand-700 hover:underline">
                  Filter
                </button>
              </Form>
            }
            className="lg:col-span-2"
          >
            {rows.length === 0 ? (
              <p className="text-sm text-slate-500">Nothing in {period.label}.</p>
            ) : (
              <>
                <ul className="divide-y divide-slate-100 sm:hidden">
                  {rows.map((tx) => (
                    <li key={tx.id} className="flex items-start justify-between gap-3 py-3 text-sm">
                      <div className="min-w-0">
                        <div className="truncate font-medium text-slate-900">{tx.guest || tx.details || tx.type}</div>
                        <div className="text-xs text-slate-500">
                          {formatDate(displayDate(tx))} · {tx.propertyName} · {tx.channel}
                        </div>
                      </div>
                      <div className="flex shrink-0 flex-col items-end gap-1">
                        <Money cents={tx.amountCents} currency={tx.currency} className="font-medium" />
                        {tx.source === "manual" ? (
                          <form action={deleteManualTransactionAction.bind(null, tx.id)}>
                            <ConfirmButton label="Delete" confirmMessage="Delete this entry?" />
                          </form>
                        ) : null}
                      </div>
                    </li>
                  ))}
                </ul>
                <div className="hidden sm:block">
                  <TableWrap>
                    <table className={tableClass}>
                      <thead>
                        <tr>
                          <th className={thClass}>Date</th>
                          <th className={thClass}>Property</th>
                          <th className={thClass}>Guest / item</th>
                          <th className={thClass}>Channel</th>
                          <th className={`${thClass} text-right`}>Payout</th>
                          <th className={thClass}>
                            <span className="sr-only">Actions</span>
                          </th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100">
                        {rows.map((tx) => (
                          <tr key={tx.id}>
                            <td className={`${tdClass} whitespace-nowrap`}>
                              {formatDate(displayDate(tx))}
                              {tx.nights ? <div className="text-xs text-slate-500">{tx.nights} nights</div> : null}
                            </td>
                            <td className={tdClass}>{tx.propertyName}</td>
                            <td className={tdClass}>
                              <div className="text-slate-900">{tx.guest || tx.details || tx.type}</div>
                              <div className="text-xs text-slate-500">
                                {KIND_LABELS[tx.kind] ?? tx.type}
                                {tx.confirmationCode ? ` · ${tx.confirmationCode}` : ""}
                              </div>
                            </td>
                            <td className={tdClass}>
                              {tx.source === "manual" ? <Badge tone="brand">{tx.channel}</Badge> : <Badge>{tx.channel}</Badge>}
                            </td>
                            <td className={`${tdClass} text-right`}>
                              <Money cents={tx.amountCents} currency={tx.currency} />
                            </td>
                            <td className={`${tdClass} text-right`}>
                              {tx.source === "manual" ? (
                                <form action={deleteManualTransactionAction.bind(null, tx.id)}>
                                  <ConfirmButton label="Delete" confirmMessage="Delete this entry?" />
                                </form>
                              ) : null}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </TableWrap>
                </div>
              </>
            )}
          </Card>
        </div>
      )}
    </>
  );
}
