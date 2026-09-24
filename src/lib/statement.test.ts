import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { parseAirbnbCsv } from "./airbnb/parse";
import { monthPeriod, yearPeriod } from "./dates";
import type { CommissionRule } from "./domain";
import {
  attributionDate,
  buildOwnerStatement,
  hasActivity,
  settlementForFlow,
  type StatementExpense,
  type StatementInput,
  type StatementProperty,
  type StatementTransaction,
} from "./statement";

const baseRule: CommissionRule = {
  base: "payout",
  rateBps: 2000,
  excludeCleaningFee: true,
  cleaningFeeTo: "owner",
  flatFeePerReservationCents: 0,
  monthlyFeeCents: 0,
};

const loft: StatementProperty = { id: "A", name: "Loft", rule: baseRule, payoutFlow: "cohost_collects" };
const cabin: StatementProperty = {
  id: "B",
  name: "Cabin",
  rule: { ...baseRule, base: "gross", rateBps: 1500, excludeCleaningFee: false, flatFeePerReservationCents: 2500, monthlyFeeCents: 5000 },
  payoutFlow: "owner_collects",
};

let nextId = 0;
function tx(fields: Partial<StatementTransaction> & Pick<StatementTransaction, "propertyId" | "date">): StatementTransaction {
  return {
    id: `t${String(++nextId).padStart(3, "0")}`,
    kind: "reservation",
    type: "Reservation",
    startDate: null,
    endDate: null,
    nights: null,
    guest: "",
    confirmationCode: "",
    details: "",
    currency: "USD",
    amountCents: 0,
    grossEarningsCents: null,
    serviceFeeCents: 0,
    fastPayFeeCents: 0,
    cleaningFeeCents: 0,
    ...fields,
  };
}

const transactions: StatementTransaction[] = [
  // Loft, checked in Aug 30, paid Aug 31.
  tx({ propertyId: "A", date: "2026-08-31", startDate: "2026-08-30", nights: 4, confirmationCode: "AAA", amountCents: 97000, grossEarningsCents: 100000, serviceFeeCents: 3000, cleaningFeeCents: 10000 }),
  // Loft, September stay.
  tx({ propertyId: "A", date: "2026-09-03", startDate: "2026-09-02", nights: 2, confirmationCode: "BBB", amountCents: 48500, grossEarningsCents: 50000, serviceFeeCents: 1500, cleaningFeeCents: 10000 }),
  // Loft, refund in September for the August stay.
  tx({ propertyId: "A", date: "2026-09-05", startDate: "2026-08-30", kind: "adjustment", type: "Adjustment", confirmationCode: "AAA", amountCents: -5000, grossEarningsCents: -5155, serviceFeeCents: -155 }),
  // Loft, checked in July 31 but paid out August 1.
  tx({ propertyId: "A", date: "2026-08-01", startDate: "2026-07-31", nights: 1, confirmationCode: "EEE", amountCents: 20000, grossEarningsCents: 20619, serviceFeeCents: 619, cleaningFeeCents: 5000 }),
  // Cabin, August stay.
  tx({ propertyId: "B", date: "2026-08-11", startDate: "2026-08-10", nights: 3, confirmationCode: "CCC", amountCents: 77600, grossEarningsCents: 80000, serviceFeeCents: 2400, cleaningFeeCents: 6000 }),
  // Cabin, July stay.
  tx({ propertyId: "B", date: "2026-07-29", startDate: "2026-07-28", nights: 2, confirmationCode: "DDD", amountCents: 30000, grossEarningsCents: 30928, serviceFeeCents: 928 }),
  // Cabin, damage reimbursement in August.
  tx({ propertyId: "B", date: "2026-08-20", kind: "resolution", type: "Resolution Payout", details: "Broken lamp", amountCents: 15000 }),
];

const expenses: StatementExpense[] = [
  { id: "e1", propertyId: "A", date: "2026-08-15", category: "Supplies", description: "Coffee and soap", amountCents: 12000, paidBy: "cohost" },
  { id: "e2", propertyId: "B", date: "2026-08-05", category: "Repairs & maintenance", description: "Plumber", amountCents: 20000, paidBy: "owner" },
  { id: "e3", propertyId: "A", date: "2026-09-01", category: "Cleaning", description: "Deep clean", amountCents: 9000, paidBy: "cohost" },
];

