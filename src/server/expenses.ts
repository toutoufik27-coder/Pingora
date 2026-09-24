import { randomUUID } from "node:crypto";
import { and, desc, eq, gte, lte } from "drizzle-orm";
import type { ReportPeriod } from "@/lib/dates";
import type { ExpensePaidBy } from "@/lib/domain";
import type { Database } from "./db/client";
import { expenses, properties, type Expense } from "./db/schema";

export interface ExpenseInput {
  propertyId: string;
  date: string;
  category: string;
  description: string;
  amountCents: number;
  paidBy: ExpensePaidBy;
}

export interface ExpenseListItem extends Expense {
  propertyName: string;
}

export async function listExpenses(db: Database, workspaceId: string, period: ReportPeriod): Promise<ExpenseListItem[]> {
  const rows = await db
    .select({ expense: expenses, propertyName: properties.name })
    .from(expenses)
    .innerJoin(properties, eq(properties.id, expenses.propertyId))
    .where(and(eq(expenses.workspaceId, workspaceId), gte(expenses.date, period.start), lte(expenses.date, period.end)))
    .orderBy(desc(expenses.date), desc(expenses.createdAt));
  return rows.map((r) => ({ ...r.expense, propertyName: r.propertyName }));
}

export async function createExpense(
  db: Database,
  workspaceId: string,
  input: ExpenseInput,
): Promise<"ok" | "unknown_property"> {
  const [property] = await db
    .select({ id: properties.id })
    .from(properties)
    .where(and(eq(properties.workspaceId, workspaceId), eq(properties.id, input.propertyId)));
  if (!property) return "unknown_property";
  await db.insert(expenses).values({ id: randomUUID(), workspaceId, ...input });
  return "ok";
}

export async function deleteExpense(db: Database, workspaceId: string, expenseId: string): Promise<boolean> {
  const deleted = await db
    .delete(expenses)
    .where(and(eq(expenses.workspaceId, workspaceId), eq(expenses.id, expenseId)))
    .returning({ id: expenses.id });
  return deleted.length > 0;
}
