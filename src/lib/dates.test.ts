import { describe, expect, it } from "vitest";
import {
  defaultStatementMonth,
  detectDateOrder,
  formatDate,
  isValidIsoDate,
  isValidMonth,
  monthPeriod,
  parseDate,
  shiftMonth,
  yearPeriod,
} from "./dates";

describe("detectDateOrder", () => {
  it("detects month/day when a day is above 12", () => {
    expect(detectDateOrder(["08/04/2026", "08/15/2026"])).toEqual({ kind: "detected", order: "MDY" });
  });

  it("detects day/month when a day is above 12", () => {
    expect(detectDateOrder(["15/08/2026", ""])).toEqual({ kind: "detected", order: "DMY" });
  });

  it("reports ambiguous, inconsistent and missing dates", () => {
    expect(detectDateOrder(["01/02/2026", "03/04/2026"])).toEqual({ kind: "ambiguous" });
    expect(detectDateOrder(["15/08/2026", "08/15/2026"])).toEqual({ kind: "inconsistent" });
    expect(detectDateOrder(["", "n/a"])).toEqual({ kind: "none" });
  });

  it("detects ISO dates", () => {
    expect(detectDateOrder(["2026-08-04"])).toEqual({ kind: "detected", order: "YMD" });
  });
});

describe("parseDate", () => {
  it("parses slash dates in either order", () => {
    expect(parseDate("08/04/2026", "MDY")).toBe("2026-08-04");
    expect(parseDate("08/04/2026", "DMY")).toBe("2026-04-08");
    expect(parseDate("8/4/26", "MDY")).toBe("2026-08-04");
  });

  it("always accepts ISO dates and timestamps", () => {
    expect(parseDate("2026-8-4", "MDY")).toBe("2026-08-04");
    expect(parseDate("2026-08-04T10:00:00Z", "DMY")).toBe("2026-08-04");
  });

  it("returns null for empty values and rejects invalid dates", () => {
    expect(parseDate("", "MDY")).toBeNull();
    expect(parseDate(undefined, "MDY")).toBeNull();
    expect(() => parseDate("02/30/2026", "MDY")).toThrow();
    expect(() => parseDate("13/13/2026", "MDY")).toThrow();
    expect(() => parseDate("yesterday", "MDY")).toThrow();
  });

  it("validates ISO dates", () => {
    expect(isValidIsoDate("2024-02-29")).toBe(true);
    expect(isValidIsoDate("2026-02-29")).toBe(false);
    expect(isValidIsoDate("2026-2-1")).toBe(false);
  });
});

describe("periods", () => {
  it("builds month periods", () => {
    expect(monthPeriod("2026-02")).toEqual({
      key: "2026-02",
      label: "February 2026",
      start: "2026-02-01",
      end: "2026-02-28",
      months: 1,
    });
    expect(monthPeriod("2024-02").end).toBe("2024-02-29");
    expect(() => monthPeriod("2026-13")).toThrow();
    expect(isValidMonth("2026-09")).toBe(true);
    expect(isValidMonth("2026-9")).toBe(false);
  });

  it("builds year periods", () => {
    expect(yearPeriod(2026)).toEqual({ key: "2026", label: "2026", start: "2026-01-01", end: "2026-12-31", months: 12 });
  });

  it("shifts months across years", () => {
    expect(shiftMonth("2026-01", -1)).toBe("2025-12");
    expect(shiftMonth("2026-12", 1)).toBe("2027-01");
  });

  it("defaults statements to the month that just ended", () => {
    expect(defaultStatementMonth(new Date("2026-09-24T12:00:00Z"))).toBe("2026-08");
    expect(defaultStatementMonth(new Date("2026-01-03T12:00:00Z"))).toBe("2025-12");
  });

  it("formats dates without time zone drift", () => {
    expect(formatDate("2026-09-03")).toBe("Sep 3, 2026");
    expect(formatDate(null)).toBe("");
  });
});
