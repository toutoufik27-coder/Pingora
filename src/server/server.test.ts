import { readFileSync } from "node:fs";
import path from "node:path";
import { eq } from "drizzle-orm";
import { beforeAll, describe, expect, it } from "vitest";
import { monthPeriod } from "@/lib/dates";
import { openPgliteDatabase, type Database } from "./db/client";
import { properties, transactions, workspaces, type Workspace } from "./db/schema";
import { createExpense, deleteExpense, listExpenses } from "./expenses";
import { commitImport, deleteImport, listImports, NEW_PROPERTY, previewImport } from "./imports";
import { createOwner, deleteOwner, listOwners } from "./owners";
import { listProperties, updateProperty, type PropertyInput } from "./properties";
import { loadOwnerStatement, loadStatements } from "./statements";
import { createWorkspace } from "./workspace";

const SAMPLE = readFileSync(path.join(process.cwd(), "public/samples/airbnb-transaction-history-sample.csv"), "utf8");
const ALL_NEW = { "Sunny Loft Downtown": NEW_PROPERTY, "Lakeview Cabin": NEW_PROPERTY, "Beach Bungalow #2": NEW_PROPERTY };

async function freshWorkspace(): Promise<{ db: Database; workspace: Workspace }> {
  const db = await openPgliteDatabase();
  return { db, workspace: await createWorkspace(db, "Harbor Co-Hosting") };
}

function propertyInput(overrides: Partial<PropertyInput>): PropertyInput {
  return {
    name: "Property",
    ownerId: null,
    payoutFlow: "cohost_collects",
    commissionBase: "payout",
    commissionRateBps: 2000,
    excludeCleaningFee: true,
    cleaningFeeTo: "owner",
    flatFeePerReservationCents: 0,
    monthlyFeeCents: 0,
    ...overrides,
  };
}

describe("workspace", () => {
  it("starts with a 14-day free trial and sensible defaults", async () => {
    const db = await openPgliteDatabase();
    const now = new Date("2026-09-01T12:00:00Z");
    const workspace = await createWorkspace(db, "Harbor Co-Hosting", now);
    expect(workspace).toMatchObject({
      name: "Harbor Co-Hosting",
      attributionBasis: "checkin",
      defaultCommissionRateBps: 2000,
      subscriptionStatus: "trialing",
      trialEndsAt: new Date("2026-09-15T12:00:00Z"),
    });
    expect(await db.select().from(workspaces)).toHaveLength(1);
  });
});

