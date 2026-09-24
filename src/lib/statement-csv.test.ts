import { describe, expect, it } from "vitest";
import { monthPeriod } from "./dates";
import { buildOwnerStatement } from "./statement";
import { statementToCsv } from "./statement-csv";

describe("statementToCsv", () => {
  it("writes bookings, expenses, fees and totals", () => {
    const statement = buildOwnerStatement({
      period: monthPeriod("2026-08"),
      basis: "checkin",
      owner: { id: "o1", name: "Dana, Smith", email: null },
      properties: [
        {
          id: "p1",
          name: 'Loft "Downtown"',
          payoutFlow: "cohost_collects",
          rule: { base: "payout", rateBps: 2000, excludeCleaningFee: true, cleaningFeeTo: "owner", flatFeePerReservationCents: 0, monthlyFeeCents: 5000 },
        },
      ],
      transactions: [
        {
          id: "t1",
          propertyId: "p1",
          kind: "reservation",
          type: "Reservation",
          date: "2026-08-04",
          startDate: "2026-08-03",
          endDate: "2026-08-06",
          nights: 3,
          guest: "=HYPERLINK(evil)",
          confirmationCode: "HM1",
          details: "",
          currency: "USD",
          channel: "Airbnb",
          amountCents: 50440,
          grossEarningsCents: 52000,
          serviceFeeCents: 1560,
          fastPayFeeCents: 0,
          cleaningFeeCents: 8500,
        },
      ],
      expenses: [{ id: "e1", propertyId: "p1", date: "2026-08-10", category: "Supplies", description: "Soap", amountCents: 1200, paidBy: "cohost" }],
    });

    const lines = statementToCsv(statement).replace(/^\ufeff/, "").trim().split("\r\n");
    expect(lines[0]).toMatch(/^Owner,Period,Property,Line,Date/);
    expect(lines[1]).toBe(
      `"Dana, Smith",2026-08,"Loft ""Downtown""",booking,2026-08-03,Airbnb,Reservation,'=HYPERLINK(evil),HM1,3,520.00,15.60,504.40,83.88,,`,
    );
    expect(lines[2]).toBe(`"Dana, Smith",2026-08,"Loft ""Downtown""",expense,2026-08-10,,Supplies,Soap,,,,,,,12.00,co-host`);
    expect(lines[3]).toContain("Monthly management fee");
    expect(lines.at(-1)).toBe("Balance due to owner,2026-08,,,,,,,,,,,358.52,,,");
  });
});
