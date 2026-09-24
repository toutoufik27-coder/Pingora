/**
 * Dates travel through the app as ISO calendar dates ("2026-09-03") and months
 * as periods ("2026-09"). Neither carries a time zone, so a reservation that
 * starts on the 1st stays on the 1st wherever the server runs.
 */

export type DateOrder = "MDY" | "DMY" | "YMD";

export type DateOrderDetection =
  | { kind: "detected"; order: DateOrder }
  /** Every value reads the same as month/day and day/month (all parts ≤ 12). */
  | { kind: "ambiguous" }
  /** Some values only work as month/day and others only as day/month. */
  | { kind: "inconsistent" }
  | { kind: "none" };

const SLASH_DATE = /^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})$/;
const ISO_DATE = /^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T ].*)?$/;

export function detectDateOrder(values: Iterable<string>): DateOrderDetection {
  let slash = false;
  let iso = false;
  let firstOver12 = false;
  let secondOver12 = false;
  for (const raw of values) {
    const value = raw.trim();
    if (!value) continue;
    if (ISO_DATE.test(value)) {
      iso = true;
      continue;
    }
    const match = SLASH_DATE.exec(value);
    if (!match) continue;
    slash = true;
    if (Number(match[1]) > 12) firstOver12 = true;
    if (Number(match[2]) > 12) secondOver12 = true;
  }
  if (!slash) return iso ? { kind: "detected", order: "YMD" } : { kind: "none" };
  if (firstOver12 && secondOver12) return { kind: "inconsistent" };
  if (firstOver12) return { kind: "detected", order: "DMY" };
  if (secondOver12) return { kind: "detected", order: "MDY" };
  return { kind: "ambiguous" };
}

/**
 * Parses a date written in the given order (ISO dates are always accepted).
 * Returns null for an empty value and throws for an invalid one.
 */
export function parseDate(raw: string | null | undefined, order: DateOrder): string | null {
  const value = raw?.trim();
  if (!value) return null;

  let year: number;
  let month: number;
  let day: number;
  const iso = ISO_DATE.exec(value);
  const slash = iso ? null : SLASH_DATE.exec(value);
  if (iso) {
    [year, month, day] = [Number(iso[1]), Number(iso[2]), Number(iso[3])];
  } else if (slash && order !== "YMD") {
    const [a, b, y] = [Number(slash[1]), Number(slash[2]), slash[3]];
    [month, day] = order === "MDY" ? [a, b] : [b, a];
    year = y.length === 2 ? 2000 + Number(y) : Number(y);
  } else {
    throw new Error(`"${value}" is not a date`);
  }

  if (month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month)) {
    throw new Error(`"${value}" is not a valid calendar date`);
  }
  return `${year}-${pad(month)}-${pad(day)}`;
}

export function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

function pad(n: number): string {
  return String(n).padStart(2, "0");
}

export function isValidIsoDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [y, m, d] = value.split("-").map(Number);
  return m >= 1 && m <= 12 && d >= 1 && d <= daysInMonth(y, m);
}

// ---------------------------------------------------------------------------
// Periods

/** A reporting window: a calendar month or a calendar year. */
export interface ReportPeriod {
  /** "2026-09" for a month, "2026" for a year. */
  key: string;
  label: string;
  /** First day, inclusive (ISO date). */
  start: string;
  /** Last day, inclusive (ISO date). */
  end: string;
  /** Number of calendar months covered; monthly fees are charged once per month. */
  months: number;
}

const PERIOD = /^(\d{4})-(0[1-9]|1[0-2])$/;

export function isValidMonth(value: string | null | undefined): value is string {
  return !!value && PERIOD.test(value);
}

export function monthPeriod(month: string): ReportPeriod {
  const match = PERIOD.exec(month);
  if (!match) throw new Error(`"${month}" is not a month (expected YYYY-MM)`);
  const year = Number(match[1]);
  const m = Number(match[2]);
  return {
    key: month,
    label: new Date(Date.UTC(year, m - 1, 1)).toLocaleString("en-US", {
      month: "long",
      year: "numeric",
      timeZone: "UTC",
    }),
    start: `${month}-01`,
    end: `${month}-${pad(daysInMonth(year, m))}`,
    months: 1,
  };
}

export function yearPeriod(year: number): ReportPeriod {
  return { key: String(year), label: String(year), start: `${year}-01-01`, end: `${year}-12-31`, months: 12 };
}

export function currentMonth(now = new Date()): string {
  return `${now.getUTCFullYear()}-${pad(now.getUTCMonth() + 1)}`;
}

export function shiftMonth(month: string, delta: number): string {
  const { start } = monthPeriod(month);
  const [y, m] = start.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1 + delta, 1));
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}`;
}

/** Statements are usually prepared for the month that just ended. */
export function defaultStatementMonth(now = new Date()): string {
  return shiftMonth(currentMonth(now), -1);
}

const dateFormatter = new Intl.DateTimeFormat("en-US", {
  month: "short",
  day: "numeric",
  year: "numeric",
  timeZone: "UTC",
});

/** "2026-09-03" → "Sep 3, 2026". */
export function formatDate(isoDate: string | null | undefined): string {
  if (!isoDate) return "";
  const [y, m, d] = isoDate.split("-").map(Number);
  return dateFormatter.format(new Date(Date.UTC(y, m - 1, d)));
}

export function todayIso(now = new Date()): string {
  return `${now.getUTCFullYear()}-${pad(now.getUTCMonth() + 1)}-${pad(now.getUTCDate())}`;
}
