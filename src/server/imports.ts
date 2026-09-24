import { randomUUID } from "node:crypto";
import { and, asc, count, desc, eq, inArray } from "drizzle-orm";
import { parseAirbnbCsv, type AirbnbTransaction, type RowError } from "@/lib/airbnb/parse";
import type { DateOrder } from "@/lib/dates";
import type { TransactionKind } from "@/lib/domain";
import type { Database } from "./db/client";
import { imports, listingMappings, properties, transactions, type ImportRecord, type Workspace } from "./db/schema";

/** Payouts are bank transfers and pass-through taxes belong to the city; neither is revenue. */
function isStored(kind: TransactionKind): boolean {
  return kind !== "payout" && kind !== "tax";
}

export const NEW_PROPERTY = "new";

export interface ImportTypeSummary {
  type: string;
  kind: TransactionKind;
  count: number;
  included: boolean;
}

export interface ImportListingSummary {
  name: string;
  rows: number;
  propertyId: string | null;
  propertyName: string | null;
}

export type ImportPreview =
  | {
      ok: true;
      dateOrder: DateOrder;
      dateOrderSource: string;
      rowCount: number;
      types: ImportTypeSummary[];
      listings: ImportListingSummary[];
      newCount: number;
      duplicateCount: number;
      skippedCount: number;
      errorCount: number;
      /** First errors only, to keep the response small. */
      rowErrors: RowError[];
      dateRange: { start: string; end: string } | null;
      currencies: string[];
      properties: { id: string; name: string }[];
    }
  | { ok: false; error: string };

export interface ImportOptions {
  dateOrder?: DateOrder;
}

async function existingFingerprints(db: Database, workspaceId: string, fingerprints: string[]): Promise<Set<string>> {
  const found = new Set<string>();
  for (let i = 0; i < fingerprints.length; i += 1000) {
    const chunk = fingerprints.slice(i, i + 1000);
    const rows = await db
      .select({ fingerprint: transactions.fingerprint })
      .from(transactions)
      .where(and(eq(transactions.workspaceId, workspaceId), inArray(transactions.fingerprint, chunk)));
    for (const row of rows) found.add(row.fingerprint);
  }
  return found;
}

async function mappingsByListing(db: Database, workspaceId: string): Promise<Map<string, { propertyId: string; propertyName: string }>> {
  const rows = await db
    .select({ listingName: listingMappings.listingName, propertyId: properties.id, propertyName: properties.name })
    .from(listingMappings)
    .innerJoin(properties, eq(properties.id, listingMappings.propertyId))
    .where(eq(listingMappings.workspaceId, workspaceId));
  return new Map(rows.map((r) => [r.listingName, { propertyId: r.propertyId, propertyName: r.propertyName }]));
}

export async function previewImport(
  db: Database,
  workspaceId: string,
  csvText: string,
  options: ImportOptions = {},
): Promise<ImportPreview> {
  const parsed = parseAirbnbCsv(csvText, { dateOrder: options.dateOrder });
  if (!parsed.ok) return parsed;

  const stored = parsed.transactions.filter((t) => isStored(t.kind));
  const [existing, mappings, propertyRows] = await Promise.all([
    existingFingerprints(
      db,
      workspaceId,
      stored.map((t) => t.fingerprint),
    ),
    mappingsByListing(db, workspaceId),
    db
      .select({ id: properties.id, name: properties.name })
      .from(properties)
      .where(eq(properties.workspaceId, workspaceId))
      .orderBy(asc(properties.name)),
  ]);

  const types = new Map<string, ImportTypeSummary>();
  for (const t of parsed.transactions) {
    const summary = types.get(t.type) ?? { type: t.type, kind: t.kind, count: 0, included: isStored(t.kind) };
    summary.count++;
    types.set(t.type, summary);
  }

  const listingRows = new Map<string, number>();
  for (const t of stored) listingRows.set(t.listing, (listingRows.get(t.listing) ?? 0) + 1);
  const listings = [...listingRows.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([name, rows]) => {
      const mapping = mappings.get(name);
      return { name, rows, propertyId: mapping?.propertyId ?? null, propertyName: mapping?.propertyName ?? null };
    });

  const dates = parsed.transactions.map((t) => t.date).sort();
  const duplicateCount = stored.filter((t) => existing.has(t.fingerprint)).length;
  return {
    ok: true,
    dateOrder: parsed.dateOrder,
    dateOrderSource: parsed.dateOrderSource,
    rowCount: parsed.transactions.length + parsed.rowErrors.length,
    types: [...types.values()].sort((a, b) => b.count - a.count),
    listings,
    newCount: stored.length - duplicateCount,
    duplicateCount,
    skippedCount: parsed.transactions.length - stored.length,
    errorCount: parsed.rowErrors.length,
    rowErrors: parsed.rowErrors.slice(0, 20),
    dateRange: dates.length > 0 ? { start: dates[0], end: dates[dates.length - 1] } : null,
    currencies: [...new Set(stored.map((t) => t.currency))].sort(),
    properties: propertyRows,
  };
}

export interface CommitImportInput extends ImportOptions {
  csvText: string;
  fileName: string;
  /** Listing name → existing property id, or NEW_PROPERTY to create one named after the listing. */
  mappings: Record<string, string>;
}

export type CommitImportResult =
  | {
      ok: true;
      importId: string;
      insertedCount: number;
      duplicateCount: number;
      skippedCount: number;
      errorCount: number;
      createdProperties: number;
    }
  | { ok: false; error: string };

