import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { classifyTransactionType, parseAirbnbCsv, type AirbnbParseResult } from "./parse";

const SAMPLE = readFileSync(path.join(process.cwd(), "public/samples/airbnb-transaction-history-sample.csv"), "utf8");

function parsed(text: string, options?: Parameters<typeof parseAirbnbCsv>[1]) {
  const result: AirbnbParseResult = parseAirbnbCsv(text, options);
  if (!result.ok) throw new Error(`expected a successful parse, got: ${result.error}`);
  return result;
}

describe("parseAirbnbCsv on the sample export", () => {
  const result = parsed(SAMPLE);

  it("detects US dates and reads every row", () => {
    expect(result.dateOrder).toBe("MDY");
    expect(result.dateOrderSource).toBe("detected");
    expect(result.rowErrors).toEqual([]);
    expect(result.transactions).toHaveLength(29);
  });

  it("classifies each line", () => {
    const counts: Record<string, number> = {};
    for (const tx of result.transactions) counts[tx.kind] = (counts[tx.kind] ?? 0) + 1;
    expect(counts).toEqual({ reservation: 13, payout: 13, adjustment: 1, resolution: 1, tax: 1 });
  });

  it("maps reservation columns", () => {
    const emily = result.transactions.find((tx) => tx.confirmationCode === "HMSL8K2QXA")!;
    expect(emily).toMatchObject({
      row: 2,
      kind: "reservation",
      type: "Reservation",
      date: "2026-08-04",
      bookingDate: "2026-07-12",
      startDate: "2026-08-03",
      endDate: "2026-08-06",
      nights: 3,
      guest: "Emily Carter",
      listing: "Sunny Loft Downtown",
      currency: "USD",
      amountCents: 50440,
      paidOutCents: 0,
      serviceFeeCents: 1560,
      cleaningFeeCents: 8500,
      grossEarningsCents: 52000,
      occupancyTaxesCents: 6240,
    });
  });

  it("keeps the sign of refunds", () => {
    const refund = result.transactions.find((tx) => tx.kind === "adjustment")!;
    expect(refund).toMatchObject({ amountCents: -6000, serviceFeeCents: -186, grossEarningsCents: -6186, nights: null });
  });

  it("reads payouts and non-Latin guest names", () => {
    const payout = result.transactions.find((tx) => tx.kind === "payout" && tx.date === "2026-09-02")!;
    expect(payout.paidOutCents).toBe(148230);
    expect(result.transactions.some((tx) => tx.guest === "李伟")).toBe(true);
  });

  it("gives every line a stable, unique fingerprint", () => {
    const fingerprints = result.transactions.map((tx) => tx.fingerprint);
    expect(new Set(fingerprints).size).toBe(fingerprints.length);
    expect(parsed(SAMPLE).transactions.map((tx) => tx.fingerprint)).toEqual(fingerprints);
  });
});

describe("parseAirbnbCsv header handling", () => {
  it("accepts older header names", () => {
    const text = [
      '"Date","Type","Confirmation Code","Start Date","Nights","Guest","Listing","Details","Reference","Currency","Amount","Paid Out","Host Fee","Cleaning Fee"',
      '"07/15/2019","Reservation","HMOLD1","07/14/2019","2","Sam","Old Listing","","","USD","194.00","","6.00","40.00"',
    ].join("\n");
    const [tx] = parsed(text).transactions;
    expect(tx).toMatchObject({
      confirmationCode: "HMOLD1",
      startDate: "2019-07-14",
      serviceFeeCents: 600,
      cleaningFeeCents: 4000,
      grossEarningsCents: null,
    });
  });

  it("finds the header below a title line", () => {
    const text = "Airbnb earnings export\nDate,Type,Listing,Amount\n08/20/2026,Reservation,Loft,100.00\n";
    const result = parsed(text);
    expect(result.transactions[0]).toMatchObject({ row: 3, amountCents: 10000, listing: "Loft" });
  });

  it("rejects files that are not Airbnb exports", () => {
    const result = parseAirbnbCsv("name,email\nAna,ana@example.com\n");
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toMatch(/missing columns: Date, Type, Amount, Listing/);
    expect(parseAirbnbCsv("").ok).toBe(false);
  });
});

