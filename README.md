# CoHost Ledger

Owner statements and payout splits for Airbnb co-hosts — a complete SaaS with sign-up, a free trial and monthly billing.

Co-hosts manage Airbnb listings for property owners and keep 10–25% of the revenue. Every month they have to work out,
per owner, what each booking earned, their own fee, which expenses to reimburse and who owes whom — usually in a
spreadsheet, because Airbnb does not expose co-host payout splits through its API and full property-management suites
charge per listing. CoHost Ledger turns Airbnb's transaction export into ready-to-send owner statements.

> _CoHost Ledger_ is a working name. Product name, company name, support email and displayed price live in
> [`src/lib/brand.ts`](src/lib/brand.ts).

## Features

**For the co-host (the paying customer)**

- Sign up with a 14-day free trial (no card), log in, reset a forgotten password by email, change email or password,
  delete the account and all its data.
- **Import Airbnb's CSV** (Earnings → Transaction history → Export CSV). Columns are matched by name, US and European date
  formats are detected, bad rows are reported, re-importing never duplicates anything, and imports can be undone.
- **Direct, VRBO and other bookings** entered by hand, and a Bookings page listing every line per month.
- **Properties and owners.** Each Airbnb listing becomes a property (renamed listings can be linked back); each property
  belongs to an owner. Properties can be deleted.
- **Fee rules per property:** a percentage of the payout or of gross revenue, with or without the cleaning fee, cleaning
  fees kept by the co-host, a flat fee per booking, a monthly management fee.
