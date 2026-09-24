import type { OwnerStatement } from "@/lib/statement";

/**
 * Spreadsheet version of an owner statement, one row per booking line and
 * expense, for accountants and bookkeeping tools.
 */

function cell(value: string | number | null | undefined): string {
  const text = value == null ? "" : String(value);
  // Quote when needed, and neutralize leading characters that spreadsheets treat as formulas.
  const safe = /^[=+\-@\t\r]/.test(text) && !/^-?\d/.test(text) ? `'${text}` : text;
  return /[",\r\n]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
}

function amount(cents: number): string {
  return ((cents || 0) / 100).toFixed(2);
}

export function statementToCsv(statement: OwnerStatement): string {
  const rows: (string | number | null)[][] = [
    ["Owner", "Period", "Property", "Line", "Date", "Channel", "Type", "Guest / description", "Confirmation code", "Nights", "Gross", "Platform fee", "Payout", "Co-host fee", "Expense", "Paid by"],
  ];
  const base = [statement.owner.name, statement.period.key];

  for (const section of statement.properties) {
    for (const line of section.lines) {
      const tx = line.transaction;
      rows.push([
        ...base,
        section.property.name,
        "booking",
        line.attributionDate,
        tx.channel ?? "Airbnb",
        tx.type,
        tx.kind === "reservation" ? tx.guest : [tx.details, tx.guest].filter(Boolean).join(" - "),
        tx.confirmationCode,
        tx.nights,
        amount(line.grossCents),
        amount(tx.serviceFeeCents),
        amount(tx.amountCents),
        amount(line.fee.totalCents),
        "",
        "",
      ]);
    }
    for (const expense of section.expenses) {
      rows.push([
        ...base,
        section.property.name,
        "expense",
        expense.date,
        "",
        expense.category,
        expense.description,
        "",
        null,
        "",
        "",
        "",
        "",
        amount(expense.amountCents),
        expense.paidBy === "cohost" ? "co-host" : "owner",
      ]);
    }
    if (section.totals.monthlyFeesCents !== 0) {
      rows.push([...base, section.property.name, "fee", statement.period.end, "", "Monthly management fee", "", "", null, "", "", "", amount(section.totals.monthlyFeesCents), "", ""]);
    }
  }

  const t = statement.totals;
  rows.push([]);
  rows.push(["Totals", statement.period.key, "", "", "", "", "", "", "", t.nights, amount(t.grossCents), amount(t.serviceFeeCents), amount(t.payoutCents), amount(t.cohostFeesCents), amount(t.reimbursableExpensesCents + t.ownerPaidExpensesCents), ""]);
  rows.push(["Balance due to owner", statement.period.key, "", "", "", "", "", "", "", null, "", "", amount(t.balanceDueToOwnerCents), "", "", ""]);

  return `\ufeff${rows.map((r) => r.map(cell).join(",")).join("\r\n")}\r\n`;
}
