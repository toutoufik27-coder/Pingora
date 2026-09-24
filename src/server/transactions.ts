import { randomUUID } from "node:crypto";
import { and, asc, eq, gte, lte, or } from "drizzle-orm";
import type { ReportPeriod } from "@/lib/dates";
import type { TransactionKind } from "@/lib/domain";
import type { Database } from "./db/client";
import { properties, transactions, type Transaction } from "./db/schema";

export interface TransactionListItem extends Transaction {
  propertyName: string;
}

/** Transactions dated within the period, plus bookings checking in during it (as on statements). */
export async function listTransactions(
  db: Database,
  workspaceId: string,
  period: ReportPeriod,
  propertyId?: string,
): Promise<TransactionListItem[]> {
  const rows = await db
    .select({ tx: transactions, propertyName: properties.name })
    .from(transactions)
    .innerJoin(properties, eq(properties.id, transactions.propertyId))
    .where(
      and(
        eq(transactions.workspaceId, workspaceId),
        propertyId ? eq(transactions.propertyId, propertyId) : undefined,
        or(
          and(gte(transactions.date, period.start), lte(transactions.date, period.end)),
          and(eq(transactions.kind, "reservation"), gte(transactions.startDate, period.start), lte(transactions.startDate, period.end)),
        ),
      ),
    )
    .orderBy(asc(transactions.date), asc(transactions.createdAt));
  return rows
    .map((r) => ({ ...r.tx, propertyName: r.propertyName }))
    .sort((a, b) => displayDate(a).localeCompare(displayDate(b)));
}

/** Bookings are listed by check-in, everything else by the date it happened. */
export function displayDate(tx: Pick<Transaction, "kind" | "date" | "startDate">): string {
  return tx.kind === "reservation" ? (tx.startDate ?? tx.date) : tx.date;
}

export interface ManualTransactionInput {
  propertyId: string;
  kind: Extract<TransactionKind, "reservation" | "adjustment">;
  channel: string;
  /** Check-in date for bookings, the date of the adjustment otherwise. */
  date: string;
  nights: number | null;
  guest: string;
  confirmationCode: string;
  details: string;
  /** What the owner's side actually receives from the channel. */
  payoutCents: number;
  /** Fee the channel kept; gross = payout + fee. */
  channelFeeCents: number;
  cleaningFeeCents: number;
}

/** Records a booking or adjustment that did not come from an Airbnb export (direct, VRBO…). */
export async function createManualTransaction(
  db: Database,
  workspaceId: string,
  input: ManualTransactionInput,
): Promise<"ok" | "unknown_property"> {
  const [property] = await db
    .select({ id: properties.id, name: properties.name })
    .from(properties)
    .where(and(eq(properties.workspaceId, workspaceId), eq(properties.id, input.propertyId)));
  if (!property) return "unknown_property";

  const isBooking = input.kind === "reservation";
  await db.insert(transactions).values({
    id: randomUUID(),
    workspaceId,
    importId: null,
    propertyId: property.id,
    fingerprint: `manual:${randomUUID()}`,
    source: "manual",
    channel: input.channel,
    kind: input.kind,
    type: isBooking ? `${input.channel} booking` : `${input.channel} adjustment`,
    date: input.date,
    startDate: isBooking ? input.date : null,
    nights: isBooking ? input.nights : null,
    guest: input.guest,
    listingName: property.name,
    confirmationCode: input.confirmationCode,
    details: input.details,
    currency: "USD",
    amountCents: input.payoutCents,
    serviceFeeCents: input.channelFeeCents,
    cleaningFeeCents: input.cleaningFeeCents,
    grossEarningsCents: input.payoutCents + input.channelFeeCents,
  });
  return "ok";
}

/** Imported rows are removed by undoing their import; only manual entries are deleted one by one. */
export async function deleteManualTransaction(db: Database, workspaceId: string, transactionId: string): Promise<boolean> {
  const deleted = await db
    .delete(transactions)
    .where(and(eq(transactions.workspaceId, workspaceId), eq(transactions.id, transactionId), eq(transactions.source, "manual")))
    .returning({ id: transactions.id });
  return deleted.length > 0;
}
