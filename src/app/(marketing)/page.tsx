import Image from "next/image";
import Link from "next/link";
import { Alert, buttonClass } from "@/components/ui";
import { TRIAL_DAYS } from "@/lib/billing";
import { APP_NAME, PRICE_MONTHLY_USD } from "@/lib/brand";
import { firstParam } from "@/lib/search-params";

const PAINS = [
  "Airbnb pays out per listing, not per owner, and doesn’t expose co-host splits anywhere you can download.",
  "One date change or refund and the spreadsheet formulas quietly break.",
  "Owners ask “where does this number come from?” and you rebuild the month by hand.",
];

const STEPS = [
  { title: "Export from Airbnb", body: "Download your transaction history CSV from Airbnb’s earnings page. No Airbnb password shared, ever." },
  { title: "Set each owner’s deal once", body: "Commission on payout or gross, cleaning fees, flat and monthly fees, and who receives the money." },
  { title: "Send the statements", body: "Every owner gets a clear PDF by email and a private page with all their statements." },
];

const FEATURES = [
  { title: "Safe Airbnb imports", body: "Reads Airbnb’s transaction CSV, old and new column names alike, detects date formats, and never double-counts a row you import twice." },
  { title: "Any fee structure", body: "Percent of payout or gross, with or without cleaning fees, per-booking and monthly fees, per property." },
  { title: "Who owes whom", body: "Works whether you collect the payouts, the owner does, or Airbnb splits them. The balance is always explicit." },
  { title: "Expenses and reimbursements", body: "Log cleaning, supplies and repairs, and mark what you paid so it is reimbursed on the statement." },
  { title: "PDF, CSV and email", body: "Professional PDF statements, a CSV for the accountant, and one click to email every owner." },
  { title: "Owner portal", body: "A private link where owners see every statement you sent them. Fewer “can you resend March?” emails." },
  { title: "Direct and VRBO bookings", body: "Add bookings from other channels by hand so each statement covers the whole month." },
  { title: "Year-end ready", body: "An annual summary per owner with the 2026 Form 1099 threshold flagged for tax season." },
];

const FAQ = [
  {
    q: "Do I need to connect my Airbnb account?",
    a: "No. You upload the transaction CSV that Airbnb lets every host export. We never ask for your Airbnb login.",
  },
  {
    q: "Does it work if the owner receives the Airbnb payouts?",
    a: "Yes. For each property you choose whether you collect the payouts, the owner does, or Airbnb splits them. Statements show the right balance in each case.",
  },
  {
    q: "Can I add bookings from VRBO or direct guests?",
    a: "Yes. Add them by hand on the Bookings page and they appear on the owner’s statement with their channel.",
  },
  {
    q: "What happens after the free trial?",
    a: `Your trial lasts ${TRIAL_DAYS} days with no card. Subscribe for $${PRICE_MONTHLY_USD}/month to continue; cancel any time from the billing page.`,
  },
  {
    q: "Is my data safe?",
    a: "Your data is only visible to your account. Passwords are hashed, sessions are secured, and you can delete your account and all data at any time.",
  },
];

