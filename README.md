# CoHost Ledger

Owner statements and payout splits for Airbnb co-hosts.

Co-hosts manage Airbnb listings for property owners and keep 10–25% of the revenue. Every month they have to work out,
per owner, what each booking earned, what their own fee is, which expenses to reimburse and who owes whom — usually in a
spreadsheet, because Airbnb does not expose co-host payout splits through its API and full property-management suites
charge per listing. CoHost Ledger turns Airbnb's transaction export into ready-to-send owner statements.

> _CoHost Ledger_ is a working name. Change it in [`src/lib/brand.ts`](src/lib/brand.ts).

## What it does today

- **Import Airbnb's CSV** (Earnings → Transaction history → Export CSV). Columns are matched by name, US and European date
  formats are detected, bad rows are reported, and re-importing the same file never duplicates anything. Imports can be undone.
- **Properties and owners.** Each Airbnb listing becomes a property (renamed listings can be linked to the same property);
  each property belongs to an owner.
- **Fee rules per property:** a percentage of the Airbnb payout or of gross revenue, with or without the cleaning fee,
  cleaning fees kept by the co-host, a flat fee per booking, and a monthly management fee.
- **Three money flows**, which decide the settlement:
  - _Co-host collects_ — Airbnb pays the co-host, who pays the owner the payout minus fees and expenses.
  - _Owner collects_ — Airbnb pays the owner, who pays the co-host's fees and expenses.
  - _Airbnb split_ — Airbnb pays the co-host's share directly; only expenses are settled.
- **Expenses** per property, marked as paid by the co-host (reimbursed) or by the owner.
- **Monthly owner statements** in the browser and as a PDF, with a per-owner overview of who owes whom.
- **Annual summary** per owner with a note on the Form 1099 threshold ($2,000 for payments made in 2026).

Bookings are counted in the month of check-in (or of the Airbnb payout — a setting). Refunds, alterations and damage
payouts count in the month they happen, so a statement that was already sent does not change later.

## Getting started

Requirements: Node.js 20.9 or newer.

```bash
npm install
npm run dev
```

Open http://localhost:3000, go to **Import from Airbnb** and click **Try the sample file**
([`public/samples/airbnb-transaction-history-sample.csv`](public/samples/airbnb-transaction-history-sample.csv)).
Then add an owner, assign properties on **Properties**, and open **Owner statements** for August 2026.

Locally the app stores its data in an embedded Postgres ([PGlite](https://pglite.dev)) under `.data/`, so no database
server is needed. Stop `npm run dev` before opening the same `.data/` folder from another process.

## Scripts

| Command               | What it does                                               |
| --------------------- | ---------------------------------------------------------- |
| `npm run dev`         | Development server                                         |
| `npm test`            | Unit and database tests (Vitest, in-memory PGlite)         |
| `npm run typecheck`   | TypeScript check                                           |
| `npm run lint`        | ESLint                                                     |
| `npm run build`       | Production build                                           |
| `npm run db:generate` | Create a SQL migration after changing `src/server/db/schema.ts` |
| `npm run db:migrate`  | Apply migrations to the Postgres database in `DATABASE_URL` |

## How the code is organized

```
src/lib/                 Pure domain logic, no database (fully unit-tested)
  airbnb/parse.ts        Airbnb transaction CSV reader
  commission.ts          Fee rules per booking line
  statement.ts           Owner statement builder and settlement per money flow
  pdf/statement-pdf.ts   PDF rendering (pdf-lib, standard fonts)
  money.ts, dates.ts     Integer-cent money and time-zone-free dates
src/server/              Data access (Drizzle ORM) and server actions
  db/schema.ts           Tables; every row carries a workspace id
  context.ts             Resolves the current workspace for each request
  actions/               Form handlers with input validation (zod)
src/app/                 Next.js App Router pages and the PDF route
drizzle/                 SQL migrations
```

Money is stored as integer cents and dates as ISO calendar dates (`2026-08-14`), so totals never drift and months never
shift with time zones.

## Deploying

Set `DATABASE_URL` to a Postgres database (for example Neon or Supabase), run `npm run db:migrate`, then deploy as a
standard Next.js app (for example on Vercel).

**There is no sign-in yet.** Everything lives in one workspace, so do not put the app on a public URL with real data
until accounts are added (next step below).

## Roadmap

1. **Accounts and subscriptions** — sign-in, one workspace per co-host business, a 14-day trial and monthly billing
   through a merchant of record such as Lemon Squeezy or Paddle (check that it supports payouts to your country).
2. **Send statements** — email the PDF to owners, a read-only owner portal, and locking a month once it is sent.
3. **More sources** — VRBO and Booking.com exports, direct bookings entered by hand, multiple currencies.
4. **Accounting exports** — QuickBooks/Xero CSV and year-end 1099 worksheets.

## Known limitations

- The Airbnb CSV layout is not documented by Airbnb; the importer accepts the known header variants and reports anything
  it cannot read. Real exports from different accounts should be tested before launch.
- Transaction types the importer does not recognize (for example co-host payout lines) appear on statements without a
  fee, and the import preview lists them; check them against a real export before relying on the totals.
- Statements use each property's current fee settings; changing a rule also changes past months.
- A statement assumes one currency and warns when an import mixes several.
- PDFs use the built-in PDF fonts: accented Latin names print correctly, other scripts (e.g. Chinese) print as `?`.
