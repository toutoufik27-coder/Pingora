import { randomUUID } from "node:crypto";
import { eq } from "drizzle-orm";
import { trialEndFrom } from "@/lib/billing";
import type { AttributionBasis, CommissionBase, PayoutFlow } from "@/lib/domain";
import type { Database } from "./db/client";
import { workspaces, type Workspace } from "./db/schema";

/** Creates a co-hosting business with a fresh free trial. */
export async function createWorkspace(db: Database, name: string, now = new Date()): Promise<Workspace> {
  const [workspace] = await db
    .insert(workspaces)
    .values({ id: randomUUID(), name, subscriptionStatus: "trialing", trialEndsAt: trialEndFrom(now) })
    .returning();
  return workspace;
}

export async function getWorkspace(db: Database, id: string): Promise<Workspace | null> {
  const [workspace] = await db.select().from(workspaces).where(eq(workspaces.id, id));
  return workspace ?? null;
}

export interface WorkspaceSettingsInput {
  name: string;
  attributionBasis: AttributionBasis;
  defaultCommissionBase: CommissionBase;
  defaultCommissionRateBps: number;
  defaultExcludeCleaningFee: boolean;
  defaultPayoutFlow: PayoutFlow;
}

export async function updateWorkspaceSettings(db: Database, workspaceId: string, input: WorkspaceSettingsInput): Promise<void> {
  await db.update(workspaces).set(input).where(eq(workspaces.id, workspaceId));
}