function input(overrides: Partial<StatementInput> = {}): StatementInput {
  return {
    period: monthPeriod("2026-08"),
    basis: "checkin",
    owner: { id: "o1", name: "Dana Owner", email: "dana@example.com" },
    properties: [loft, cabin],
    transactions,
    expenses,
    ...overrides,
  };
}

describe("buildOwnerStatement", () => {
  it("builds an August statement by check-in date", () => {
    const statement = buildOwnerStatement(input());
    const [a, b] = statement.properties;

    expect(a.lines.map((l) => l.transaction.confirmationCode)).toEqual(["AAA"]);
    expect(a.lines[0].fee.commissionCents).toBe(17400); // 20% of (97,000 − 10,000)
    expect(a.expenses.map((e) => e.id)).toEqual(["e1"]);
    expect(a.totals).toMatchObject({
      bookings: 1,
      nights: 4,
      payoutCents: 97000,
      cohostFeesCents: 17400,
      reimbursableExpensesCents: 12000,
      balanceDueToOwnerCents: 67600, // co-host collected, pays the owner
    });

    expect(b.lines.map((l) => l.transaction.kind)).toEqual(["reservation", "resolution"]);
    expect(b.lines.map((l) => l.fee.totalCents)).toEqual([14500, 0]); // 15% of 80,000 + $25 flat
    expect(b.totals).toMatchObject({
      payoutCents: 92600,
      commissionCents: 12000,
      flatFeesCents: 2500,
      monthlyFeesCents: 5000,
      cohostFeesCents: 19500,
      ownerPaidExpensesCents: 20000,
      balanceDueToOwnerCents: -19500, // owner collected, owes the co-host
    });

    expect(statement.totals).toMatchObject({
      bookings: 2,
      nights: 7,
      payoutCents: 189600,
      cohostFeesCents: 36900,
      reimbursableExpensesCents: 12000,
      ownerPaidExpensesCents: 20000,
      ownerNetCents: 120700,
      balanceDueToOwnerCents: 48100,
    });
    expect(statement.currency).toBe("USD");
    expect(statement.currencies).toEqual(["USD"]);
    expect(hasActivity(statement)).toBe(true);
  });

  it("counts bookings by payout date on a cash basis", () => {
    const statement = buildOwnerStatement(input({ basis: "payout_date" }));
    expect(statement.properties[0].lines.map((l) => l.transaction.confirmationCode)).toEqual(["EEE", "AAA"]);
  });

  it("keeps later refunds out of the month already reported", () => {
    const september = buildOwnerStatement(input({ period: monthPeriod("2026-09") }));
    const loftLines = september.properties[0].lines;
    expect(loftLines.map((l) => [l.transaction.kind, l.transaction.confirmationCode])).toEqual([
      ["reservation", "BBB"],
      ["adjustment", "AAA"],
    ]);
    expect(loftLines[1].fee.commissionCents).toBe(-1000);
  });

  it("charges the flat fee once per booking, including across periods", () => {
    const monthly = [
      tx({ propertyId: "B", date: "2026-08-02", startDate: "2026-08-01", nights: 30, confirmationCode: "MONTH", amountCents: 100000, grossEarningsCents: 103093, serviceFeeCents: 3093 }),
      tx({ propertyId: "B", date: "2026-08-30", startDate: "2026-08-01", confirmationCode: "MONTH", amountCents: 100000, grossEarningsCents: 103093, serviceFeeCents: 3093 }),
    ];
    const once = buildOwnerStatement(input({ properties: [cabin], transactions: monthly }));
    expect(once.properties[0].lines.map((l) => l.fee.flatFeeCents)).toEqual([2500, 0]);
    expect(once.totals.bookings).toBe(1);

    const already = buildOwnerStatement(input({ properties: [cabin], transactions: monthly, flatFeeChargedCodes: new Set(["MONTH"]) }));
    expect(already.totals.flatFeesCents).toBe(0);
  });

  it("charges monthly fees once per month in the period", () => {
    const year = buildOwnerStatement(input({ period: yearPeriod(2026), properties: [cabin] }));
    expect(year.totals.monthlyFeesCents).toBe(60000);
  });

  it("lists properties without activity and reports none", () => {
    const quiet = buildOwnerStatement(input({ period: monthPeriod("2026-03"), properties: [loft] }));
    expect(quiet.properties).toHaveLength(1);
    expect(quiet.properties[0].lines).toEqual([]);
    expect(hasActivity(quiet)).toBe(false);
  });

  it("flags mixed currencies", () => {
    const mixed = [
      tx({ propertyId: "A", date: "2026-08-10", startDate: "2026-08-09", amountCents: 1000 }),
      tx({ propertyId: "A", date: "2026-08-11", startDate: "2026-08-10", amountCents: 1000, currency: "EUR" }),
      tx({ propertyId: "A", date: "2026-08-12", startDate: "2026-08-11", amountCents: 1000, currency: "EUR" }),
    ];
    const statement = buildOwnerStatement(input({ transactions: mixed, properties: [loft] }));
    expect(statement.currency).toBe("EUR");
    expect(statement.currencies).toEqual(["EUR", "USD"]);
  });
});

