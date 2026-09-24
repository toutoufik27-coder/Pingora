import type { Metadata } from "next";
import Link from "next/link";
import { buttonClass } from "@/components/ui";
import { TRIAL_DAYS } from "@/lib/billing";
import { PRICE_MONTHLY_USD, SUPPORT_EMAIL } from "@/lib/brand";

export const metadata: Metadata = {
  title: "Pricing",
  description: `One plan for Airbnb co-hosts: $${PRICE_MONTHLY_USD} per month, unlimited owners and properties, ${TRIAL_DAYS}-day free trial.`,
};

const INCLUDED = [
  "Unlimited owners, properties and bookings",
  "Airbnb CSV imports with duplicate protection",
  "Direct, VRBO and other bookings",
  "Flexible fees per property",
  "Expenses and reimbursements",
  "PDF and CSV statements",
  "Email statements to owners",
  "Owner portal",
  "Annual summary for tax season",
  "Email support",
];

export default function PricingPage() {
  return (
    <section className="mx-auto max-w-4xl px-4 py-16 md:px-8 md:py-24">
      <div className="text-center">
        <h1 className="text-4xl font-bold tracking-tight text-ink-900">Simple pricing</h1>
        <p className="mt-4 text-lg text-ink-600">One plan with everything. Try it free for {TRIAL_DAYS} days, no credit card.</p>
      </div>

      <div className="mx-auto mt-12 max-w-md rounded-2xl border border-ink-200 p-8 shadow-sm">
        <h2 className="text-lg font-semibold text-ink-900">Pro</h2>
        <p className="mt-4 flex items-baseline gap-1">
          <span className="text-5xl font-bold tracking-tight text-ink-900">${PRICE_MONTHLY_USD}</span>
          <span className="text-ink-500">/ month</span>
        </p>
        <p className="mt-2 text-sm text-ink-500">Billed monthly. Sales tax added where applicable. Cancel anytime.</p>
        <Link href="/signup" className={`${buttonClass("primary")} mt-6 w-full py-3 text-base`}>
          Start your free trial
        </Link>
        <ul className="mt-8 space-y-3 text-sm text-ink-700">
          {INCLUDED.map((item) => (
            <li key={item} className="flex gap-2">
              <span aria-hidden className="text-brand-600">
                ✓
              </span>
              {item}
            </li>
          ))}
        </ul>
      </div>

      <div className="mx-auto mt-16 max-w-2xl space-y-6 text-ink-700">
        <div>
          <h3 className="font-semibold text-ink-900">What happens when the trial ends?</h3>
          <p className="mt-1">Your data stays safe. Subscribe to keep preparing statements; nothing is charged until you do.</p>
        </div>
        <div>
          <h3 className="font-semibold text-ink-900">How do I cancel?</h3>
          <p className="mt-1">From the billing page, in two clicks. You keep access until the end of the month you paid for.</p>
        </div>
        <div>
          <h3 className="font-semibold text-ink-900">Who processes payments?</h3>
          <p className="mt-1">Lemon Squeezy, our merchant of record, handles payment, sales tax and invoices.</p>
        </div>
        <div>
          <h3 className="font-semibold text-ink-900">Managing many properties?</h3>
          <p className="mt-1">
            The price is the same however many you manage. Questions? Email <a href={`mailto:${SUPPORT_EMAIL}`} className="underline">{SUPPORT_EMAIL}</a>.
          </p>
        </div>
      </div>
    </section>
  );
}
