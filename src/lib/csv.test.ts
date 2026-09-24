import { describe, expect, it } from "vitest";
import { detectDelimiter, parseCsv } from "./csv";

describe("parseCsv", () => {
  it("parses simple rows", () => {
    expect(parseCsv("a,b,c\n1,2,3\n")).toEqual([
      ["a", "b", "c"],
      ["1", "2", "3"],
    ]);
  });

  it("handles quotes, escaped quotes and embedded delimiters and newlines", () => {
    const text = 'name,notes\n"Loft, Downtown","He said ""hi""\nthen left"\n';
    expect(parseCsv(text)).toEqual([
      ["name", "notes"],
      ["Loft, Downtown", 'He said "hi"\nthen left'],
    ]);
  });

  it("handles CRLF, a BOM, blank lines and a missing final newline", () => {
    expect(parseCsv("\ufeffa,b\r\n\r\n1,2\r\n3,4")).toEqual([
      ["a", "b"],
      ["1", "2"],
      ["3", "4"],
    ]);
  });

  it("keeps empty fields", () => {
    expect(parseCsv("a,,c\n,,\n")).toEqual([
      ["a", "", "c"],
      ["", "", ""],
    ]);
  });

  it("detects semicolon and tab delimiters", () => {
    expect(detectDelimiter("a;b;c\n1;2;3")).toBe(";");
    expect(detectDelimiter("a\tb\tc")).toBe("\t");
    expect(detectDelimiter('"a;b",c,d')).toBe(",");
    expect(parseCsv("a;b\n1;2")).toEqual([
      ["a", "b"],
      ["1", "2"],
    ]);
  });
});