describe("parseAirbnbCsv dates", () => {
  const header = "Date,Type,Listing,Amount,Start date\n";

  it("detects day/month exports", () => {
    const result = parsed(`${header}15/08/2026,Reservation,Loft,100,14/08/2026\n`);
    expect(result.dateOrder).toBe("DMY");
    expect(result.transactions[0].date).toBe("2026-08-15");
  });

  it("assumes US order when every date is ambiguous, unless overridden", () => {
    const text = `${header}03/04/2026,Reservation,Loft,100,03/02/2026\n`;
    const assumed = parsed(text);
    expect(assumed.dateOrderSource).toBe("ambiguous");
    expect(assumed.transactions[0].date).toBe("2026-03-04");
    const overridden = parsed(text, { dateOrder: "DMY" });
    expect(overridden.dateOrderSource).toBe("override");
    expect(overridden.transactions[0].date).toBe("2026-04-03");
  });

  it("refuses files that mix date formats", () => {
    const result = parseAirbnbCsv(`${header}15/08/2026,Reservation,Loft,100,\n08/16/2026,Reservation,Loft,100,\n`);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toMatch(/mix month\/day and day\/month/);
  });
});

describe("parseAirbnbCsv row problems", () => {
  const header = "Date,Type,Confirmation code,Listing,Amount,Service fee,Gross earnings\n";

  it("reports bad rows and keeps the good ones", () => {
    const result = parsed(
      header +
        "08/20/2026,Reservation,HM1,Loft,abc,,\n" +
        "08/21/2026,Reservation,HM2,,100,,\n" +
        "08/22/2026,,HM3,Loft,100,,\n" +
        "not a date,Reservation,HM4,Loft,100,,\n" +
        "08/23/2026,Reservation,HM5,Loft,100,,\n",
    );
    expect(result.transactions.map((tx) => tx.confirmationCode)).toEqual(["HM5"]);
    expect(result.rowErrors).toEqual([
      { row: 2, message: 'Amount "abc" is not a valid amount.' },
      { row: 3, message: 'Missing listing name on a "Reservation" line.' },
      { row: 4, message: "Missing transaction type." },
      { row: 5, message: '"not a date" is not a date' },
    ]);
  });

  it("flips a service fee exported with the opposite sign", () => {
    const [tx] = parsed(`${header}08/20/2026,Reservation,HM1,Loft,97.00,-3.00,100.00\n`).transactions;
    expect(tx.serviceFeeCents).toBe(300);
  });

  it("keeps genuinely repeated lines apart but deduplicates re-imports", () => {
    const line = "08/20/2026,Adjustment,HM1,Loft,-10.00,,\n";
    const first = parsed(header + line + line).transactions.map((tx) => tx.fingerprint);
    expect(new Set(first).size).toBe(2);
    expect(parsed(header + line + line).transactions.map((tx) => tx.fingerprint)).toEqual(first);
  });

  it("ignores listing renames when fingerprinting", () => {
    const a = parsed(`${header}08/20/2026,Reservation,HM1,Old name,100,,\n`).transactions[0];
    const b = parsed(`${header}08/20/2026,Reservation,HM1,New name,100,,\n`).transactions[0];
    expect(a.fingerprint).toBe(b.fingerprint);
  });
});

describe("classifyTransactionType", () => {
  it.each([
    ["Reservation", "reservation"],
    ["Adjustment", "adjustment"],
    ["Reservation Alteration", "adjustment"],
    ["Resolution Payout", "resolution"],
    ["Resolution Adjustment", "resolution"],
    ["Payout", "payout"],
    ["Pass Through Tot", "tax"],
    ["Co-Host Payout", "other"],
    ["Cancellation Fee", "other"],
  ])("classifies %j as %s", (type, kind) => {
    expect(classifyTransactionType(type)).toBe(kind);
  });
});
