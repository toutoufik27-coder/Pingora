import { PDFDocument, rgb, StandardFonts, type PDFFont, type PDFPage, type RGB } from "pdf-lib";
import { describeRule } from "@/lib/commission";
import { formatDate } from "@/lib/dates";
import { PAYOUT_FLOW_SHORT_LABELS } from "@/lib/domain";
import { formatMoney } from "@/lib/money";
import type { OwnerStatement, PropertyStatement, StatementLine } from "@/lib/statement";

/**
 * Renders an owner statement as a US Letter PDF using the standard PDF fonts,
 * so it needs no font files and works in any Node runtime.
 */

export interface StatementPdfOptions {
  businessName: string;
  /** ISO date printed as the generation date. */
  generatedOn: string;
  appName: string;
}

const PAGE_WIDTH = 612;
const PAGE_HEIGHT = 792;
const MARGIN = 40;
const CONTENT_WIDTH = PAGE_WIDTH - 2 * MARGIN;
const FOOTER_SPACE = 36;

const INK = rgb(0.1, 0.12, 0.16);
const MUTED = rgb(0.42, 0.45, 0.5);
const RULE = rgb(0.85, 0.87, 0.9);
const HEADER_FILL = rgb(0.95, 0.96, 0.97);
const ACCENT = rgb(0.05, 0.4, 0.35);

interface Column {
  header: string;
  width: number;
  align?: "left" | "right";
}

interface TextOptions {
  size?: number;
  bold?: boolean;
  color?: RGB;
  align?: "left" | "right";
  maxWidth?: number;
}

class Layout {
  private pages: PDFPage[] = [];
  private page!: PDFPage;
  y = 0;
  private readonly supported: Set<number>;

  constructor(
    private readonly doc: PDFDocument,
    private readonly regular: PDFFont,
    private readonly bold: PDFFont,
  ) {
    this.supported = new Set(regular.getCharacterSet());
    this.newPage();
  }

  newPage(): void {
    this.page = this.doc.addPage([PAGE_WIDTH, PAGE_HEIGHT]);
    this.pages.push(this.page);
    this.y = PAGE_HEIGHT - MARGIN;
  }

  /** Starts a new page when fewer than `height` points are left. Returns true if it did. */
  ensureSpace(height: number): boolean {
    if (this.y - height >= MARGIN + FOOTER_SPACE) return false;
    this.newPage();
    return true;
  }

  /** Standard fonts only cover Windows-1252; strip accents or substitute "?" for the rest. */
  clean(text: string): string {
    let out = "";
    for (const ch of text.replace(/[\r\n\t]+/g, " ").normalize("NFC")) {
      if (this.supported.has(ch.codePointAt(0)!)) {
        out += ch;
        continue;
      }
      const stripped = ch.normalize("NFD").replace(/[̀-ͯ]/g, "");
      out += stripped && [...stripped].every((c) => this.supported.has(c.codePointAt(0)!)) ? stripped : "?";
    }
    return out;
  }

  width(text: string, size: number, bold = false): number {
    return (bold ? this.bold : this.regular).widthOfTextAtSize(text, size);
  }

  fit(text: string, size: number, maxWidth: number, bold = false): string {
    if (this.width(text, size, bold) <= maxWidth) return text;
    let end = text.length;
    while (end > 0 && this.width(`${text.slice(0, end)}…`, size, bold) > maxWidth) end--;
    return `${text.slice(0, end).trimEnd()}…`;
  }

  text(value: string, x: number, y: number, options: TextOptions = {}): void {
    const size = options.size ?? 9;
    const bold = options.bold ?? false;
    let text = this.clean(value);
    if (options.maxWidth !== undefined) text = this.fit(text, size, options.maxWidth, bold);
    const drawX = options.align === "right" ? x - this.width(text, size, bold) : x;
    this.page.drawText(text, {
      x: drawX,
      y,
      size,
      font: bold ? this.bold : this.regular,
      color: options.color ?? INK,
    });
  }

  rule(y: number, color = RULE, thickness = 0.75): void {
    this.page.drawLine({ start: { x: MARGIN, y }, end: { x: PAGE_WIDTH - MARGIN, y }, thickness, color });
  }

  fill(x: number, y: number, width: number, height: number, color: RGB): void {
    this.page.drawRectangle({ x, y, width, height, color });
  }

