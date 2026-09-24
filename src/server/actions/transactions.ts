"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { failure, success, type ActionState } from "@/lib/action-state";
import { isValidIsoDate } from "@/lib/dates";
import { MANUAL_CHANNELS } from "@/lib/domain";
import { formatMoney, parseMoney } from "@/lib/money";
import { getAppContext } from "../context";
import { deleteProperty } from "../properties";
import { createManualTransaction, deleteManualTransaction } from "../transactions";
import { firstIssue, idField, moneyField, readFields } from "./fields";

/** Signed amount: refunds are negative. */
const signedMoney = z.string().transform((value, ctx) => {
  try {
    const cents = parseMoney(value);
    if (cents === null || cents === 0) throw new Error("empty");
    return cents;
  } catch {
    ctx.addIssue({ code: "custom", message: "Enter the payout amount, like 450 or -60 for a refund." });
    return z.NEVER;
  }
});

const manualSchema = z.object({
  propertyId: z.string().min(1, "Choose a property.").max(100),
  kind: z.enum(["reservation", "adjustment"], "Choose a booking or an adjustment."),
  channel: z.enum(MANUAL_CHANNELS, "Choose where the booking came from."),
  date: z.string().refine(isValidIsoDate, "Enter the date."),
  nights: z.string().transform((value, ctx) => {
    if (value.trim() === "") return null;
    const n = Number(value);
    if (!Number.isInteger(n) || n < 0 || n > 366) {
      ctx.addIssue({ code: "custom", message: "Nights must be a whole number." });
      return z.NEVER;
    }
    return n;
  }),
  guest: z.string().trim().max(200),
  confirmationCode: z.string().trim().max(100),
  details: z.string().trim().max(500),
  payout: signedMoney,
  channelFee: moneyField("The channel fee"),
  cleaningFee: moneyField("The cleaning fee"),
});

export async function createManualTransactionAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const parsed = manualSchema.safeParse(
    readFields(formData, ["propertyId", "kind", "channel", "date", "nights", "guest", "confirmationCode", "details", "payout", "channelFee", "cleaningFee"]),
  );
  if (!parsed.success) return failure(firstIssue(parsed.error));
  const { db, workspace } = await getAppContext();
  const { payout, channelFee, cleaningFee, ...rest } = parsed.data;
  const result = await createManualTransaction(db, workspace.id, {
    ...rest,
    payoutCents: payout,
    channelFeeCents: channelFee,
    cleaningFeeCents: cleaningFee,
  });
  if (result === "unknown_property") return failure("That property no longer exists.");
  revalidatePath("/", "layout");
  return success(`Added ${rest.channel} ${rest.kind === "reservation" ? "booking" : "adjustment"} of ${formatMoney(payout)}.`);
}

export async function deleteManualTransactionAction(transactionId: string): Promise<void> {
  const id = idField.parse(transactionId);
  const { db, workspace } = await getAppContext();
  await deleteManualTransaction(db, workspace.id, id);
  revalidatePath("/", "layout");
}

export async function deletePropertyAction(propertyId: string): Promise<void> {
  const id = idField.parse(propertyId);
  const { db, workspace } = await getAppContext();
  await deleteProperty(db, workspace.id, id);
  revalidatePath("/", "layout");
  redirect("/properties");
}
