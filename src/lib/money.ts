/**
 * Money is stored and computed as integer cents so totals never drift
 * the way floating point dollars do.
 */
export type Cents = number;

export class MoneyParseError extends Error {
  constructor(readonly input: string) {
    super(`"${input}" is not a valid amount`);
    this.name = "MoneyParseError";
  }
}

/**
 * Parses an amount the way Airbnb (or a person typing into a form) writes it:
 * "1,234.56", "$12.00", "-4.50", "(4.50)", "12,50" or "1.234,56".
 * Returns null for an empty value and throws MoneyParseError for anything else
 * that is not a number.
 */
export function parseMoney(raw: string | null | undefined): Cents | null {
  if (raw == null) return null;
  let s = raw.trim();
  if (s === "") return null;

  let negative = false;
  if (s.startsWith("(") && s.endsWith(")")) {
    negative = true;
    s = s.slice(1, -1);
  }
  // Currency symbols, ISO codes and (non-breaking) spaces carry no value.
  s = s.replace(/[A-Za-z$€£¥\s ]/g, "");
  if (s.startsWith("-")) {
    negative = !negative;
    s = s.slice(1);
  } else if (s.startsWith("+")) {
    s = s.slice(1);
  }

  const normalized = normalizeDecimalSeparator(s);
  if (!/^\d+(\.\d+)?$/.test(normalized)) throw new MoneyParseError(raw);

  const [whole, fraction = ""] = normalized.split(".");
  const digits = (fraction + "000").slice(0, 3);
  let cents = Number(whole) * 100 + Number(digits.slice(0, 2));
  // Round half away from zero on the third decimal.
  if (Number(digits[2]) >= 5) cents += 1;
  return negative && cents !== 0 ? -cents : cents;
}

function normalizeDecimalSeparator(s: string): string {
  const lastComma = s.lastIndexOf(",");
  const lastDot = s.lastIndexOf(".");
  if (lastComma === -1) return s;
  if (lastDot === -1) {
    // Only commas: "1,234" / "1,234,567" are thousands, "12,50" is a decimal comma.
    const commas = s.split(",").length - 1;
    const decimals = s.length - lastComma - 1;
    return commas === 1 && decimals !== 3 ? s.replace(",", ".") : s.replace(/,/g, "");
  }
  return lastComma > lastDot
    ? s.replace(/\./g, "").replace(",", ".") // 1.234,56
    : s.replace(/,/g, ""); // 1,234.56
}

export function roundHalfAwayFromZero(value: number): number {
  return Math.sign(value) * Math.round(Math.abs(value));
}

/** Applies a rate expressed in basis points (20% = 2000) to an amount in cents. */
export function applyRate(cents: Cents, basisPoints: number): Cents {
  // Normalize -0 to 0 so it never leaks into totals or rendering.
  return roundHalfAwayFromZero((cents * basisPoints) / 10_000) || 0;
}

/** Parses "20", "12.5" or "12.5%" into basis points. Returns null when invalid. */
export function parsePercentToBasisPoints(raw: string | null | undefined): number | null {
  if (raw == null) return null;
  const s = raw.trim().replace(/%$/, "").trim();
  if (!/^\d{1,3}(\.\d{1,2})?$/.test(s)) return null;
  const [whole, fraction = ""] = s.split(".");
  const bps = Number(whole) * 100 + Number((fraction + "00").slice(0, 2));
  return bps <= 10_000 ? bps : null;
}

export function formatBasisPoints(bps: number): string {
  return `${Number((bps / 100).toFixed(2))}%`;
}

const formatters = new Map<string, Intl.NumberFormat>();

export function formatMoney(cents: Cents, currency = "USD"): string {
  cents ||= 0; // never print "-$0.00"
  let formatter = formatters.get(currency);
  if (!formatter) {
    try {
      formatter = new Intl.NumberFormat("en-US", { style: "currency", currency });
    } catch {
      // Unknown currency code in an import: fall back to a plain number.
      return `${currency} ${(cents / 100).toFixed(2)}`;
    }
    formatters.set(currency, formatter);
  }
  return formatter.format(cents / 100);
}

/** Formats cents for an editable input field ("1234.5" → "1234.50"). */
export function centsToInput(cents: Cents): string {
  return (cents / 100).toFixed(2);
}