  table(columns: Column[], rows: string[][], options: { boldLastRow?: boolean } = {}): void {
    const rowHeight = 15;
    const size = 8;
    const drawHeader = () => {
      this.fill(MARGIN, this.y - rowHeight + 4, CONTENT_WIDTH, rowHeight, HEADER_FILL);
      let x = MARGIN;
      for (const column of columns) {
        const right = column.align === "right";
        this.text(column.header, right ? x + column.width - 4 : x + 4, this.y - 7, {
          size,
          bold: true,
          color: MUTED,
          align: column.align,
          maxWidth: column.width - 8,
        });
        x += column.width;
      }
      this.y -= rowHeight;
    };

    this.ensureSpace(rowHeight * 2);
    drawHeader();
    rows.forEach((row, index) => {
      if (this.ensureSpace(rowHeight)) drawHeader();
      const bold = options.boldLastRow === true && index === rows.length - 1;
      if (bold) this.rule(this.y + 1, INK, 0.5);
      let x = MARGIN;
      row.forEach((value, i) => {
        const column = columns[i];
        const right = column.align === "right";
        this.text(value, right ? x + column.width - 4 : x + 4, this.y - 7, {
          size,
          bold,
          align: column.align,
          maxWidth: column.width - 8,
        });
        x += column.width;
      });
      this.y -= rowHeight;
      if (!bold) this.rule(this.y + 4, RULE, 0.4);
    });
  }

  /** Label on the left, amount on the right, across the content width. */
  keyValue(label: string, value: string, options: { bold?: boolean; size?: number; color?: RGB } = {}): void {
    const size = options.size ?? 9;
    this.ensureSpace(size + 6);
    this.text(label, MARGIN, this.y - size, { size, bold: options.bold, color: options.color });
    this.text(value, PAGE_WIDTH - MARGIN, this.y - size, { size, bold: options.bold, color: options.color, align: "right" });
    this.y -= size + 6;
  }

  footer(left: string): void {
    this.pages.forEach((page, i) => {
      this.page = page;
      this.rule(MARGIN + 14, RULE, 0.5);
      this.text(left, MARGIN, MARGIN, { size: 7, color: MUTED, maxWidth: CONTENT_WIDTH - 80 });
      this.text(`Page ${i + 1} of ${this.pages.length}`, PAGE_WIDTH - MARGIN, MARGIN, { size: 7, color: MUTED, align: "right" });
    });
  }
}

function money(cents: number, currency: string): string {
  return formatMoney(cents, currency);
}

function lineDescription(line: StatementLine): string {
  const tx = line.transaction;
  if (tx.kind === "reservation") {
    const guest = tx.guest || "Reservation";
    return tx.channel && tx.channel !== "Airbnb" ? `${guest} (${tx.channel})` : guest;
  }
  return [tx.type, tx.details || tx.guest].filter(Boolean).join(" - ");
}

function balanceLabel(balanceCents: number): string {
  if (balanceCents > 0) return "Balance due to owner";
  if (balanceCents < 0) return "Balance due from owner";
  return "Balance";
}

export async function renderStatementPdf(statement: OwnerStatement, options: StatementPdfOptions): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  const title = `Owner statement - ${statement.owner.name} - ${statement.period.label}`;
  doc.setTitle(title);
  doc.setAuthor(options.businessName);
  doc.setCreator(options.appName);
  doc.setProducer(options.appName);

  const regular = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const layout = new Layout(doc, regular, bold);
  const currency = statement.currency;
  const totals = statement.totals;

  // Heading
  layout.text(options.businessName, MARGIN, layout.y - 16, { size: 16, bold: true, maxWidth: CONTENT_WIDTH / 2 });
  layout.text("OWNER STATEMENT", PAGE_WIDTH - MARGIN, layout.y - 10, { size: 8, bold: true, color: MUTED, align: "right" });
  layout.text(statement.period.label, PAGE_WIDTH - MARGIN, layout.y - 26, { size: 14, bold: true, align: "right" });
  layout.y -= 38;
  layout.rule(layout.y);
  layout.y -= 16;

  const basis =
    statement.basis === "checkin" ? "Bookings are counted in the month of check-in." : "Bookings are counted in the month they were paid out.";
  const details: [string, string][] = [
    ["Prepared for", [statement.owner.name, statement.owner.email].filter(Boolean).join(" · ")],
    ["Period", `${formatDate(statement.period.start)} - ${formatDate(statement.period.end)}`],
    ["Generated", formatDate(options.generatedOn)],
  ];
  for (const [label, value] of details) {
    layout.text(label, MARGIN, layout.y, { size: 9, color: MUTED });
    layout.text(value, MARGIN + 90, layout.y, { size: 9, maxWidth: CONTENT_WIDTH - 90 });
    layout.y -= 13;
  }
  layout.text(basis, MARGIN, layout.y, { size: 8, color: MUTED });
  layout.y -= 22;

  // Summary
  layout.text("Summary", MARGIN, layout.y, { size: 11, bold: true });
  layout.y -= 8;
  layout.keyValue("Gross booking revenue", money(totals.grossCents, currency));
  layout.keyValue("Platform fees", money(-totals.serviceFeeCents, currency));
  layout.keyValue("Payouts", money(totals.payoutCents, currency), { bold: true });
  layout.keyValue("Co-host fees", money(-totals.cohostFeesCents, currency));
  if (totals.reimbursableExpensesCents !== 0) {
    layout.keyValue("Expenses paid by co-host", money(-totals.reimbursableExpensesCents, currency));
  }
  if (totals.ownerPaidExpensesCents !== 0) {
    layout.keyValue("Expenses paid by owner", money(-totals.ownerPaidExpensesCents, currency));
  }
  layout.keyValue("Owner net income", money(totals.ownerNetCents, currency), { bold: true });
  layout.rule(layout.y + 2, INK, 0.75);
  layout.y -= 4;
  layout.keyValue(balanceLabel(totals.balanceDueToOwnerCents), money(Math.abs(totals.balanceDueToOwnerCents), currency), {
    bold: true,
    size: 12,
    color: ACCENT,
  });
  if (statement.currencies.length > 1) {
    layout.text(`Warning: lines are in several currencies (${statement.currencies.join(", ")}); totals mix them.`, MARGIN, layout.y - 8, {
      size: 8,
      color: rgb(0.7, 0.2, 0.1),
    });
    layout.y -= 14;
  }
  layout.y -= 12;

  for (const section of statement.properties) renderProperty(layout, section, currency);

  layout.footer(`${options.businessName} · ${title} · Generated with ${options.appName}`);
  return doc.save();
}