export async function commitImport(db: Database, workspace: Workspace, input: CommitImportInput): Promise<CommitImportResult> {
  const parsed = parseAirbnbCsv(input.csvText, { dateOrder: input.dateOrder });
  if (!parsed.ok) return parsed;

  const stored = parsed.transactions.filter((t) => isStored(t.kind));
  const listingNames = [...new Set(stored.map((t) => t.listing))];

  // Resolve every listing before writing anything, so a bad choice leaves no partial import.
  const existingMappings = await mappingsByListing(db, workspace.id);
  const workspaceProperties = new Set(
    (await db.select({ id: properties.id }).from(properties).where(eq(properties.workspaceId, workspace.id))).map((p) => p.id),
  );
  const propertyForListing = new Map<string, string>();
  const newMappings: { listing: string; propertyId: string; create: boolean }[] = [];
  for (const listing of listingNames) {
    const known = existingMappings.get(listing);
    if (known) {
      propertyForListing.set(listing, known.propertyId);
      continue;
    }
    const target = Object.hasOwn(input.mappings, listing) ? input.mappings[listing] : undefined;
    if (!target) return { ok: false, error: `Choose a property for the listing "${listing}".` };
    if (target !== NEW_PROPERTY && !workspaceProperties.has(target)) {
      return { ok: false, error: `Unknown property selected for "${listing}".` };
    }
    const propertyId = target === NEW_PROPERTY ? randomUUID() : target;
    propertyForListing.set(listing, propertyId);
    newMappings.push({ listing, propertyId, create: target === NEW_PROPERTY });
  }

  const importId = randomUUID();
  const rows = stored.map((t) => toRow(t, workspace.id, importId, propertyForListing.get(t.listing)!));
  const skippedCount = parsed.transactions.length - stored.length;
  const errorCount = parsed.rowErrors.length;

  return db.transaction(async (tx) => {
    for (const mapping of newMappings) {
      if (mapping.create) {
        await tx.insert(properties).values({
          id: mapping.propertyId,
          workspaceId: workspace.id,
          name: mapping.listing,
          commissionBase: workspace.defaultCommissionBase,
          commissionRateBps: workspace.defaultCommissionRateBps,
          excludeCleaningFee: workspace.defaultExcludeCleaningFee,
          payoutFlow: workspace.defaultPayoutFlow,
        });
      }
      await tx.insert(listingMappings).values({
        id: randomUUID(),
        workspaceId: workspace.id,
        listingName: mapping.listing,
        propertyId: mapping.propertyId,
      });
    }

    // The import record goes in first so transactions can reference it; counts are set after.
    await tx.insert(imports).values({
      id: importId,
      workspaceId: workspace.id,
      fileName: input.fileName,
      rowCount: parsed.transactions.length + errorCount,
      insertedCount: 0,
      duplicateCount: 0,
      skippedCount,
      errorCount,
    });
    let insertedCount = 0;
    for (let i = 0; i < rows.length; i += 500) {
      const inserted = await tx
        .insert(transactions)
        .values(rows.slice(i, i + 500))
        .onConflictDoNothing({ target: [transactions.workspaceId, transactions.fingerprint] })
        .returning({ id: transactions.id });
      insertedCount += inserted.length;
    }
    const duplicateCount = rows.length - insertedCount;
    await tx.update(imports).set({ insertedCount, duplicateCount }).where(eq(imports.id, importId));

    return {
      ok: true as const,
      importId,
      insertedCount,
      duplicateCount,
      skippedCount,
      errorCount,
      createdProperties: newMappings.filter((m) => m.create).length,
    };
  });
}

function toRow(t: AirbnbTransaction, workspaceId: string, importId: string, propertyId: string): typeof transactions.$inferInsert {
  return {
    id: randomUUID(),
    workspaceId,
    importId,
    propertyId,
    fingerprint: t.fingerprint,
    kind: t.kind,
    type: t.type,
    date: t.date,
    bookingDate: t.bookingDate,
    startDate: t.startDate,
    endDate: t.endDate,
    nights: t.nights,
    guest: t.guest,
    listingName: t.listing,
    confirmationCode: t.confirmationCode,
    details: t.details,
    referenceCode: t.referenceCode,
    currency: t.currency,
    amountCents: t.amountCents,
    serviceFeeCents: t.serviceFeeCents,
    fastPayFeeCents: t.fastPayFeeCents,
    cleaningFeeCents: t.cleaningFeeCents,
    grossEarningsCents: t.grossEarningsCents,
    occupancyTaxesCents: t.occupancyTaxesCents,
  };
}

export interface ImportListItem extends ImportRecord {
  /** Transactions from this import still in the database. */
  remaining: number;
}

export async function listImports(db: Database, workspaceId: string): Promise<ImportListItem[]> {
  const rows = await db
    .select({ record: imports, remaining: count(transactions.id) })
    .from(imports)
    .leftJoin(transactions, eq(transactions.importId, imports.id))
    .where(eq(imports.workspaceId, workspaceId))
    .groupBy(imports.id)
    .orderBy(desc(imports.createdAt));
  return rows.map((r) => ({ ...r.record, remaining: Number(r.remaining) }));
}

/** Removes an import and every transaction it added. */
export async function deleteImport(db: Database, workspaceId: string, importId: string): Promise<boolean> {
  const deleted = await db
    .delete(imports)
    .where(and(eq(imports.workspaceId, workspaceId), eq(imports.id, importId)))
    .returning({ id: imports.id });
  return deleted.length > 0;
}
