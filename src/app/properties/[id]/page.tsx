import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ActionForm } from "@/components/action-form";
import { Card, Field, inputClass, PageHeader } from "@/components/ui";
import {
  CLEANING_FEE_RECIPIENT_LABELS,
  CLEANING_FEE_RECIPIENTS,
  COMMISSION_BASE_LABELS,
  COMMISSION_BASES,
  PAYOUT_FLOW_LABELS,
  PAYOUT_FLOWS,
} from "@/lib/domain";
import { centsToInput } from "@/lib/money";
import { updatePropertyAction } from "@/server/actions/properties";
import { getAppContext } from "@/server/context";
import { listOwners } from "@/server/owners";
import { getProperty } from "@/server/properties";

export const metadata: Metadata = { title: "Edit property" };

export default async function PropertyPage({ params }: PageProps<"/properties/[id]">) {
  const { id } = await params;
  const { db, workspace } = await getAppContext();
  const [property, owners] = await Promise.all([getProperty(db, workspace.id, id), listOwners(db, workspace.id)]);
  if (!property) notFound();

  return (
    <>
      <PageHeader
        title={property.name}
        description={
          <>
            Airbnb listing{property.listingNames.length === 1 ? "" : "s"}: {property.listingNames.join(", ") || "none"} ·{" "}
            {property.transactionCount} transactions ·{" "}
            <Link href="/properties" className="underline">
              All properties
            </Link>
          </>
        }
      />

      <ActionForm action={updatePropertyAction.bind(null, property.id)} submitLabel="Save property" className="space-y-6">
        <Card title="Property">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Name" htmlFor="name">
              <input id="name" name="name" defaultValue={property.name} required className={inputClass} />
            </Field>
            <Field
              label="Owner"
              htmlFor="ownerId"
              hint={
                owners.length === 0 ? (
                  <>
                    <Link href="/owners" className="underline">
                      Add an owner
                    </Link>{" "}
                    first.
                  </>
                ) : undefined
              }
            >
              <select id="ownerId" name="ownerId" defaultValue={property.ownerId ?? ""} className={inputClass}>
                <option value="">— No owner —</option>
                {owners.map((o) => (
                  <option key={o.id} value={o.id}>
                    {o.name}
                  </option>
                ))}
              </select>
            </Field>
          </div>
        </Card>

        <Card title="Who receives the money" description="Decides who owes whom at the end of each month.">
          <fieldset className="space-y-2">
            <legend className="sr-only">Payout flow</legend>
            {PAYOUT_FLOWS.map((flow) => (
              <label key={flow} className="flex items-start gap-3 rounded-lg border border-slate-200 px-3 py-2 text-sm has-[:checked]:border-brand-600 has-[:checked]:bg-brand-50">
                <input type="radio" name="payoutFlow" value={flow} defaultChecked={property.payoutFlow === flow} className="mt-0.5 accent-brand-600" />
                <span>{PAYOUT_FLOW_LABELS[flow]}</span>
              </label>
            ))}
          </fieldset>
        </Card>

        <Card title="Your fee" description="Applied to every booking and adjustment. Damage reimbursements are passed to the owner in full.">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Commission rate (%)" htmlFor="commissionRate">
              <input
                id="commissionRate"
                name="commissionRate"
                inputMode="decimal"
                defaultValue={String(property.commissionRateBps / 100)}
                className={inputClass}
              />
            </Field>
            <Field label="Commission is a percentage of" htmlFor="commissionBase">
              <select id="commissionBase" name="commissionBase" defaultValue={property.commissionBase} className={inputClass}>
                {COMMISSION_BASES.map((base) => (
                  <option key={base} value={base}>
                    {COMMISSION_BASE_LABELS[base]}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="The guest cleaning fee goes to" htmlFor="cleaningFeeTo">
              <select id="cleaningFeeTo" name="cleaningFeeTo" defaultValue={property.cleaningFeeTo} className={inputClass}>
                {CLEANING_FEE_RECIPIENTS.map((r) => (
                  <option key={r} value={r}>
                    {CLEANING_FEE_RECIPIENT_LABELS[r]}
                  </option>
                ))}
              </select>
            </Field>
            <div className="flex items-end pb-2">
              <label className="flex items-center gap-2 text-sm text-slate-700">
                <input
                  type="checkbox"
                  name="excludeCleaningFee"
                  defaultChecked={property.excludeCleaningFee}
                  className="size-4 accent-brand-600"
                />
                Don&apos;t take commission on cleaning fees
              </label>
            </div>
            <Field label="Flat fee per booking ($)" htmlFor="flatFee" hint="Optional. Charged once per reservation.">
              <input id="flatFee" name="flatFee" inputMode="decimal" defaultValue={centsToInput(property.flatFeePerReservationCents)} className={inputClass} />
            </Field>
            <Field label="Monthly management fee ($)" htmlFor="monthlyFee" hint="Optional. Charged every month, with or without bookings.">
              <input id="monthlyFee" name="monthlyFee" inputMode="decimal" defaultValue={centsToInput(property.monthlyFeeCents)} className={inputClass} />
            </Field>
          </div>
        </Card>
      </ActionForm>
    </>
  );
}