describe("settlementForFlow", () => {
  const amounts = { payoutCents: 100000, cohostFeesCents: 20000, reimbursableExpensesCents: 5000 };
  it("works out who owes whom", () => {
    expect(settlementForFlow("cohost_collects", amounts)).toBe(75000);
    expect(settlementForFlow("owner_collects", amounts)).toBe(-25000);
    expect(settlementForFlow("airbnb_split", amounts)).toBe(-5000);
  });
});

describe("attributionDate", () => {
  it("uses check-in for bookings and the transaction date for everything else", () => {
    expect(attributionDate({ kind: "reservation", date: "2026-08-01", startDate: "2026-07-31" }, "checkin")).toBe("2026-07-31");
    expect(attributionDate({ kind: "reservation", date: "2026-08-01", startDate: null }, "checkin")).toBe("2026-08-01");
    expect(attributionDate({ kind: "adjustment", date: "2026-09-05", startDate: "2026-08-30" }, "checkin")).toBe("2026-09-05");
    expect(attributionDate({ kind: "reservation", date: "2026-08-01", startDate: "2026-07-31" }, "payout_date")).toBe("2026-08-01");
  });
});

describe("statement from the sample Airbnb export", () => {
  it("matches a hand-checked August statement", () => {
    const text = readFileSync(path.join(process.cwd(), "public/samples/airbnb-transaction-history-sample.csv"), "utf8");
    const result = parseAirbnbCsv(text);
    if (!result.ok) throw new Error(result.error);
    const propertyIds: Record<string, string> = { "Sunny Loft Downtown": "loft", "Lakeview Cabin": "cabin" };
    const rows = result.transactions
      .filter((t) => t.kind !== "payout" && t.kind !== "tax" && propertyIds[t.listing])
      .map((t, i) => ({ ...t, id: `s${i}`, propertyId: propertyIds[t.listing] }));

    const statement = buildOwnerStatement({
      period: monthPeriod("2026-08"),
      basis: "checkin",
      owner: { id: "o1", name: "Owner", email: null },
      properties: [
        { id: "loft", name: "Sunny Loft Downtown", rule: baseRule, payoutFlow: "cohost_collects" },
        { id: "cabin", name: "Lakeview Cabin", rule: baseRule, payoutFlow: "cohost_collects" },
      ],
      transactions: rows,
      expenses: [],
    });

    // Loft: 504.40 + 645.05 + 785.70; commission 20% of those minus $85 cleaning each = 336.03
    // Cabin: 931.20 + 727.50; commission 20% of those minus $120 cleaning each = 283.74
    expect(statement.properties.map((p) => p.totals.payoutCents)).toEqual([193515, 165870]);
    expect(statement.properties.map((p) => p.totals.commissionCents)).toEqual([33603, 28374]);
    expect(statement.totals).toMatchObject({ bookings: 5, nights: 19, payoutCents: 359385, cohostFeesCents: 61977, balanceDueToOwnerCents: 297408 });
  });
});
