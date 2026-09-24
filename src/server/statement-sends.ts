import { randomUUID } from "node:crypto";
import { and, desc, eq } from "drizzle-orm";
import type { SendMethod } from "@/lib/domain";
import type { OwnerStatement } from "@/lib/statement";
import type { Database } from "./db/client";
import { statementSends, type StatementSend, type StatementSnapshot } from "./db/schema";

export function snapshotOf(statement: OwnerStatement): StatementSnapshot {
  const t = statement.totals;
  return {
    bookings: t.bookings,
    payoutCents: t.payoutCents,
    cohostFeesCents: t.cohostFeesCents,
    expensesCents: t.reimbursableExpensesCents + t.ownerPaidExpensesCents,
    balanceDueToOwnerCents: t.balanceDueToOwnerCents,
  };
}

/** True when the figures moved since the statement was sent (late import, new expense, rule change…). */
export function snapshotChanged(snapshot: StatementSnapshot, statement: OwnerStatement): boolean {
  const now = snapshotOf(statement);
  return (Object.keys(now) as (keyof StatementSnapshot)[]).some((key) => now[key] !== snapshot[key]);
}

export async function recordStatementSend(
  db: Database,
  workspaceId: string,
  statement: OwnerStatement,
  method: SendMethod,
  sentTo: string | null,
): Promise<StatementSend> {
  const [send] = await db
    .insert(statementSends)
    .values({
      id: randomUUID(),
      workspaceId,
      ownerId: statement.owner.id,
      period: statement.period.key,
      method,
      sentTo,
      snapshot: snapshotOf(statement),
    })
    .returning();
  return send;
}

/** Latest delivery of each owner's statement for a month. */
export async function latestSendsForPeriod(db: Database, workspaceId: string, period: string): Promise<Map<string, StatementSend>> {
  const rows = await db
    .select()
    .from(statementSends)
    .where(and(eq(statementSends.workspaceId, workspaceId), eq(statementSends.period, period)))
    .orderBy(desc(statementSends.createdAt));
  const latest = new Map<string, StatementSend>();
  for (const row of rows) if (!latest.has(row.ownerId)) latest.set(row.ownerId, row);
  return latest;
}

export async function sendsForOwnerPeriod(db: Database, workspaceId: string, ownerId: string, period: string): Promise<StatementSend[]> {
  return db
    .select()
    .from(statementSends)
    .where(and(eq(statementSends.workspaceId, workspaceId), eq(statementSends.ownerId, ownerId), eq(statementSends.period, period)))
    .orderBy(desc(statementSends.createdAt));
}

/** Months whose statement was delivered to the owner, newest first. Shown in the owner portal. */
export async function sentPeriodsForOwner(db: Database, ownerId: string): Promise<string[]> {
  const rows = await db
    .selectDistinct({ period: statementSends.period })
    .from(statementSends)
    .where(eq(statementSends.ownerId, ownerId))
    .orderBy(desc(statementSends.period));
  return rows.map((r) => r.period);
}
