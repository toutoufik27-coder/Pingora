import { randomUUID } from "node:crypto";
import { and, asc, count, eq } from "drizzle-orm";
import type { Database } from "./db/client";
import { owners, properties, type Owner } from "./db/schema";

export interface OwnerInput {
  name: string;
  email: string | null;
}

export interface OwnerListItem extends Owner {
  propertyCount: number;
}

export async function listOwners(db: Database, workspaceId: string): Promise<OwnerListItem[]> {
  const rows = await db
    .select({ owner: owners, propertyCount: count(properties.id) })
    .from(owners)
    .leftJoin(properties, eq(properties.ownerId, owners.id))
    .where(eq(owners.workspaceId, workspaceId))
    .groupBy(owners.id)
    .orderBy(asc(owners.name));
  return rows.map((r) => ({ ...r.owner, propertyCount: Number(r.propertyCount) }));
}

export async function getOwner(db: Database, workspaceId: string, ownerId: string): Promise<Owner | null> {
  const [owner] = await db
    .select()
    .from(owners)
    .where(and(eq(owners.workspaceId, workspaceId), eq(owners.id, ownerId)));
  return owner ?? null;
}

export async function createOwner(db: Database, workspaceId: string, input: OwnerInput): Promise<Owner> {
  const [owner] = await db
    .insert(owners)
    .values({ id: randomUUID(), workspaceId, ...input })
    .returning();
  return owner;
}

export async function updateOwner(db: Database, workspaceId: string, ownerId: string, input: OwnerInput): Promise<boolean> {
  const updated = await db
    .update(owners)
    .set(input)
    .where(and(eq(owners.workspaceId, workspaceId), eq(owners.id, ownerId)))
    .returning({ id: owners.id });
  return updated.length > 0;
}

/** Properties of a deleted owner become unassigned; their bookings are kept. */
export async function deleteOwner(db: Database, workspaceId: string, ownerId: string): Promise<boolean> {
  const deleted = await db
    .delete(owners)
    .where(and(eq(owners.workspaceId, workspaceId), eq(owners.id, ownerId)))
    .returning({ id: owners.id });
  return deleted.length > 0;
}
