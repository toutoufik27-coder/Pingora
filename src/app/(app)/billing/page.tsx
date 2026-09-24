import type { Metadata } from "next";
import { Alert, Badge, buttonClass, Card, PageHeader } from "@/components/ui";
import { describeBilling, hasAccess, isSubscribed, TRIAL_DAYS } from "@/lib/billing";
import { PRICE_MONTHLY_USD, SUPPORT_EMAIL } from "@/lib/brand";
import { formatDate } from "@/lib/dates";
import { firstParam } from "@/lib/search-params";
import { startCheckoutAction } from "@/server/actions/account";
import { getAppContext } from "@/server/context";
import { isBillingEnabled } from "@/server/env";

export const metadata: Metadata = { title: "Billing" };

const FEATURES = [
  "Unlimited owners and properties",
  "Airbnb imports, direct and VRBO bookings",
  "PDF and CSV owner statements, emailed for you",
  "Owner portal with every statement",
  "Annual summary for tax season",
];

export default async function BillingPage({ searchParams }: PageProps<"/billing">) {
  const query = await searchParams;
  const { workspace } = await getAppContext({ allowInactive: true });
  const now = new Date();
  const enabled = isBillingEnabled();
  const access = hasAccess(workspace, now, enabled);
  const subscribed = isSubscribed(workspace);
  const checkout = firstParam(query, "checkout");

  return (
    <>
      <PageHeader title="Billing" description={`One plan with everything, $${PRICE_MONTHLY_USD} per month. Cancel anytime.`} />

      <div className="grid max-w-3xl gap-6">
        {checkout === "success" ? (
          <Alert tone="info" title="Thank you!">
            Your subscription is being activated. It can take a minute to show here; refresh the page if needed.
          </Alert>
        ) : null}
        {checkout === "error" ? (
          <Alert tone="danger" title="Checkout could not start">
            Please try again in a moment, or email {SUPPORT_EMAIL}.
          </Alert>
        ) : null}
        {!enabled ? (
          <Alert tone="info" title="Billing is not configured">
            This installation has no payment provider set up, so every feature is unlocked. Add the Lemon Squeezy settings described in the
            README to start charging.
          </Alert>
        ) : null}
        {enabled && !access ? (
          <Alert tone="danger" title="Your access is paused">
            {workspace.subscriptionStatus === "trialing"
              ? `Your ${TRIAL_DAYS}-day free trial has ended. Subscribe to keep preparing statements — your data is safe and waiting.`
              : "Your subscription is not active. Update your payment method or subscribe again to continue — your data is safe."}
          </Alert>
        ) : null}

        <Card title="Your plan">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <div className="flex items-center gap-2">
                <span className="text-lg font-semibold text-ink-900">CoHost Ledger Pro</span>
                <Badge tone={access ? "brand" : "danger"}>{describeBilling(workspace, now)}</Badge>
              </div>
              <p className="mt-1 text-sm text-ink-600">
                {workspace.subscriptionStatus === "trialing" && workspace.trialEndsAt
                  ? `Trial ends ${formatDate(workspace.trialEndsAt.toISOString().slice(0, 10))}.`
                  : workspace.currentPeriodEndsAt
                    ? `${workspace.subscriptionStatus === "cancelled" ? "Access ends" : "Renews"} ${formatDate(workspace.currentPeriodEndsAt.toISOString().slice(0, 10))}.`
                    : null}
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              {enabled && (!subscribed || !access || workspace.subscriptionStatus === "expired") ? (
                <form action={startCheckoutAction}>
                  <button type="submit" className={buttonClass("primary")}>
                    Subscribe · ${PRICE_MONTHLY_USD}/month
                  </button>
                </form>
              ) : null}
              {workspace.billingPortalUrl ? (
                <a href={workspace.billingPortalUrl} className={buttonClass("secondary")} target="_blank" rel="noreferrer">
                  Manage subscription & invoices
                </a>
              ) : null}
            </div>
          </div>
          <ul className="mt-5 grid gap-2 text-sm text-ink-700 sm:grid-cols-2">
            {FEATURES.map((f) => (
              <li key={f} className="flex items-start gap-2">
                <span aria-hidden className="text-brand-600">
                  ✓
                </span>
                {f}
              </li>
            ))}
          </ul>
        </Card>

        <p className="text-xs text-ink-500">
          Payments are processed by Lemon Squeezy, our merchant of record, which also handles sales tax and sends your invoices. Questions?{" "}
          {SUPPORT_EMAIL}
        </p>
      </div>
    </>
  );
}
