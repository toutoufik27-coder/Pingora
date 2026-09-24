import { createHash } from "node:crypto";
import { parseCsv } from "@/lib/csv";
import { detectDateOrder, parseDate, type DateOrder, type DateOrderDetection } from "@/lib/dates";
import type { TransactionKind } from "@/lib/domain";
import { parseMoney } from "@/lib/money";

/**
 * Reader for the CSV that Airbnb exports from Earnings → Transaction history
 * ("Completed payouts" or "Gross earnings"). Header names have changed over the
 * years ("Host Fee" became "Service fee", capitalization differs between
 * exports), so columns are matched by normalized aliases rather than position.
 */

type Field =
  | "date"
  | "type"
  | "confirmationCode"
  | "bookingDate"
  | "startDate"
  | "endDate"
  | "nights"
  | "guest"
  | "listing"
  | "details"
  | "referenceCode"
  | "currency"
  | "amount"
  | "paidOut"
  | "serviceFee"
  | "fastPayFee"
  | "cleaningFee"
  | "grossEarnings"
  | "occupancyTaxes";

const FIELD_ALIASES: Record<Field, readonly string[]> = {
  date: ["date", "transactiondate"],
  type: ["type", "transactiontype"],
  confirmationCode: ["confirmationcode", "confirmation"],
  bookingDate: ["bookingdate"],
  startDate: ["startdate", "checkin", "checkindate"],
  endDate: ["enddate", "checkout", "checkoutdate"],
  nights: ["nights", "numberofnights"],
  guest: ["guest", "guestname"],
  listing: ["listing", "listingname"],
  details: ["details", "description"],
  referenceCode: ["referencecode", "reference"],
  currency: ["currency"],
  amount: ["amount"],
  paidOut: ["paidout"],
  serviceFee: ["servicefee", "hostfee", "hostservicefee"],
  fastPayFee: ["fastpayfee"],
  cleaningFee: ["cleaningfee"],
  grossEarnings: ["grossearnings"],
  occupancyTaxes: ["occupancytaxes", "occupancytax"],
};

const REQUIRED_FIELDS: readonly Field[] = ["date", "type", "amount", "listing"];
const DATE_FIELDS: readonly Field[] = ["date", "bookingDate", "startDate", "endDate"];

export interface AirbnbTransaction {
  /** CSV record number, counting the header as 1. */
  row: number;
  /** Stable identity used to skip rows that were already imported. */
  fingerprint: string;
  kind: TransactionKind;
  /** Airbnb's own label, e.g. "Reservation" or "Resolution Payout". */
  type: string;
  date: string;
  bookingDate: string | null;
  startDate: string | null;
  endDate: string | null;
  nights: number | null;
  guest: string;
  listing: string;
  confirmationCode: string;
  details: string;
  referenceCode: string;
  currency: string;
  /** The host payout for this line ("Amount"). */
  amountCents: number;
  /** Money transferred to the bank; only set on payout lines. */
  paidOutCents: number;
  /** Airbnb's host service fee, positive when charged. */
  serviceFeeCents: number;
  fastPayFeeCents: number;
  cleaningFeeCents: number;
  /** Null when the export has no "Gross earnings" column or the cell is empty. */
  grossEarningsCents: number | null;
  occupancyTaxesCents: number;
}

export interface RowError {
  row: number;
  message: string;
}

export type AirbnbParseResult =
  | {
      ok: true;
      transactions: AirbnbTransaction[];
      rowErrors: RowError[];
      dateOrder: DateOrder;
      /** How the date order was decided; "ambiguous" means US month/day was assumed. */
      dateOrderSource: DateOrderDetection["kind"] | "override";
    }
  | { ok: false; error: string };

export interface ParseOptions {
  /** Force the order of slash dates instead of detecting it. */
  dateOrder?: DateOrder;
}

export function classifyTransactionType(type: string): TransactionKind {
  const t = type.trim().toLowerCase();
  if (t === "reservation") return "reservation";
  if (t.startsWith("resolution")) return "resolution";
  if (t === "payout") return "payout";
  if (t.includes("adjustment") || t.includes("alteration")) return "adjustment";
  // "Pass Through Tot" lines are occupancy taxes the host must remit.
  if (t.includes("tax") || /\btot\b/.test(t)) return "tax";
  return "other";
}

function normalizeHeader(header: string): string {
  return header.toLowerCase().replace(/[^a-z0-9]/g, "");
}

function mapHeaders(headers: string[]): Partial<Record<Field, number>> {
  const lookup = new Map<string, Field>();
  for (const [field, aliases] of Object.entries(FIELD_ALIASES) as [Field, readonly string[]][]) {
    for (const alias of aliases) lookup.set(alias, field);
  }
  const index: Partial<Record<Field, number>> = {};
  headers.forEach((header, i) => {
    const field = lookup.get(normalizeHeader(header));
    if (field && index[field] === undefined) index[field] = i;
  });
  return index;
}

