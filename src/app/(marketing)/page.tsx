import Image from "next/image";
import Link from "next/link";
import { Icon, type IconName } from "@/components/icons";
import { Alert, buttonClass } from "@/components/ui";
import { TRIAL_DAYS } from "@/lib/billing";
import { APP_NAME, PRICE_MONTHLY_USD } from "@/lib/brand";
import { firstParam } from "@/lib/search-params";

const HERO_POINTS = ["Built for Airbnb transaction exports", "PDF, CSV, email and owner portal", "Any fee split, any money flow"];

const PAINS = [
  { title: "Payouts don’t match owners", body: "Airbnb pays out per listing, not per owner, and its API doesn’t expose co-host splits you can download." },
  { title: "Spreadsheets break quietly", body: "One date change, refund or damage claim and the formulas stop adding up — usually after the owner noticed." },
  { title: "Owners ask for proof", body: "“Where does this number come from?” means rebuilding the month by hand, line by line." },
];

const STEPS = [
  { title: "Export from Airbnb", body: "Download your transaction history CSV from Airbnb’s earnings page. No Airbnb password is ever shared.", icon: "upload" },
  { title: "Set each owner’s deal once", body: "Commission on payout or gross, cleaning fees, flat and monthly fees, and who receives the money.", icon: "settings" },
  { title: "Send the statements", body: "Every owner gets a clear PDF by email and a private page with all their statements.", icon: "statement" },
] satisfies { title: string; body: string; icon: IconName }[];

const FEATURES: { title: string; body: string; icon: IconName }[] = [
  { title: "Safe Airbnb imports", body: "Old and new column names, date formats detected, and a row imported twice is never counted twice.", icon: "upload" },
  { title: "Any fee structure", body: "Percent of payout or gross, with or without cleaning, plus per-booking and monthly fees — per property.", icon: "settings" },
  { title: "Who owes whom", body: "Whether you collect the payouts, the owner does, or Airbnb splits them, the balance is always explicit.", icon: "card" },
  { title: "Expenses & reimbursements", body: "Log cleaning, supplies and repairs, and mark what you paid so it’s reimbursed on the statement.", icon: "receipt" },
  { title: "PDF, CSV and email", body: "Professional PDF statements, a CSV for the accountant, and one click to email every owner.", icon: "statement" },
  { title: "Owner portal", body: "A private link where owners see every statement you sent. Fewer “can you resend March?” emails.", icon: "users" },
  { title: "Direct & VRBO bookings", body: "Add bookings from other channels by hand so each statement covers the whole month.", icon: "calendar" },
  { title: "Year-end ready", body: "An annual summary per owner, with the 2026 Form 1099 threshold flagged for tax season.", icon: "chart" },
];

const COMPARISON: [string, string, string][] = [
  ["Import Airbnb transactions", "Copy and paste, by hand", "Upload the CSV, duplicates skipped"],
  ["Commission per owner", "A formula per sheet", "One rule per property"],
  ["Refunds and damage claims", "Easy to miss", "Placed in the right month automatically"],
  ["Statement for the owner", "Export and format yourself", "PDF, CSV and email in one click"],
  ["Owner access to history", "Search your sent emails", "Private owner portal"],
  ["Year-end totals", "Rebuild twelve months", "Annual summary per owner"],
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
    a: "Yes. Add them on the Bookings page and they appear on the owner’s statement with their channel.",
  },
  {
    q: "Do my owners need an account?",
    a: "No. They receive the PDF by email and can open a private link with all their statements — no login.",
  },
  {
    q: "What happens after the free trial?",
    a: `Your trial lasts ${TRIAL_DAYS} days with no card. Subscribe for $${PRICE_MONTHLY_USD}/month to continue; cancel any time from the billing page.`,
  },
  {
    q: "Is my data safe?",
    a: "Your data is only visible to your account. Passwords are hashed, sessions are secured, and you can delete your account and all its data at any time.",
  },
];

