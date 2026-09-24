import { describe, expect, it } from "vitest";
import {
  applyRate,
  centsToInput,
  formatBasisPoints,
  formatMoney,
  MoneyParseError,
  parseMoney,
  parsePercentToBasisPoints,
} from "./money";

describe("parseMoney", () => {
  it.each([
    ["1,234.56", 123456],
    ["$12.00", 1200],
    ["-4.50", -450],
    ["(4.50)", -450],
    ["-$4.50", -450],
    ["$-4.50", -450],
    ["USD 99", 9900],
    ["12,50", 1250],
    ["1.234,56", 123456],
    ["1,234", 123400],
    ["1,234,567.8", 123456780],
    ["0.005", 1],
    ["-0.005", -1],
    ["0.004", 0],
    [" 42 ", 4200],
  ])("parses %j as %i cents", (input, expected) => {
    expect(parseMoney(input)).toBe(expected);
  });

  it("returns null for empty values", () => {
    expect(parseMoney("")).toBeNull();
    expect(parseMoney("   ")).toBeNull();
    expect(parseMoney(null)).toBeNull();
    expect(parseMoney(undefined)).toBeNull();
  });

  it("never returns negative zero", () => {
    expect(Object.is(parseMoney("-0.00"), 0)).toBe(true);
  });

  it.each(["abc", "1.2.3", "--5", "$"])("rejects %j", (input) => {
    expect(() => parseMoney(input)).toThrow(MoneyParseError);
  });
});

describe("applyRate", () => {
  it("applies basis points and rounds half away from zero", () => {
    expect(applyRate(12345, 2000)).toBe(2469);
    expect(applyRate(333, 1500)).toBe(50); // 49.95
    expect(applyRate(-333, 1500)).toBe(-50);
    expect(applyRate(1, 5000)).toBe(1); // 0.5
    expect(applyRate(-1, 5000)).toBe(-1);
  });

  it("never returns negative zero", () => {
    expect(Object.is(applyRate(-10, 100), 0)).toBe(true);
  });
});

describe("percentages", () => {
  it.each([
    ["20", 2000],
    ["12.5", 1250],
    ["12.5%", 1250],
    ["0", 0],
    ["100", 10000],
  ])("parses %j as %i basis points", (input, expected) => {
    expect(parsePercentToBasisPoints(input)).toBe(expected);
  });

  it.each(["", "abc", "12.345", "100.01", "-5"])("rejects %j", (input) => {
    expect(parsePercentToBasisPoints(input)).toBeNull();
  });

  it("formats basis points", () => {
    expect(formatBasisPoints(2000)).toBe("20%");
    expect(formatBasisPoints(1250)).toBe("12.5%");
    expect(formatBasisPoints(1234)).toBe("12.34%");
  });
});

describe("formatMoney", () => {
  it("formats cents as currency", () => {
    expect(formatMoney(123456)).toBe("$1,234.56");
    expect(formatMoney(-450)).toBe("-$4.50");
    expect(formatMoney(100, "EUR")).toBe("€1.00");
  });

  it("never prints negative zero", () => {
    expect(formatMoney(-0)).toBe("$0.00");
  });

  it("falls back for unknown currency codes", () => {
    expect(formatMoney(100, "XXXX")).toBe("XXXX 1.00");
  });

  it("formats values for inputs", () => {
    expect(centsToInput(123450)).toBe("1234.50");
  });
});