describe("importing an Airbnb export", () => {
  let db: Database;
  let workspace: Workspace;
  beforeAll(async () => ({ db, workspace } = await freshWorkspace()));

  it("previews what will be imported", async () => {
    const preview = await previewImport(db, workspace.id, SAMPLE);
    if (!preview.ok) throw new Error(preview.error);
    expect(preview).toMatchObject({
      dateOrder: "MDY",
      rowCount: 29,
      newCount: 15,
      duplicateCount: 0,
      skippedCount: 14,
      errorCount: 0,
      dateRange: { start: "2026-08-04", end: "2026-09-20" },
      currencies: ["USD"],
    });
    expect(preview.listings.map((l) => [l.name, l.rows, l.propertyId])).toEqual([
      ["Beach Bungalow #2", 3, null],
      ["Lakeview Cabin", 5, null],
      ["Sunny Loft Downtown", 7, null],
    ]);
    expect(preview.types.find((t) => t.type === "Payout")).toMatchObject({ count: 13, included: false });
  });

  it("refuses to import while a listing has no property, writing nothing", async () => {
    const result = await commitImport(db, workspace, { csvText: SAMPLE, fileName: "a.csv", mappings: { "Lakeview Cabin": NEW_PROPERTY } });
    expect(result).toEqual({ ok: false, error: 'Choose a property for the listing "Sunny Loft Downtown".' });
    expect(await db.select().from(properties)).toHaveLength(0);
  });

  it("imports, creating one property per new listing", async () => {
    const result = await commitImport(db, workspace, { csvText: SAMPLE, fileName: "sample.csv", mappings: ALL_NEW });
    expect(result).toMatchObject({ ok: true, insertedCount: 15, duplicateCount: 0, skippedCount: 14, errorCount: 0, createdProperties: 3 });
    const props = await listProperties(db, workspace.id);
    expect(props.map((p) => [p.name, p.listingNames, p.transactionCount])).toEqual([
      ["Beach Bungalow #2", ["Beach Bungalow #2"], 3],
      ["Lakeview Cabin", ["Lakeview Cabin"], 5],
      ["Sunny Loft Downtown", ["Sunny Loft Downtown"], 7],
    ]);
  });

  it("skips everything on a second import of the same file", async () => {
    const preview = await previewImport(db, workspace.id, SAMPLE);
    if (!preview.ok) throw new Error(preview.error);
    expect(preview.newCount).toBe(0);
    expect(preview.duplicateCount).toBe(15);
    expect(preview.listings.every((l) => l.propertyId !== null)).toBe(true);

    const again = await commitImport(db, workspace, { csvText: SAMPLE, fileName: "sample-again.csv", mappings: {} });
    expect(again).toMatchObject({ ok: true, insertedCount: 0, duplicateCount: 15, createdProperties: 0 });
    expect(await db.select().from(transactions)).toHaveLength(15);
  });

  it("maps a renamed listing onto an existing property", async () => {
    const [loft] = (await listProperties(db, workspace.id)).filter((p) => p.name === "Sunny Loft Downtown");
    const renamed = SAMPLE.replace("Sunny Loft Downtown,,,USD,504.40,,15.60,,85.00,520.00,62.40,2026\r\n08/04", "Sunny Loft (renamed),,,USD,504.40,,15.60,,85.00,520.00,62.40,2026\r\n08/04");
    const result = await commitImport(db, workspace, { csvText: renamed, fileName: "renamed.csv", mappings: { "Sunny Loft (renamed)": loft.id } });
    expect(result).toMatchObject({ ok: true, insertedCount: 0, createdProperties: 0 });
    expect((await listProperties(db, workspace.id)).find((p) => p.id === loft.id)?.listingNames).toEqual([
      "Sunny Loft (renamed)",
      "Sunny Loft Downtown",
    ]);
  });

  it("builds statements for owners and flags unassigned properties", async () => {
    const owner = await createOwner(db, workspace.id, { name: "Dana Owner", email: "dana@example.com" });
    const props = await listProperties(db, workspace.id);
    for (const p of props.filter((p) => p.name !== "Beach Bungalow #2")) {
      expect(await updateProperty(db, workspace.id, p.id, propertyInput({ name: p.name, ownerId: owner.id }))).toBe("ok");
    }

    const { statements, unassigned } = await loadStatements(db, workspace, monthPeriod("2026-08"));
    expect(statements).toHaveLength(1);
    expect(statements[0].properties.map((p) => p.property.name)).toEqual(["Lakeview Cabin", "Sunny Loft Downtown"]);
    expect(statements[0].totals).toMatchObject({ bookings: 5, nights: 19, payoutCents: 359385, cohostFeesCents: 61977, balanceDueToOwnerCents: 297408 });
    expect(unassigned).toEqual([expect.objectContaining({ propertyName: "Beach Bungalow #2", lines: 2, payoutCents: 175570 })]);

    const september = await loadOwnerStatement(db, workspace, owner.id, monthPeriod("2026-09"));
    const cabin = september!.properties.find((p) => p.property.name === "Lakeview Cabin")!;
    expect(cabin.lines.map((l) => l.transaction.kind)).toEqual(["reservation", "resolution", "reservation"]);
    expect(await loadOwnerStatement(db, workspace, "missing", monthPeriod("2026-09"))).toBeNull();
  });

  it("rejects an owner from another workspace", async () => {
    const [prop] = await listProperties(db, workspace.id);
    expect(await updateProperty(db, workspace.id, prop.id, propertyInput({ ownerId: "not-an-owner" }))).toBe("unknown_owner");
    expect(await updateProperty(db, "other-workspace", prop.id, propertyInput({}))).toBe("not_found");
  });

  it("records and deletes expenses", async () => {
    const [prop] = await listProperties(db, workspace.id);
    const input = { propertyId: prop.id, date: "2026-08-15", category: "Supplies", description: "Soap", amountCents: 1299, paidBy: "cohost" as const };
    expect(await createExpense(db, workspace.id, { ...input, propertyId: "nope" })).toBe("unknown_property");
    expect(await createExpense(db, workspace.id, input)).toBe("ok");
    const [expense] = await listExpenses(db, workspace.id, monthPeriod("2026-08"));
    expect(expense).toMatchObject({ propertyName: prop.name, amountCents: 1299 });
    expect(await listExpenses(db, workspace.id, monthPeriod("2026-09"))).toEqual([]);
    expect(await deleteExpense(db, workspace.id, expense.id)).toBe(true);
    expect(await deleteExpense(db, workspace.id, expense.id)).toBe(false);
  });

  it("unassigns properties when their owner is deleted", async () => {
    const [owner] = await listOwners(db, workspace.id);
    expect(owner.propertyCount).toBe(2);
    expect(await deleteOwner(db, workspace.id, owner.id)).toBe(true);
    expect((await listProperties(db, workspace.id)).every((p) => p.ownerId === null)).toBe(true);
  });

  it("deletes an import together with its transactions", async () => {
    const history = await listImports(db, workspace.id);
    expect(history.map((i) => [i.fileName, i.insertedCount, i.remaining])).toEqual([
      ["renamed.csv", 0, 0],
      ["sample-again.csv", 0, 0],
      ["sample.csv", 15, 15],
    ]);
    const first = history.find((i) => i.fileName === "sample.csv")!;
    expect(await deleteImport(db, workspace.id, first.id)).toBe(true);
    expect(await db.select().from(transactions)).toHaveLength(0);
    expect(await deleteImport(db, workspace.id, first.id)).toBe(false);
  });
});

