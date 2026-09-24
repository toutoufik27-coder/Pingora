import { and, asc, eq, gte, inArray, lt, lte, or } from "drizzle-orm";
import type { ReportPeriod } from "@/lib/dates";
import { STATEMENT_KINDS } from "@/lib/domain";
import {
  attributionDate,
  buildOwnerStatement,
  type OwnerStatement,
  type StatementExpense,
  type StatementProperty,
  type StatementTransaction,
} from "@/lib/statement";
import type { Database } from "./db/client";
import { expenses, owners, properties, transactions, type Owner, type Property, type Transaction, type Workspace } from "./db/schema";
import { propertyRule } from "./properties";

function toStatementProperty(property: Property): StatementProperty {
  return { id: property.id, name: property.name, rule: propertyRule(property), payoutFlow: property.payoutFlow };
}

function toStatementTransaction(row: Transaction): StatementTransaction {
  return {
    id: row.id,
    propertyId: row.propertyId,
    kind: row.kind,
    type: row.type,
    date: row.date,
    startDate: row.startDate,
    endDate: row.endDate,
    nights: row.nights,
    guest: row.guest,
    confirmationCode: row.confirmationCode,
    details: row.details,
    currency: row.currency,
    amountCents: row.amountCents,
    grossEarningsCents: row.grossEarningsCents,
    serviceFeeCents: row.serviceFeeCents,
    fastPayFeeCents: row.fastPayFeeCents,
    cleaningFeeCents: row.cleaningFeeCents,
  };
}

function toStatementOwner(owner: Owner) {
  return { id: owner.id, name: owner.name, email: owner.email };
}

/** Everything that could land in the period; the statement builder does the exact filtering. */
async function periodTransactions(db: Database, workspaceId: string, propertyIds: string[], period: ReportPeriod): Promise<Transaction[]> {
  if (propertyIds.length === 0) return [];
  return db
    .select()
    .from(transactions)
    .where(
      and(
        eq(transactions.workspaceId, workspaceId),
        inArray(transactions.propertyId, propertyIds),
        inArray(transactions.kind, [...STATEMENT_KINDS]),
        or(
          and(gte(transactions.date, period.start), lte(transactions.date, period.end)),
          and(gte(transactions.startDate, period.start), lte(transactions.startDate, period.end)),
        ),
      ),
    )
    .orderBy(asc(transactions.date));
}

/** Bookings in the period whose per-booking flat fee was already charged in an earlier period. */
async function flatFeeChargedCodes(
  db: Database,
  workspace: Workspace,
  propertyIds: string[],
  period: ReportPeriod,
  rows: Transaction[],
): Promise<Set<string>> {
  const codes = [...new Set(rows.filter((r) => r.kind === "reservation" && r.confirmationCode).map((r) => r.confirmationCode))];
  if (codes.length === 0) return new Set();
  const earlier = await db
    .select({ kind: transactions.kind, date: transactions.date, startDate: transactions.startDate, code: transactions.confirmationCode })
    .from(transactions)
    .where(
      and(
        eq(transactions.workspaceId, workspace.id),
        inArray(transactions.propertyId, propertyIds),
        eq(transactions.kind, "reservation"),
        inArray(transactions.confirmationCode, codes),
        or(lt(transactions.date, period.start), lt(transactions.startDate, period.start)),
      ),
    );
  return new Set(earlier.filter((r) => attributionDate(r, workspace.attributionBasis) < period.start).map((r) => r.code));
}

export interface UnassignedActivity {
  propertyId: string;
  propertyName: string;
  lines: number;
  payoutCents: number;
}

export interface StatementsResult {
  statements: OwnerStatement[];
  /** Properties with activity in the period but no owner, so missing from every statement. */
  unassigned: UnassignedActivity[];
}

export async function loadStatements(
  db: Database,
  workspace: Workspace,
  period: ReportPeriod,
  onlyOwnerId?: string,
): Promise<StatementsResult> {
  const [ownerRows, propertyRows] = await Promise.all([
    db
      .select()
      .from(owners)
      .where(and(eq(owners.workspaceId, workspace.id), onlyOwnerId ? eq(owners.id, onlyOwnerId) : undefined))
      .orderBy(asc(owners.name)),
    db.select().from(properties).where(eq(properties.workspaceId, workspace.id)).orderBy(asc(properties.name)),
  ]);

  const relevant = onlyOwnerId ? propertyRows.filter((p) => p.ownerId === onlyOwnerId) : propertyRows;
  const propertyIds = relevant.map((p) => p.id);
  const [txRows, expenseRows] = await Promise.all([
    periodTransactions(db, workspace.id, propertyIds, period),
    propertyIds.length === 0
      ? []
      : db
          .select()
          .from(expenses)
          .where(
            and(
              eq(expenses.workspaceId, workspace.id),
              inArray(expenses.propertyId, propertyIds),
              gte(expenses.date, period.start),
              lte(expenses.date, period.end),
            ),
          ),
  ]);
  const charged = await flatFeeChargedCodes(db, workspace, propertyIds, period, txRows);

  const statementTransactions = txRows.map(toStatementTransaction);
  const statementExpenses: StatementExpense[] = expenseRows.map((e) => ({
    id: e.id,
    propertyId: e.propertyId,
    date: e.date,
    category: e.category,
    description: e.description,
    amountCents: e.amountCents,
    paidBy: e.paidBy,
  }));

  const build = (owner: { id: string; name: string; email: string | null }, props: Property[]) =>
    buildOwnerStatement({
      period,
      basis: workspace.attributionBasis,
      owner,
      properties: props.map(toStatementProperty),
      transactions: statementTransactions,
      expenses: statementExpenses,
      flatFeeChargedCodes: charged,
    });

  const statements = ownerRows.map((owner) =>
    build(
      toStatementOwner(owner),
      propertyRows.filter((p) => p.ownerId === owner.id),
    ),
  );

  const unassignedProps = propertyRows.filter((p) => p.ownerId === null);
  const unassigned =
    onlyOwnerId || unassignedProps.length === 0
      ? []
      : build({ id: "", name: "Unassigned", email: null }, unassignedProps)
          .properties.filter((p) => p.lines.length > 0)
          .map((p) => ({
            propertyId: p.property.id,
            propertyName: p.property.name,
            lines: p.lines.length,
            payoutCents: p.totals.payoutCents,
          }));

  return { statements, unassigned };
}

export async function loadOwnerStatement(
  db: Database,
  workspace: Workspace,
  ownerId: string,
  period: ReportPeriod,
): Promise<OwnerStatement | null> {
  const { statements } = await loadStatements(db, workspace, period, ownerId);
  return statements[0] ?? null;
}
