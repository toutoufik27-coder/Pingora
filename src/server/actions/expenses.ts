"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { failure, success, type ActionState } from "@/lib/action-state";
import { isValidIsoDate } from "@/lib/dates";
import { EXPENSE_CATEGORIES, EXPENSE_PAYERS } from "@/lib/domain";
import { formatMoney } from "@/lib/money";
import { getAppContext } from "../context";
import { createExpense, deleteExpense } from "../expenses";
import { firstIssue, idField, readFields, requiredMoneyField } from "./fields";

const expenseSchema = z.object({
  propertyId: z.string().min(1, "Choose a property.").max(100),
  date: z.string().refine(isValidIsoDate, "Enter the date of the expense."),
  category: z.enum(EXPENSE_CATEGORIES, "Choose a category."),
  description: z.string().trim().max(500, "Keep the description under 500 characters."),
  amount: requiredMoneyField("Amount"),
  paidBy: z.enum(EXPENSE_PAYERS, "Choose who paid."),
});

export async function createExpenseAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const parsed = expenseSchema.safeParse(
    readFields(formData, ["propertyId", "date", "category", "description", "amount", "paidBy"]),
  );
  if (!parsed.success) return failure(firstIssue(parsed.error));
  const { db, workspace } = await getAppContext();
  const { amount, ...rest } = parsed.data;
  const result = await createExpense(db, workspace.id, { ...rest, amountCents: amount });
  if (result === "unknown_property") return failure("That property no longer exists.");
  revalidatePath("/", "layout");
  return success(`Added ${formatMoney(amount)} ${parsed.data.category.toLowerCase()} expense.`);
}

export async function deleteExpenseAction(expenseId: string): Promise<void> {
  const id = idField.parse(expenseId);
  const { db, workspace } = await getAppContext();
  await deleteExpense(db, workspace.id, id);
  revalidatePath("/", "layout");
}