export default async function HomePage({ searchParams }: PageProps<"/">) {
  const deleted = firstParam(await searchParams, "account") === "deleted";

  return (
    <>
      {deleted ? (
        <div className="mx-auto max-w-6xl px-4 pt-6 md:px-8">
          <Alert tone="info">Your account and all of its data have been deleted.</Alert>
        </div>
      ) : null}

      <section className="mx-auto grid max-w-6xl items-center gap-12 px-4 py-16 md:grid-cols-2 md:px-8 md:py-24">
        <div>
          <p className="text-sm font-semibold tracking-wide text-brand-700 uppercase">For Airbnb co-hosts and small property managers</p>
          <h1 className="mt-3 text-4xl font-bold tracking-tight text-slate-900 md:text-5xl">
            Owner statements in minutes, not evenings.
          </h1>
          <p className="mt-5 text-lg text-slate-600">
            {APP_NAME} turns your Airbnb export into a clear monthly statement for every owner: bookings, your commission, expenses and
            exactly who owes whom. PDF, email and an owner portal included.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/signup" className={`${buttonClass("primary")} px-6 py-3 text-base`}>
              Start your {TRIAL_DAYS}-day free trial
            </Link>
            <Link href="#how-it-works" className={`${buttonClass("secondary")} px-6 py-3 text-base`}>
              See how it works
            </Link>
          </div>
          <p className="mt-3 text-sm text-slate-500">No credit card required · ${PRICE_MONTHLY_USD}/month after, unlimited properties</p>
        </div>
        <div className="overflow-hidden rounded-xl border border-slate-200 shadow-xl">
          <Image
            src="/marketing/statement.png"
            alt="An owner's monthly statement: payouts, co-host fees, expenses and the balance due to the owner"
            width={1280}
            height={960}
            priority
            className="h-auto w-full"
          />
        </div>
      </section>

      <section className="bg-slate-50">
        <div className="mx-auto max-w-6xl px-4 py-16 md:px-8">
          <h2 className="text-2xl font-bold text-slate-900 md:text-3xl">Still doing owner payouts in a spreadsheet?</h2>
          <ul className="mt-6 grid gap-4 md:grid-cols-3">
            {PAINS.map((pain) => (
              <li key={pain} className="rounded-xl border border-slate-200 bg-white p-5 text-slate-700">
                {pain}
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section id="how-it-works" className="mx-auto max-w-6xl scroll-mt-8 px-4 py-16 md:px-8">
        <h2 className="text-2xl font-bold text-slate-900 md:text-3xl">How it works</h2>
        <ol className="mt-8 grid gap-6 md:grid-cols-3">
          {STEPS.map((step, i) => (
            <li key={step.title}>
              <span className="grid size-9 place-items-center rounded-full bg-brand-600 font-semibold text-white">{i + 1}</span>
              <h3 className="mt-4 text-lg font-semibold text-slate-900">{step.title}</h3>
              <p className="mt-2 text-slate-600">{step.body}</p>
            </li>
          ))}
        </ol>
      </section>

      <section id="features" className="scroll-mt-8 bg-slate-50">
        <div className="mx-auto max-w-6xl px-4 py-16 md:px-8">
          <h2 className="text-2xl font-bold text-slate-900 md:text-3xl">Everything a co-host needs at month end</h2>
          <div className="mt-8 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {FEATURES.map((f) => (
              <div key={f.title} className="rounded-xl border border-slate-200 bg-white p-5">
                <h3 className="font-semibold text-slate-900">{f.title}</h3>
                <p className="mt-2 text-sm text-slate-600">{f.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-4 py-16 md:px-8">
        <div className="grid items-center gap-8 rounded-2xl bg-brand-800 px-6 py-10 text-white md:grid-cols-2 md:px-12">
          <div>
            <h2 className="text-2xl font-bold md:text-3xl">One simple price</h2>
            <p className="mt-3 text-brand-100">
              ${PRICE_MONTHLY_USD} per month for your whole business. Unlimited owners and properties, no per-listing fees.
            </p>
          </div>
          <div className="flex flex-wrap gap-3 md:justify-end">
            <Link href="/signup" className="rounded-md bg-white px-6 py-3 font-semibold text-brand-800 hover:bg-brand-50">
              Start free trial
            </Link>
            <Link href="/pricing" className="rounded-md px-6 py-3 font-semibold text-white ring-1 ring-white/40 hover:bg-white/10">
              See pricing
            </Link>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-3xl px-4 pb-20 md:px-8">
        <h2 className="text-2xl font-bold text-slate-900 md:text-3xl">Questions</h2>
        <div className="mt-6 divide-y divide-slate-200 border-y border-slate-200">
          {FAQ.map((item) => (
            <details key={item.q} className="group py-4">
              <summary className="cursor-pointer list-none font-medium text-slate-900">
                <span className="mr-2 inline-block text-brand-600 transition-transform group-open:rotate-90">›</span>
                {item.q}
              </summary>
              <p className="mt-2 pl-5 text-slate-600">{item.a}</p>
            </details>
          ))}
        </div>
      </section>
    </>
  );
}
