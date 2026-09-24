import { computeLineFee, grossCents, NO_FEE, type FeeableLine, type LineFee } from "@/lib/commission";
import type { ReportPeriod } from "@/lib/dates";
import type { AttributionBasis, CommissionRule, ExpensePaidBy, PayoutFlow } from "@/lib/domain";

/**
 * Builds an owner statement: every booking, adjustment and expense of the
 * owner's properties in a period, the co-host's fees, and the balance one side
 * owes the other. Pure function so the maths can be tested without a database.
 */

export interface StatementOwner {
  id: string;
  name: string;
  email: string | null;
}

export interface StatementProperty {
  id: string;
  name: string;
  rule: CommissionRule;
  payoutFlow: PayoutFlow;
}

export interface StatementTransaction extends FeeableLine {
  id: string;
  propertyId: string;
  type: string;
  date: string;
  startDate: string | null;
  endDate: string | null;
  nights: number | null;
  guest: string;
  confirmationCode: string;
  details: string;
  currency: string;
}

export interface StatementExpense {
  id: string;
  propertyId: string;
  date: string;
  category: string;
  description: string;
  amountCents: number;
  paidBy: ExpensePaidBy;
}

export interface StatementInput {
  period: ReportPeriod;
  basis: AttributionBasis;
  owner: StatementOwner;
  properties: StatementProperty[];
  /** May include rows outside the period; they are filtered here. */
  transactions: StatementTransaction[];
  expenses: StatementExpense[];
  /** Confirmation codes whose per-booking flat fee was charged in an earlier period. */
  flatFeeChargedCodes?: ReadonlySet<string>;
}

export interface StatementLine {
  transaction: StatementTransaction;
  /** Date that placed the line in this period. */
  attributionDate: string;
  grossCents: number;
  fee: LineFee;
}

export interface StatementTotals {
  /** Distinct bookings (confirmation codes) among reservation lines. */
  bookings: number;
  nights: number;
  grossCents: number;
  serviceFeeCents: number;
  cleaningFeeCents: number;
  payoutCents: number;
  commissionCents: number;
  flatFeesCents: number;
  cleaningFeesToCohostCents: number;
  monthlyFeesCents: number;
  cohostFeesCents: number;
  reimbursableExpensesCents: number;
  ownerPaidExpensesCents: number;
  /** What the owner earned: payouts minus co-host fees minus all expenses. */
  ownerNetCents: number;
  /** Settlement. Positive: the co-host pays the owner. Negative: the owner pays the co-host. */
  balanceDueToOwnerCents: number;
}

export interface PropertyStatement {
  property: StatementProperty;
  lines: StatementLine[];
  expenses: StatementExpense[];
  totals: StatementTotals;
}

export interface OwnerStatement {
  period: ReportPeriod;
  basis: AttributionBasis;
  owner: StatementOwner;
  properties: PropertyStatement[];
  totals: StatementTotals;
  /** Currency of the statement lines; statements assume a single currency. */
  currency: string;
  /** More than one entry means the lines mix currencies and totals are not meaningful. */
  currencies: string[];
}

/**
 * Bookings land in the month of check-in (or of the Airbnb transaction, if the
 * co-host reports on a cash basis). Adjustments, refunds and damage payouts
 * always land in the month they happened, so statements already sent are not
 * rewritten by a refund that arrives later.
 */
export function attributionDate(tx: Pick<StatementTransaction, "kind" | "date" | "startDate">, basis: AttributionBasis): string {
  if (basis === "checkin" && tx.kind === "reservation") return tx.startDate ?? tx.date;
  return tx.date;
}

export function settlementForFlow(
  flow: PayoutFlow,
  amounts: { payoutCents: number; cohostFeesCents: number; reimbursableExpensesCents: number },
): number {
  switch (flow) {
    case "cohost_collects":
      return amounts.payoutCents - amounts.cohostFeesCents - amounts.reimbursableExpensesCents;
    case "owner_collects":
      return -(amounts.cohostFeesCents + amounts.reimbursableExpensesCents);
    case "airbnb_split":
      // Airbnb already paid the co-host's fee; only out-of-pocket expenses are owed.
      return -amounts.reimbursableExpensesCents;
  }
}

