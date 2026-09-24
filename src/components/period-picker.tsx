import Form from "next/form";
import Link from "next/link";
import { monthPeriod, shiftMonth } from "@/lib/dates";
import { buttonClass, inputClass } from "./ui";

/** Month navigation that keeps the choice in the URL (?month=YYYY-MM). */
export function MonthPicker({ month, basePath }: { month: string; basePath: string }) {
  const previous = shiftMonth(month, -1);
  const next = shiftMonth(month, 1);
  return (
    <div className="flex items-center gap-2">
      <Link
        href={`${basePath}?month=${previous}`}
        className={buttonClass("secondary", "sm")}
        aria-label={`Previous month (${monthPeriod(previous).label})`}
      >
        ←
      </Link>
      <Form action={basePath} className="flex items-center gap-2">
        <label htmlFor="month" className="sr-only">
          Month
        </label>
        <input id="month" type="month" name="month" defaultValue={month} className={`${inputClass} w-40 py-1.5`} />
        <button type="submit" className={buttonClass("secondary", "sm")}>
          Show
        </button>
      </Form>
      <Link
        href={`${basePath}?month=${next}`}
        className={buttonClass("secondary", "sm")}
        aria-label={`Next month (${monthPeriod(next).label})`}
      >
        →
      </Link>
    </div>
  );
}

export function YearPicker({ year, basePath }: { year: number; basePath: string }) {
  return (
    <div className="flex items-center gap-2">
      <Link href={`${basePath}?year=${year - 1}`} className={buttonClass("secondary", "sm")} aria-label={`Year ${year - 1}`}>
        ← {year - 1}
      </Link>
      <span className="px-2 text-sm font-semibold text-ink-900">{year}</span>
      <Link href={`${basePath}?year=${year + 1}`} className={buttonClass("secondary", "sm")} aria-label={`Year ${year + 1}`}>
        {year + 1} →
      </Link>
    </div>
  );
}