function renderProperty(layout: Layout, section: PropertyStatement, currency: string): void {
  const { property, totals } = section;
  layout.ensureSpace(80);
  layout.y -= 6;
  layout.text(property.name, MARGIN, layout.y - 12, { size: 12, bold: true, maxWidth: CONTENT_WIDTH });
  layout.y -= 26;
  layout.text(`${PAYOUT_FLOW_SHORT_LABELS[property.payoutFlow]} · ${describeRule(property.rule)}`, MARGIN, layout.y, {
    size: 8,
    color: MUTED,
    maxWidth: CONTENT_WIDTH,
  });
  layout.y -= 10;

  if (section.lines.length === 0) {
    layout.text("No bookings in this period.", MARGIN, layout.y - 10, { size: 9, color: MUTED });
    layout.y -= 20;
  } else {
    const columns: Column[] = [
      { header: "Date", width: 62 },
      { header: "Guest / item", width: 122 },
      { header: "Nights", width: 36, align: "right" },
      { header: "Code", width: 72 },
      { header: "Gross", width: 60, align: "right" },
      { header: "Platform fee", width: 60, align: "right" },
      { header: "Payout", width: 60, align: "right" },
      { header: "Co-host fee", width: 60, align: "right" },
    ];
    const rows = section.lines.map((line) => [
      formatDate(line.attributionDate),
      lineDescription(line),
      line.transaction.nights?.toString() ?? "",
      line.transaction.confirmationCode,
      money(line.grossCents, currency),
      money(-line.transaction.serviceFeeCents, currency),
      money(line.transaction.amountCents, currency),
      money(line.fee.totalCents, currency),
    ]);
    rows.push([
      "Total",
      `${totals.bookings} booking${totals.bookings === 1 ? "" : "s"}`,
      String(totals.nights),
      "",
      money(totals.grossCents, currency),
      money(-totals.serviceFeeCents, currency),
      money(totals.payoutCents, currency),
      money(totals.commissionCents + totals.flatFeesCents + totals.cleaningFeesToCohostCents, currency),
    ]);
    layout.y -= 4;
    layout.table(columns, rows, { boldLastRow: true });
  }

  if (section.expenses.length > 0) {
    layout.y -= 8;
    layout.ensureSpace(40);
    layout.text("Expenses", MARGIN, layout.y - 10, { size: 9, bold: true });
    layout.y -= 16;
    layout.table(
      [
        { header: "Date", width: 62 },
        { header: "Category", width: 100 },
        { header: "Description", width: 190 },
        { header: "Paid by", width: 120 },
        { header: "Amount", width: 60, align: "right" },
      ],
      section.expenses.map((e) => [
        formatDate(e.date),
        e.category,
        e.description,
        e.paidBy === "cohost" ? "Co-host (reimbursed)" : "Owner (paid directly)",
        money(e.amountCents, currency),
      ]),
    );
  }

  layout.y -= 6;
  if (totals.monthlyFeesCents !== 0) layout.keyValue("Monthly management fee", money(-totals.monthlyFeesCents, currency));
  layout.keyValue("Total co-host fees", money(-totals.cohostFeesCents, currency));
  layout.keyValue(balanceLabel(totals.balanceDueToOwnerCents), money(Math.abs(totals.balanceDueToOwnerCents), currency), {
    bold: true,
  });
  layout.y -= 10;
}
