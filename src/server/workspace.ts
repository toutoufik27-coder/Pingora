import { eq } from "drizzle-orm";
import type { AttributionBasis, CommissionBase, PayoutFlow } from "@/lib/domain";
import type { Database } from "./db/client";
import { workspaces, type Workspace } from "./db/schema";

/** Until sign-in exists, everything lives in this workspace. */
export const DEFAULT_WORKSPACE_ID = "default";

export async function ensureWorkspace(db: Database, id = DEFAULT_WORKSPACE_ID): Promise<Workspace> {
  const [existing] = await db.select().from(workspaces).where(eq(workspaces.id, id));
  if (existing) return existing;
  await db.insert(workspaces).values({ id, name: "My Co-Hosting Business" }).onConflictDoNothing();
  const [created] = await db.select().from(workspaces).where(eq(workspaces.id, id));
  return created;
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
