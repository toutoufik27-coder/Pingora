"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { failure, success, type ActionState } from "@/lib/action-state";
import { ATTRIBUTION_BASES, COMMISSION_BASES, PAYOUT_FLOWS } from "@/lib/domain";
import { getAppContext } from "../context";
import { updateWorkspaceSettings } from "../workspace";
import { checkboxField, firstIssue, percentField, readFields } from "./fields";

const settingsSchema = z.object({
  name: z.string().trim().min(1, "Enter your business name.").max(200, "That name is too long."),
  attributionBasis: z.enum(ATTRIBUTION_BASES, "Choose how bookings are assigned to months."),
  defaultCommissionBase: z.enum(COMMISSION_BASES, "Choose what the commission is based on."),
  defaultCommissionRate: percentField,
  defaultExcludeCleaningFee: checkboxField,
  defaultPayoutFlow: z.enum(PAYOUT_FLOWS, "Choose who receives the Airbnb payouts."),
});

export async function updateSettingsAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const parsed = settingsSchema.safeParse(
    readFields(formData, [
      "name",
      "attributionBasis",
      "defaultCommissionBase",
      "defaultCommissionRate",
      "defaultExcludeCleaningFee",
      "defaultPayoutFlow",
    ]),
  );
  if (!parsed.success) return failure(firstIssue(parsed.error));
  const { db, workspace } = await getAppContext();
  const { defaultCommissionRate, ...rest } = parsed.data;
  await updateWorkspaceSettings(db, workspace.id, { ...rest, defaultCommissionRateBps: defaultCommissionRate });
  revalidatePath("/", "layout");
  return success("Settings saved.");
}
