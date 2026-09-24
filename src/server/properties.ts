import { and, asc, count, eq } from "drizzle-orm";
import type { CleaningFeeRecipient, CommissionBase, CommissionRule, PayoutFlow } from "@/lib/domain";
import type { Database } from "./db/client";
import { listingMappings, owners, properties, transactions, type Property } from "./db/schema";

export function propertyRule(property: Property): CommissionRule {
  return {
    base: property.commissionBase,
    rateBps: property.commissionRateBps,
    excludeCleaningFee: property.excludeCleaningFee,
    cleaningFeeTo: property.cleaningFeeTo,
    flatFeePerReservationCents: property.flatFeePerReservationCents,
    monthlyFeeCents: property.monthlyFeeCents,
  };
}

export interface PropertyListItem extends Property {
  ownerName: string | null;
  listingNames: string[];
  transactionCount: number;
}

export async function listProperties(db: Database, workspaceId: string): Promise<PropertyListItem[]> {
  const [rows, mappings, counts] = await Promise.all([
    db
      .select({ property: properties, ownerName: owners.name })
      .from(properties)
      .leftJoin(owners, eq(owners.id, properties.ownerId))
      .where(eq(properties.workspaceId, workspaceId))
      .orderBy(asc(properties.name)),
    db
      .select({ propertyId: listingMappings.propertyId, listingName: listingMappings.listingName })
      .from(listingMappings)
      .where(eq(listingMappings.workspaceId, workspaceId))
      .orderBy(asc(listingMappings.listingName)),
    db
      .select({ propertyId: transactions.propertyId, n: count() })
      .from(transactions)
      .where(eq(transactions.workspaceId, workspaceId))
      .groupBy(transactions.propertyId),
  ]);
  const countByProperty = new Map(counts.map((c) => [c.propertyId, Number(c.n)]));
  return rows.map(({ property, ownerName }) => ({
    ...property,
    ownerName,
    listingNames: mappings.filter((m) => m.propertyId === property.id).map((m) => m.listingName),
    transactionCount: countByProperty.get(property.id) ?? 0,
  }));
}

export async function getProperty(db: Database, workspaceId: string, propertyId: string): Promise<PropertyListItem | null> {
  const all = await listProperties(db, workspaceId);
  return all.find((p) => p.id === propertyId) ?? null;
}

export interface PropertyInput {
  name: string;
  ownerId: string | null;
  payoutFlow: PayoutFlow;
  commissionBase: CommissionBase;
  commissionRateBps: number;
  excludeCleaningFee: boolean;
  cleaningFeeTo: CleaningFeeRecipient;
  flatFeePerReservationCents: number;
  monthlyFeeCents: number;
}

export async function updateProperty(
  db: Database,
  workspaceId: string,
  propertyId: string,
  input: PropertyInput,
): Promise<"ok" | "not_found" | "unknown_owner"> {
  if (input.ownerId) {
    const [owner] = await db
      .select({ id: owners.id })
      .from(owners)
      .where(and(eq(owners.workspaceId, workspaceId), eq(owners.id, input.ownerId)));
    if (!owner) return "unknown_owner";
  }
  const updated = await db
    .update(properties)
    .set(input)
    .where(and(eq(properties.workspaceId, workspaceId), eq(properties.id, propertyId)))
    .returning({ id: properties.id });
  return updated.length > 0 ? "ok" : "not_found";
}