function SectionHeading({ eyebrow, title, body }: { eyebrow: string; title: string; body?: string }) {
  return (
    <div className="mx-auto max-w-2xl text-center">
      <p className="text-sm font-semibold tracking-wide text-brand-700 uppercase">{eyebrow}</p>
      <h2 className="mt-2 text-3xl font-bold tracking-tight text-slate-900 md:text-4xl">{title}</h2>
      {body ? <p className="mt-4 text-lg text-slate-600">{body}</p> : null}
    </div>
  );
}

export default async function HomePage({ searchParams }: PageProps<"/">) {
  const deleted = firstParam(await searchParams, "account") === "deleted";

  return (
    <>
      {deleted ? (
        <div className="mx-auto max-w-6xl px-4 pt-6 md:px-8">
          <Alert tone="info">Your account and all of its data have been deleted.</Alert>
        </div>
      ) : null}

      {/* Hero */}
      <section className="relative overflow-hidden">
        <div aria-hidden className="absolute inset-0 -z-10 bg-[radial-gradient(60rem_30rem_at_70%_-10%,#d7f2ea,transparent)]" />
        <div className="mx-auto grid max-w-6xl items-center gap-12 px-4 pt-16 pb-20 md:px-8 lg:grid-cols-[1fr_1.1fr] lg:pt-24">
          <div>
            <p className="inline-flex items-center gap-2 rounded-full border border-brand-100 bg-white px-3 py-1 text-xs font-medium text-brand-700">
              For Airbnb co-hosts & small property managers
            </p>
            <h1 className="mt-5 text-4xl font-bold tracking-tight text-slate-900 md:text-6xl">Owner statements in minutes, not evenings.</h1>
            <p className="mt-6 text-lg text-slate-600">
              {APP_NAME} turns your Airbnb export into a clear monthly statement for every owner: bookings, your commission, expenses and
              exactly who owes whom.
            </p>
            <ul className="mt-6 space-y-2 text-slate-700">
              {HERO_POINTS.map((point) => (
                <li key={point} className="flex items-center gap-2">
                  <Icon name="check" className="size-5 text-brand-600" />
                  {point}
                </li>
              ))}
            </ul>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link href="/signup" className={`${buttonClass("primary")} px-6 py-3 text-base`}>
                Start your {TRIAL_DAYS}-day free trial
              </Link>
              <Link href="#how-it-works" className={`${buttonClass("secondary")} px-6 py-3 text-base`}>
                See how it works
              </Link>
            </div>
            <p className="mt-3 text-sm text-slate-500">No credit card required · ${PRICE_MONTHLY_USD}/month after · unlimited properties</p>
          </div>
          <div className="rounded-2xl border border-slate-200 bg-white p-2 shadow-2xl shadow-brand-800/10">
            <div className="flex items-center gap-1.5 px-2 pt-1 pb-2" aria-hidden>
              <span className="size-2.5 rounded-full bg-slate-200" />
              <span className="size-2.5 rounded-full bg-slate-200" />
              <span className="size-2.5 rounded-full bg-slate-200" />
            </div>
            <Image
              src="/marketing/statement.png"
              alt="An owner's monthly statement: payouts, co-host fees, expenses and the balance due to the owner"
              width={1280}
              height={960}
              priority
              className="h-auto w-full rounded-lg border border-slate-100"
            />
          </div>
        </div>
      </section>

      {/* Problem */}
      <section className="border-y border-slate-100 bg-slate-50">
        <div className="mx-auto max-w-6xl px-4 py-20 md:px-8">
          <SectionHeading eyebrow="The month-end problem" title="Still doing owner payouts in a spreadsheet?" />
          <div className="mt-12 grid gap-5 md:grid-cols-3">
            {PAINS.map((pain) => (
              <div key={pain.title} className="rounded-2xl border border-slate-200 bg-white p-6">
                <h3 className="font-semibold text-slate-900">{pain.title}</h3>
                <p className="mt-2 text-slate-600">{pain.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How it works */}
      <section id="how-it-works" className="mx-auto max-w-6xl scroll-mt-20 px-4 py-20 md:px-8">
        <SectionHeading eyebrow="How it works" title="From Airbnb export to sent statements" body="Set up once, then each month takes a few minutes." />
        <ol className="mt-12 grid gap-8 md:grid-cols-3">
          {STEPS.map((step, i) => (
            <li key={step.title} className="relative rounded-2xl border border-slate-200 p-6">
              <div className="flex items-center gap-3">
                <span className="grid size-10 place-items-center rounded-xl bg-brand-50 text-brand-700">
                  <Icon name={step.icon} />
                </span>
                <span className="text-sm font-semibold text-slate-400">Step {i + 1}</span>
              </div>
              <h3 className="mt-5 text-lg font-semibold text-slate-900">{step.title}</h3>
              <p className="mt-2 text-slate-600">{step.body}</p>
            </li>
          ))}
        </ol>
      </section>

      {/* Features */}
      <section id="features" className="scroll-mt-20 border-y border-slate-100 bg-slate-50">
        <div className="mx-auto max-w-6xl px-4 py-20 md:px-8">
          <SectionHeading eyebrow="Features" title="Everything a co-host needs at month end" />
          <div className="mt-12 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {FEATURES.map((f) => (
              <div key={f.title} className="rounded-2xl border border-slate-200 bg-white p-6">
                <span className="grid size-10 place-items-center rounded-xl bg-brand-50 text-brand-700">
                  <Icon name={f.icon} />
                </span>
                <h3 className="mt-4 font-semibold text-slate-900">{f.title}</h3>
                <p className="mt-2 text-sm text-slate-600">{f.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Comparison */}
      <section className="mx-auto max-w-5xl px-4 py-20 md:px-8">
        <SectionHeading eyebrow="Why switch" title="Spreadsheet vs. CoHost Ledger" />
        <div className="mt-12 overflow-x-auto rounded-2xl border border-slate-200">
          <table className="w-full min-w-[36rem] text-left text-sm">
            <thead className="bg-slate-50 text-slate-500">
              <tr>
                <th scope="col" className="px-5 py-3 font-semibold">
                  Task
                </th>
                <th scope="col" className="px-5 py-3 font-semibold">
                  Spreadsheet
                </th>
                <th scope="col" className="px-5 py-3 font-semibold text-brand-700">
                  {APP_NAME}
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {COMPARISON.map(([task, before, after]) => (
                <tr key={task}>
                  <th scope="row" className="px-5 py-4 font-medium text-slate-900">
                    {task}
                  </th>
                  <td className="px-5 py-4 text-slate-500">{before}</td>
                  <td className="px-5 py-4 text-slate-900">
                    <span className="inline-flex items-center gap-2">
                      <Icon name="check" className="size-4 shrink-0 text-brand-600" />
                      {after}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* Pricing band */}
      <section className="mx-auto max-w-6xl px-4 pb-20 md:px-8">
        <div className="grid items-center gap-8 rounded-3xl bg-brand-800 px-6 py-12 text-white md:grid-cols-2 md:px-12">
          <div>
            <h2 className="text-3xl font-bold">One simple price</h2>
            <p className="mt-3 text-lg text-brand-100">
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

      {/* FAQ */}
      <section id="faq" className="scroll-mt-20 border-t border-slate-100 bg-slate-50">
        <div className="mx-auto max-w-3xl px-4 py-20 md:px-8">
          <SectionHeading eyebrow="FAQ" title="Questions" />
          <div className="mt-10 divide-y divide-slate-200 rounded-2xl border border-slate-200 bg-white">
            {FAQ.map((item) => (
              <details key={item.q} className="group px-6 py-5">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 font-medium text-slate-900 [&::-webkit-details-marker]:hidden">
                  {item.q}
                  <span aria-hidden className="text-xl leading-none text-brand-600 transition-transform group-open:rotate-45">
                    +
                  </span>
                </summary>
                <p className="mt-3 text-slate-600">{item.a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