describe("per-booking flat fees across months", () => {
  it("charges a monthly stay's flat fee only in its first month", async () => {
    const { db, workspace } = await freshWorkspace();
    await db.update(workspaces).set({ attributionBasis: "payout_date" }).where(eq(workspaces.id, workspace.id));
    const cashBasis = { ...workspace, attributionBasis: "payout_date" as const };
    const csv = [
      "Date,Type,Confirmation code,Start date,Nights,Guest,Listing,Currency,Amount,Service fee,Gross earnings",
      "08/02/2026,Reservation,HMMONTH,08/01/2026,31,Long Stay,Loft,USD,2910.00,90.00,3000.00",
      "09/01/2026,Reservation,HMMONTH,08/01/2026,30,Long Stay,Loft,USD,2910.00,90.00,3000.00",
    ].join("\n");
    const result = await commitImport(db, cashBasis, { csvText: csv, fileName: "monthly.csv", mappings: { Loft: NEW_PROPERTY } });
    expect(result).toMatchObject({ ok: true, insertedCount: 2 });

    const owner = await createOwner(db, workspace.id, { name: "Owner", email: null });
    const [loft] = await listProperties(db, workspace.id);
    await updateProperty(db, workspace.id, loft.id, propertyInput({ name: "Loft", ownerId: owner.id, flatFeePerReservationCents: 2500 }));

    const august = await loadOwnerStatement(db, cashBasis, owner.id, monthPeriod("2026-08"));
    const september = await loadOwnerStatement(db, cashBasis, owner.id, monthPeriod("2026-09"));
    expect(august!.totals.flatFeesCents).toBe(2500);
    expect(september!.totals.flatFeesCents).toBe(0);
    expect(september!.totals.commissionCents).toBe(58200);
  });
});
