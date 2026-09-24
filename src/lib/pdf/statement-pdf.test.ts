import { readFileSync } from "node:fs";
import path from "node:path";
import { PDFDocument } from "pdf-lib";
import { describe, expect, it } from "vitest";
import { parseAirbnbCsv } from "@/lib/airbnb/parse";
import { monthPeriod } from "@/lib/dates";
import type { CommissionRule } from "@/lib/domain";
import { buildOwnerStatement, type StatementTransaction } from "@/lib/statement";
import { renderStatementPdf } from "./statement-pdf";

const rule: CommissionRule = {
  base: "payout",
  rateBps: 2000,
  excludeCleaningFee: true,
  cleaningFeeTo: "owner",
  flatFeePerReservationCents: 2500,
  monthlyFeeCents: 10000,
};

const options = { businessName: "Harbor Co-Hosting", generatedOn: "2026-10-01", appName: "CoHost Ledger" };

function sampleTransactions(): StatementTransaction[] {
  const result = parseAirbnbCsv(readFileSync(path.join(process.cwd(), "public/samples/airbnb-transaction-history-sample.csv"), "utf8"));
  if (!result.ok) throw new Error(result.error);
  return result.transactions
    .filter((t) => t.kind !== "payout" && t.kind !== "tax")
    .map((t, i) => ({ ...t, id: `t${i}`, propertyId: t.listing }));
}

describe("renderStatementPdf", () => {
  it("renders a statement with accented and non-Latin guest names", async () => {
    const statement = buildOwnerStatement({
      period: monthPeriod("2026-09"),
      basis: "checkin",
      owner: { id: "o1", name: "Zoë Owner", email: "zoe@example.com" },
      properties: ["Sunny Loft Downtown", "Lakeview Cabin", "Beach Bungalow #2"].map((name) => ({
        id: name,
        name,
        rule,
        payoutFlow: "cohost_collects" as const,
      })),
      transactions: sampleTransactions(),
      expenses: [
        { id: "e1", propertyId: "Lakeview Cabin", date: "2026-09-12", category: "Repairs & maintenance", description: "Replace lamp — 2 bulbs", amountCents: 4599, paidBy: "cohost" },
      ],
    });
    expect(statement.properties[0].lines.some((l) => l.transaction.guest === "李伟")).toBe(true);

    const bytes = await renderStatementPdf(statement, options);
    expect(Buffer.from(bytes.subarray(0, 5)).toString()).toBe("%PDF-");

    const doc = await PDFDocument.load(bytes);
    expect(doc.getPageCount()).toBeGreaterThanOrEqual(1);
    expect(doc.getTitle()).toBe("Owner statement - Zoë Owner - September 2026");
  });

  it("flows long statements onto more pages", async () => {
    const many: StatementTransaction[] = Array.from({ length: 150 }, (_, i) => ({
      id: `r${i}`,
      propertyId: "p1",
      kind: "reservation",
      type: "Reservation",
      date: "2026-09-15",
      startDate: "2026-09-14",
      endDate: "2026-09-16",
      nights: 2,
      guest: `Guest number ${i} with a rather long name that must be truncated`,
      confirmationCode: `HM${i}`,
      details: "",
      currency: "USD",
      amountCents: 20000,
      grossEarningsCents: 20619,
      serviceFeeCents: 619,
      fastPayFeeCents: 0,
      cleaningFeeCents: 5000,
    }));
    const statement = buildOwnerStatement({
      period: monthPeriod("2026-09"),
      basis: "checkin",
      owner: { id: "o1", name: "Owner", email: null },
      properties: [{ id: "p1", name: "Busy Apartment", rule, payoutFlow: "owner_collects" }],
      transactions: many,
      expenses: [],
    });
    const doc = await PDFDocument.load(await renderStatementPdf(statement, options));
    expect(doc.getPageCount()).toBeGreaterThan(3);
  });
});