export function emptyTotals(): StatementTotals {
  return {
    bookings: 0,
    nights: 0,
    grossCents: 0,
    serviceFeeCents: 0,
    cleaningFeeCents: 0,
    payoutCents: 0,
    commissionCents: 0,
    flatFeesCents: 0,
    cleaningFeesToCohostCents: 0,
    monthlyFeesCents: 0,
    cohostFeesCents: 0,
    reimbursableExpensesCents: 0,
    ownerPaidExpensesCents: 0,
    ownerNetCents: 0,
    balanceDueToOwnerCents: 0,
  };
}

export function addTotals(a: StatementTotals, b: StatementTotals): StatementTotals {
  const sum = emptyTotals();
  for (const key of Object.keys(sum) as (keyof StatementTotals)[]) sum[key] = a[key] + b[key];
  return sum;
}

function inPeriod(date: string, period: ReportPeriod): boolean {
  return date >= period.start && date <= period.end;
}

function compareLines(a: StatementLine, b: StatementLine): number {
  return (
    a.attributionDate.localeCompare(b.attributionDate) ||
    a.transaction.date.localeCompare(b.transaction.date) ||
    a.transaction.id.localeCompare(b.transaction.id)
  );
}

export function buildOwnerStatement(input: StatementInput): OwnerStatement {
  const { period, basis } = input;
  const chargedCodes = new Set(input.flatFeeChargedCodes ?? []);
  const currencyCounts = new Map<string, number>();

  const properties = input.properties.map((property): PropertyStatement => {
    const candidates: StatementLine[] = input.transactions
      .filter((tx) => tx.propertyId === property.id)
      .map((tx) => ({ transaction: tx, attributionDate: attributionDate(tx, basis), grossCents: grossCents(tx), fee: NO_FEE }))
      .filter((line) => inPeriod(line.attributionDate, period))
      .sort(compareLines);

    const totals = emptyTotals();
    const bookings = new Set<string>();
    const lines = candidates.map((line): StatementLine => {
      const tx = line.transaction;
      // The flat fee is charged once per booking, on its first line.
      let chargeFlatFee = tx.kind === "reservation";
      if (chargeFlatFee && tx.confirmationCode) {
        chargeFlatFee = !chargedCodes.has(tx.confirmationCode);
        chargedCodes.add(tx.confirmationCode);
      }
      const fee = computeLineFee(tx, property.rule, { chargeFlatFee });

      if (tx.kind === "reservation") {
        bookings.add(tx.confirmationCode || `row:${tx.id}`);
        totals.nights += tx.nights ?? 0;
      }
      totals.grossCents += line.grossCents;
      totals.serviceFeeCents += tx.serviceFeeCents;
      totals.cleaningFeeCents += tx.cleaningFeeCents;
      totals.payoutCents += tx.amountCents;
      totals.commissionCents += fee.commissionCents;
      totals.flatFeesCents += fee.flatFeeCents;
      totals.cleaningFeesToCohostCents += fee.cleaningFeeCents;
      currencyCounts.set(tx.currency, (currencyCounts.get(tx.currency) ?? 0) + 1);
      return { ...line, fee };
    });

    const expenses = input.expenses
      .filter((e) => e.propertyId === property.id && inPeriod(e.date, period))
      .sort((a, b) => a.date.localeCompare(b.date) || a.id.localeCompare(b.id));
    for (const expense of expenses) {
      if (expense.paidBy === "cohost") totals.reimbursableExpensesCents += expense.amountCents;
      else totals.ownerPaidExpensesCents += expense.amountCents;
    }

    totals.bookings = bookings.size;
    totals.monthlyFeesCents = property.rule.monthlyFeeCents * period.months;
    totals.cohostFeesCents =
      totals.commissionCents + totals.flatFeesCents + totals.cleaningFeesToCohostCents + totals.monthlyFeesCents;
    totals.ownerNetCents =
      totals.payoutCents - totals.cohostFeesCents - totals.reimbursableExpensesCents - totals.ownerPaidExpensesCents;
    totals.balanceDueToOwnerCents = settlementForFlow(property.payoutFlow, totals);

    return { property, lines, expenses, totals };
  });

  const currencies = [...currencyCounts.entries()].sort((a, b) => b[1] - a[1]).map(([code]) => code);
  return {
    period,
    basis,
    owner: input.owner,
    properties,
    totals: properties.reduce((sum, p) => addTotals(sum, p.totals), emptyTotals()),
    currency: currencies[0] ?? "USD",
    currencies,
  };
}

export function hasActivity(statement: OwnerStatement): boolean {
  return statement.properties.some(
    (p) => p.lines.length > 0 || p.expenses.length > 0 || p.totals.monthlyFeesCents !== 0,
  );
}
