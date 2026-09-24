import { z } from "zod";
import { parseMoney, parsePercentToBasisPoints } from "@/lib/money";

/** Reads the named fields of a form as strings ("" when missing or a file). */
export function readFields<K extends string>(formData: FormData, keys: readonly K[]): Record<K, string> {
  const out = {} as Record<K, string>;
  for (const key of keys) {
    const value = formData.get(key);
    out[key] = typeof value === "string" ? value : "";
  }
  return out;
}

export function firstIssue(error: z.ZodError): string {
  return error.issues[0]?.message ?? "Please check the form.";
}

/** A non-negative dollar amount typed by a person ("25", "$1,200.50"); empty means zero. */
export function moneyField(label: string) {
  return z.string().transform((value, ctx) => {
    try {
      const cents = parseMoney(value) ?? 0;
      if (cents < 0) throw new Error("negative");
      return cents;
    } catch {
      ctx.addIssue({ code: "custom", message: `${label} must be a positive amount, like 25 or 25.50.` });
      return z.NEVER;
    }
  });
}

export function requiredMoneyField(label: string) {
  return z.string().transform((value, ctx) => {
    try {
      const cents = parseMoney(value);
      if (cents === null || cents <= 0) throw new Error("empty");
      return cents;
    } catch {
      ctx.addIssue({ code: "custom", message: `Enter the ${label.toLowerCase()} as a positive amount, like 45.99.` });
      return z.NEVER;
    }
  });
}

export const percentField = z.string().transform((value, ctx) => {
  const bps = parsePercentToBasisPoints(value);
  if (bps === null) {
    ctx.addIssue({ code: "custom", message: "Enter a commission rate between 0 and 100, like 20 or 12.5." });
    return z.NEVER;
  }
  return bps;
});

/** HTML checkboxes submit "on" when ticked and nothing otherwise. */
export const checkboxField = z.string().transform((value) => value === "on" || value === "true");

export const idField = z.string().trim().min(1).max(100);
