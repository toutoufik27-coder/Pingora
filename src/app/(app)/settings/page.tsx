import type { Metadata } from "next";
import { ActionForm } from "@/components/action-form";
import { Card, Field, inputClass, PageHeader } from "@/components/ui";
import { ATTRIBUTION_BASES, ATTRIBUTION_BASIS_LABELS, COMMISSION_BASE_LABELS, COMMISSION_BASES, PAYOUT_FLOW_LABELS, PAYOUT_FLOWS } from "@/lib/domain";
import { updateSettingsAction } from "@/server/actions/settings";
import { getAppContext } from "@/server/context";

export const metadata: Metadata = { title: "Settings" };

export default async function SettingsPage() {
  const { workspace } = await getAppContext();

  return (
    <>
      <PageHeader title="Settings" description="Your business details and the defaults used for properties created by an import." />

      <ActionForm action={updateSettingsAction} submitLabel="Save settings" className="max-w-3xl space-y-6">
        <Card title="Business">
          <Field label="Business name" htmlFor="name" hint="Printed at the top of every owner statement.">
            <input id="name" name="name" required defaultValue={workspace.name} className={inputClass} />
          </Field>
        </Card>

        <Card title="Which month does a booking belong to?" description="Refunds and damage payouts always count in the month they happen.">
          <fieldset className="space-y-2">
            <legend className="sr-only">Statement month</legend>
            {ATTRIBUTION_BASES.map((basis) => (
              <label
                key={basis}
                className="flex items-start gap-3 rounded-lg border border-ink-200 px-3 py-2 text-sm has-[:checked]:border-brand-600 has-[:checked]:bg-brand-50"
              >
                <input
                  type="radio"
                  name="attributionBasis"
                  value={basis}
                  defaultChecked={workspace.attributionBasis === basis}
                  className="mt-0.5 accent-brand-600"
                />
                <span>{ATTRIBUTION_BASIS_LABELS[basis]}</span>
              </label>
            ))}
          </fieldset>
        </Card>

        <Card title="Defaults for new properties" description="Existing properties keep their own settings.">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Commission rate (%)" htmlFor="defaultCommissionRate">
              <input
                id="defaultCommissionRate"
                name="defaultCommissionRate"
                inputMode="decimal"
                defaultValue={String(workspace.defaultCommissionRateBps / 100)}
                className={inputClass}
              />
            </Field>
            <Field label="Commission is a percentage of" htmlFor="defaultCommissionBase">
              <select id="defaultCommissionBase" name="defaultCommissionBase" defaultValue={workspace.defaultCommissionBase} className={inputClass}>
                {COMMISSION_BASES.map((base) => (
                  <option key={base} value={base}>
                    {COMMISSION_BASE_LABELS[base]}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Who receives the Airbnb payouts" htmlFor="defaultPayoutFlow">
              <select id="defaultPayoutFlow" name="defaultPayoutFlow" defaultValue={workspace.defaultPayoutFlow} className={inputClass}>
                {PAYOUT_FLOWS.map((flow) => (
                  <option key={flow} value={flow}>
                    {PAYOUT_FLOW_LABELS[flow]}
                  </option>
                ))}
              </select>
            </Field>
            <div className="flex items-end pb-2">
              <label className="flex items-center gap-2 text-sm text-ink-700">
                <input type="checkbox" name="defaultExcludeCleaningFee" defaultChecked={workspace.defaultExcludeCleaningFee} className="size-4 accent-brand-600" />
                Don&apos;t take commission on cleaning fees
              </label>
            </div>
          </div>
        </Card>
      </ActionForm>
    </>
  );
}
