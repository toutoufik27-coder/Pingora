"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { failure, success, type ActionState } from "@/lib/action-state";
import { CLEANING_FEE_RECIPIENTS, COMMISSION_BASES, PAYOUT_FLOWS } from "@/lib/domain";
import { getAppContext } from "../context";
import { updateProperty } from "../properties";
import { checkboxField, firstIssue, idField, moneyField, percentField, readFields } from "./fields";

const propertySchema = z.object({
  name: z.string().trim().min(1, "Enter a property name.").max(200, "That name is too long."),
  ownerId: z
    .string()
    .max(100)
    .transform((v) => v || null),
  payoutFlow: z.enum(PAYOUT_FLOWS, "Choose who receives the Airbnb payouts."),
  commissionBase: z.enum(COMMISSION_BASES, "Choose what the commission is based on."),
  commissionRate: percentField,
  excludeCleaningFee: checkboxField,
  cleaningFeeTo: z.enum(CLEANING_FEE_RECIPIENTS, "Choose who keeps the cleaning fee."),
  flatFee: moneyField("The per-booking fee"),
  monthlyFee: moneyField("The monthly fee"),
});

const FIELDS = [
  "name",
  "ownerId",
  "payoutFlow",
  "commissionBase",
  "commissionRate",
  "excludeCleaningFee",
  "cleaningFeeTo",
  "flatFee",
  "monthlyFee",
] as const;

export async function updatePropertyAction(propertyId: string, _state: ActionState, formData: FormData): Promise<ActionState> {
  const id = idField.safeParse(propertyId);
  const parsed = propertySchema.safeParse(readFields(formData, FIELDS));
  if (!id.success) return failure("Unknown property.");
  if (!parsed.success) return failure(firstIssue(parsed.error));

  const { db, workspace } = await getAppContext();
  const data = parsed.data;
  const result = await updateProperty(db, workspace.id, id.data, {
    name: data.name,
    ownerId: data.ownerId,
    payoutFlow: data.payoutFlow,
    commissionBase: data.commissionBase,
    commissionRateBps: data.commissionRate,
    excludeCleaningFee: data.excludeCleaningFee,
    cleaningFeeTo: data.cleaningFeeTo,
    flatFeePerReservationCents: data.flatFee,
    monthlyFeeCents: data.monthlyFee,
  });
  if (result === "not_found") return failure("This property no longer exists.");
  if (result === "unknown_owner") return failure("That owner no longer exists. Reload the page and try again.");
  revalidatePath("/", "layout");
  return success("Saved. Statements now use these settings.");
}
