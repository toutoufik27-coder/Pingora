import { defaultStatementMonth, isValidMonth } from "@/lib/dates";

type SearchParams = Record<string, string | string[] | undefined>;

export function firstParam(params: SearchParams, key: string): string | undefined {
  const value = params[key];
  return Array.isArray(value) ? value[0] : value;
}

/** The ?month= parameter, or the month that just ended. */
export function monthParam(params: SearchParams, now = new Date()): string {
  const month = firstParam(params, "month");
  return isValidMonth(month) ? month : defaultStatementMonth(now);
}

/** The ?year= parameter, or the year of the month that just ended. */
export function yearParam(params: SearchParams, now = new Date()): number {
  const year = Number(firstParam(params, "year"));
  return Number.isInteger(year) && year >= 2000 && year <= 2100 ? year : Number(defaultStatementMonth(now).slice(0, 4));
}