- **Three money flows** decide the settlement: the co-host collects the payouts, the owner collects them, or Airbnb splits them.
- **Expenses** per property, paid by the co-host (reimbursed) or by the owner.
- **Monthly owner statements** in the browser, as PDF and as CSV; email them one by one or all at once (with a personal note,
  from the co-host's business name, replies going to the co-host). The app records what was sent and flags statements whose
  figures changed afterwards.
- **Annual summary** per owner with the Form 1099 threshold ($2,000 for payments made in 2026).
- **Billing page** with Lemon Squeezy checkout and customer portal; access pauses when a trial or subscription ends and
  comes back as soon as the co-host subscribes.

**For the owner**

- A private, revocable **portal link** (no login) showing every statement that was sent to them, with PDF downloads.

**For you, the operator**

- Marketing site: landing page, pricing, terms of service, privacy policy, sitemap and robots.txt.
- Security: scrypt password hashing, database sessions stored as token hashes in httpOnly cookies, rate limiting on
  login, sign-up and password resets, per-workspace data isolation, signed billing webhooks, security headers.
- Health check at `/api/health` for uptime monitoring.

Bookings count in the month of check-in (or of the payout — a setting). Refunds, alterations and damage payouts count in
the month they happen, so a statement already sent is not rewritten by a later refund.

## Run it locally

Requirements: Node.js 20.9 or newer.

```bash
npm install
npm run dev
```

Open http://localhost:3000, click **Start free trial**, then on **Import from Airbnb** click **Try the sample file**
([`public/samples/airbnb-transaction-history-sample.csv`](public/samples/airbnb-transaction-history-sample.csv)).
Add an owner, assign properties on **Properties**, and open **Owner statements** for August 2026.

Locally no configuration is needed: data lives in an embedded Postgres ([PGlite](https://pglite.dev)) under `.data/`,
emails are printed in the terminal instead of being sent (password-reset links included), and billing is off so every
feature is unlocked. Stop `npm run dev` before opening the same `.data/` folder from another process.

## Scripts

| Command               | What it does                                                        |
| --------------------- | ------------------------------------------------------------------- |
| `npm run dev`         | Development server                                                  |
| `npm test`            | Unit and database tests (Vitest, in-memory PGlite)                  |
| `npm run test:e2e`    | Browser tests (Playwright) against a production build — run `npm run build` first |
| `npm run typecheck`   | TypeScript check                                                    |
| `npm run lint`        | ESLint                                                              |
| `npm run build`       | Production build                                                    |
| `npm run db:generate` | Create a SQL migration after changing `src/server/db/schema.ts`     |
| `npm run db:migrate`  | Apply migrations to the Postgres database in `DATABASE_URL`         |

GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs all of them on every push and pull request,
with the browser tests against both the embedded database and a real Postgres.

## Launch checklist

Everything below is configuration in outside services; no code changes are needed.

1. **Name and details.** Edit [`src/lib/brand.ts`](src/lib/brand.ts): product name, company name, support email, price.
   Read the [terms](src/app/(marketing)/terms/page.tsx) and [privacy policy](src/app/(marketing)/privacy/page.tsx) and have
   them reviewed for your country and company.
2. **Database.** Create a Postgres database (for example [Neon](https://neon.tech), free tier). Copy its _pooled_
   connection string.
3. **Email.** Create a [Resend](https://resend.com) account, verify your sending domain, create an API key.
4. **Payments.** Create a [Lemon Squeezy](https://lemonsqueezy.com) store (check that payouts to your country are
   supported on their _Supported countries_ page). Create a product with a monthly subscription variant priced like
   `PRICE_MONTHLY_USD`. Note the store ID and variant ID and create an API key.
5. **Deploy.** Import the repository in [Vercel](https://vercel.com) and set the environment variables from
   [`.env.example`](.env.example): `APP_URL` (your domain), `DATABASE_URL`, `RESEND_API_KEY`, `EMAIL_FROM`, and the four
   `LEMONSQUEEZY_*` values. The `vercel-build` script applies database migrations before each build.
6. **Webhook.** In Lemon Squeezy → Settings → Webhooks, add `https://YOUR-DOMAIN/api/webhooks/lemonsqueezy` with the
   signing secret from `LEMONSQUEEZY_WEBHOOK_SECRET` and these events: `subscription_created`, `subscription_updated`,
   `subscription_cancelled`, `subscription_resumed`, `subscription_expired`, `subscription_paused`, `subscription_unpaused`.
7. **Test a purchase** in Lemon Squeezy test mode: sign up, subscribe from Billing, check the status turns to
   _Subscribed_, open _Manage subscription_, cancel.
8. **Monitoring.** Point an uptime monitor (e.g. Better Stack, UptimeRobot) at `https://YOUR-DOMAIN/api/health`.
9. **Real data.** Import a real Airbnb export from a co-host (guest names can be removed first) and compare one month
   with their spreadsheet before you start selling.

Any Node.js host works too (`npm run build && npm run start` behind HTTPS, with the same variables); run
`npm run db:migrate` before starting a new version.

## How the code is organized

```
src/lib/                   Pure domain logic, no database (fully unit-tested)
  airbnb/parse.ts          Airbnb transaction CSV reader
  commission.ts            Fee rules per booking line
  statement.ts             Owner statement builder and settlement per money flow
  statement-csv.ts         CSV export
  pdf/statement-pdf.ts     PDF rendering (pdf-lib, standard fonts)
  billing.ts               Trial/subscription access rules, webhook parsing
  money.ts, dates.ts       Integer-cent money and time-zone-free dates
src/server/                Data access (Drizzle ORM), auth, billing, email
  db/schema.ts             Tables; every business row carries a workspace id
  auth/                    Password hashing, sessions, rate limiting, accounts
  context.ts               Current user and workspace for each request, access checks
  actions/                 Server actions with input validation (zod)
src/app/(marketing)/       Landing, pricing, terms, privacy
src/app/(auth)/            Log in, sign up, password reset
src/app/(app)/             The signed-in app
src/app/o/[token]/         Owner portal
src/app/api/               Billing webhook and health check
src/proxy.ts               Redirects signed-out visitors to the login page
e2e/                       Playwright browser tests
drizzle/                   SQL migrations
```

Money is stored as integer cents and dates as ISO calendar dates (`2026-08-14`), so totals never drift and months never
shift with time zones.

## Known limitations

- The Airbnb CSV layout is not documented by Airbnb; the importer accepts the known header variants and reports anything
  it cannot read. Transaction types it does not recognize (for example co-host payout lines) appear on statements without a
  fee and are listed in the import preview.
- Statements use each property's current fee settings; changing a rule changes past months too (the app then flags sent
  statements as changed).
- A statement assumes one currency and warns when lines mix several.
- PDFs use the built-in PDF fonts: accented Latin names print correctly, other scripts (e.g. Chinese) print as `?`.
- One login per business; team members sharing an account would share a password.