export function parseAirbnbCsv(text: string, options: ParseOptions = {}): AirbnbParseResult {
  const records = parseCsv(text);
  if (records.length === 0) return { ok: false, error: "The file is empty." };

  // Some tools add a title line above the header, so look a few lines down for it.
  let headerAt = -1;
  let index: Partial<Record<Field, number>> = {};
  for (let i = 0; i < Math.min(records.length, 10); i++) {
    const candidate = mapHeaders(records[i]);
    if (REQUIRED_FIELDS.every((f) => candidate[f] !== undefined)) {
      headerAt = i;
      index = candidate;
      break;
    }
  }
  if (headerAt === -1) {
    const found = mapHeaders(records[0]);
    const missing = REQUIRED_FIELDS.filter((f) => found[f] === undefined);
    return {
      ok: false,
      error:
        "This doesn't look like an Airbnb transaction history export " +
        `(missing columns: ${missing.map(fieldLabel).join(", ")}). ` +
        "In Airbnb, open Earnings → Transaction history and use Export CSV.",
    };
  }

  const dataRows = records.slice(headerAt + 1).map((cells, i) => ({ cells, row: headerAt + i + 2 }));
  const cell = (cells: string[], field: Field) => {
    const i = index[field];
    return i === undefined ? "" : (cells[i] ?? "").trim();
  };

  let dateOrder: DateOrder;
  let dateOrderSource: DateOrderDetection["kind"] | "override";
  if (options.dateOrder) {
    dateOrder = options.dateOrder;
    dateOrderSource = "override";
  } else {
    const detection = detectDateOrder(
      dataRows.flatMap(({ cells }) => DATE_FIELDS.map((field) => cell(cells, field))),
    );
    if (detection.kind === "inconsistent") {
      return {
        ok: false,
        error:
          "The dates in this file mix month/day and day/month formats. This usually happens " +
          "when a CSV is opened and saved in Excel. Export a fresh copy from Airbnb and upload it directly.",
      };
    }
    dateOrder = detection.kind === "detected" ? detection.order : "MDY";
    dateOrderSource = detection.kind;
  }

  const transactions: AirbnbTransaction[] = [];
  const rowErrors: RowError[] = [];

  for (const { cells, row } of dataRows) {
    if (cells.every((c) => c.trim() === "")) continue;
    const get = (field: Field) => cell(cells, field);
    try {
      const type = get("type");
      if (!type) throw new Error("Missing transaction type.");
      const kind = classifyTransactionType(type);

      const date = parseDate(get("date"), dateOrder);
      if (!date) throw new Error("Missing date.");

      const listing = get("listing");
      if (!listing && kind !== "payout" && kind !== "tax") {
        throw new Error(`Missing listing name on a "${type}" line.`);
      }

      const amountCents = money(get("amount"), "Amount") ?? 0;
      const fastPayFeeCents = money(get("fastPayFee"), "Fast pay fee") ?? 0;
      const grossEarningsCents = money(get("grossEarnings"), "Gross earnings");
      let serviceFeeCents = money(get("serviceFee"), "Service fee") ?? 0;
      // Airbnb reports the fee as a positive deduction (gross − fee = amount).
      // If a file carries it with the opposite sign, flip it back.
      if (
        grossEarningsCents !== null &&
        serviceFeeCents !== 0 &&
        grossEarningsCents - amountCents - fastPayFeeCents === -serviceFeeCents
      ) {
        serviceFeeCents = -serviceFeeCents;
      }

      const nightsRaw = get("nights");
      const nights = /^\d+$/.test(nightsRaw) ? Number(nightsRaw) : null;

      transactions.push({
        row,
        fingerprint: "",
        kind,
        type,
        date,
        bookingDate: parseDate(get("bookingDate"), dateOrder),
        startDate: parseDate(get("startDate"), dateOrder),
        endDate: parseDate(get("endDate"), dateOrder),
        nights,
        guest: get("guest"),
        listing,
        confirmationCode: get("confirmationCode"),
        details: get("details"),
        referenceCode: get("referenceCode"),
        currency: (get("currency") || "USD").toUpperCase(),
        amountCents,
        paidOutCents: money(get("paidOut"), "Paid out") ?? 0,
        serviceFeeCents,
        fastPayFeeCents,
        cleaningFeeCents: money(get("cleaningFee"), "Cleaning fee") ?? 0,
        grossEarningsCents,
        occupancyTaxesCents: money(get("occupancyTaxes"), "Occupancy taxes") ?? 0,
      });
    } catch (error) {
      rowErrors.push({ row, message: error instanceof Error ? error.message : String(error) });
    }
  }

  assignFingerprints(transactions);
  return { ok: true, transactions, rowErrors, dateOrder, dateOrderSource };
}

function money(raw: string, label: string): number | null {
  try {
    return parseMoney(raw);
  } catch {
    throw new Error(`${label} "${raw}" is not a valid amount.`);
  }
}

/**
 * Fingerprints ignore the listing name (hosts rename listings) and include an
 * occurrence counter so two genuinely identical lines in one file both survive,
 * while importing the same file twice adds nothing.
 */
function assignFingerprints(transactions: AirbnbTransaction[]): void {
  const occurrences = new Map<string, number>();
  for (const tx of transactions) {
    const identity = JSON.stringify([
      tx.type.toLowerCase(),
      tx.date,
      tx.confirmationCode,
      tx.startDate,
      tx.nights,
      tx.amountCents,
      tx.grossEarningsCents,
      tx.paidOutCents,
      tx.referenceCode,
      tx.confirmationCode ? "" : tx.details,
    ]);
    const n = occurrences.get(identity) ?? 0;
    occurrences.set(identity, n + 1);
    tx.fingerprint = createHash("sha256").update(`${identity}#${n}`).digest("hex").slice(0, 32);
  }
}

function fieldLabel(field: Field): string {
  const labels: Partial<Record<Field, string>> = {
    date: "Date",
    type: "Type",
    amount: "Amount",
    listing: "Listing",
  };
  return labels[field] ?? field;
}
