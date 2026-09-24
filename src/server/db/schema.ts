import { boolean, date, index, integer, pgTable, text, timestamp, uniqueIndex } from "drizzle-orm/pg-core";
import {
  ATTRIBUTION_BASES,
  CLEANING_FEE_RECIPIENTS,
  COMMISSION_BASES,
  EXPENSE_PAYERS,
  PAYOUT_FLOWS,
  TRANSACTION_KINDS,
} from "../../lib/domain";

/**
 * Every table carries a workspace id: one workspace is one co-hosting business.
 * Until sign-in exists the app uses a single default workspace (see
 * src/server/workspace.ts); the column keeps the data ready for many tenants.
 * Money is stored in integer cents, dates as ISO calendar dates.
 */

const createdAt = () => timestamp("created_at", { withTimezone: true }).notNull().defaultNow();

export const workspaces = pgTable("workspaces", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  attributionBasis: text("attribution_basis", { enum: ATTRIBUTION_BASES }).notNull().default("checkin"),
  // Defaults copied into properties created from an import.
  defaultCommissionBase: text("default_commission_base", { enum: COMMISSION_BASES }).notNull().default("payout"),
  defaultCommissionRateBps: integer("default_commission_rate_bps").notNull().default(2000),
  defaultExcludeCleaningFee: boolean("default_exclude_cleaning_fee").notNull().default(true),
  defaultPayoutFlow: text("default_payout_flow", { enum: PAYOUT_FLOWS }).notNull().default("cohost_collects"),
  createdAt: createdAt(),
});

export const owners = pgTable(
  "owners",
  {
    id: text("id").primaryKey(),
    workspaceId: text("workspace_id")
      .notNull()
      .references(() => workspaces.id, { onDelete: "cascade" }),
    name: text("name").notNull(),
    email: text("email"),
    createdAt: createdAt(),
  },
  (t) => [index("owners_workspace_idx").on(t.workspaceId)],
);

export const properties = pgTable(
  "properties",
  {
    id: text("id").primaryKey(),
    workspaceId: text("workspace_id")
      .notNull()
      .references(() => workspaces.id, { onDelete: "cascade" }),
    ownerId: text("owner_id").references(() => owners.id, { onDelete: "set null" }),
    name: text("name").notNull(),
    commissionBase: text("commission_base", { enum: COMMISSION_BASES }).notNull().default("payout"),
    commissionRateBps: integer("commission_rate_bps").notNull().default(2000),
    excludeCleaningFee: boolean("exclude_cleaning_fee").notNull().default(true),
    cleaningFeeTo: text("cleaning_fee_to", { enum: CLEANING_FEE_RECIPIENTS }).notNull().default("owner"),
    flatFeePerReservationCents: integer("flat_fee_per_reservation_cents").notNull().default(0),
    monthlyFeeCents: integer("monthly_fee_cents").notNull().default(0),
    payoutFlow: text("payout_flow", { enum: PAYOUT_FLOWS }).notNull().default("cohost_collects"),
    createdAt: createdAt(),
  },
  (t) => [index("properties_workspace_idx").on(t.workspaceId), index("properties_owner_idx").on(t.ownerId)],
);

/** Airbnb listing names (including old names after a rename) that belong to a property. */
export const listingMappings = pgTable(
  "listing_mappings",
  {
    id: text("id").primaryKey(),
    workspaceId: text("workspace_id")
      .notNull()
      .references(() => workspaces.id, { onDelete: "cascade" }),
    listingName: text("listing_name").notNull(),
    propertyId: text("property_id")
      .notNull()
      .references(() => properties.id, { onDelete: "cascade" }),
  },
  (t) => [uniqueIndex("listing_mappings_workspace_listing_uq").on(t.workspaceId, t.listingName)],
);

export const imports = pgTable(
  "imports",
  {
    id: text("id").primaryKey(),
    workspaceId: text("workspace_id")
      .notNull()
      .references(() => workspaces.id, { onDelete: "cascade" }),
    fileName: text("file_name").notNull(),
    /** Data rows in the file. */
    rowCount: integer("row_count").notNull(),
    insertedCount: integer("inserted_count").notNull(),
    duplicateCount: integer("duplicate_count").notNull(),
    /** Payout and tax lines, which are not revenue. */
    skippedCount: integer("skipped_count").notNull(),
    errorCount: integer("error_count").notNull(),
    createdAt: createdAt(),
  },
  (t) => [index("imports_workspace_idx").on(t.workspaceId)],
);

export const transactions = pgTable(
  "transactions",
  {
    id: text("id").primaryKey(),
    workspaceId: text("workspace_id")
      .notNull()
      .references(() => workspaces.id, { onDelete: "cascade" }),
    importId: text("import_id")
      .notNull()
      .references(() => imports.id, { onDelete: "cascade" }),
    propertyId: text("property_id")
      .notNull()
      .references(() => properties.id, { onDelete: "cascade" }),
    fingerprint: text("fingerprint").notNull(),
    kind: text("kind", { enum: TRANSACTION_KINDS }).notNull(),
    type: text("type").notNull(),
    date: date("date", { mode: "string" }).notNull(),
    bookingDate: date("booking_date", { mode: "string" }),
    startDate: date("start_date", { mode: "string" }),
    endDate: date("end_date", { mode: "string" }),
    nights: integer("nights"),
    guest: text("guest").notNull().default(""),
    listingName: text("listing_name").notNull(),
    confirmationCode: text("confirmation_code").notNull().default(""),
    details: text("details").notNull().default(""),
    referenceCode: text("reference_code").notNull().default(""),
    currency: text("currency").notNull().default("USD"),
    amountCents: integer("amount_cents").notNull(),
    serviceFeeCents: integer("service_fee_cents").notNull().default(0),
    fastPayFeeCents: integer("fast_pay_fee_cents").notNull().default(0),
    cleaningFeeCents: integer("cleaning_fee_cents").notNull().default(0),
    grossEarningsCents: integer("gross_earnings_cents"),
    occupancyTaxesCents: integer("occupancy_taxes_cents").notNull().default(0),
    createdAt: createdAt(),
  },
  (t) => [
    uniqueIndex("transactions_workspace_fingerprint_uq").on(t.workspaceId, t.fingerprint),
    index("transactions_property_date_idx").on(t.propertyId, t.date),
    index("transactions_property_start_idx").on(t.propertyId, t.startDate),
    index("transactions_import_idx").on(t.importId),
  ],
);

export const expenses = pgTable(
  "expenses",
  {
    id: text("id").primaryKey(),
    workspaceId: text("workspace_id")
      .notNull()
      .references(() => workspaces.id, { onDelete: "cascade" }),
    propertyId: text("property_id")
      .notNull()
      .references(() => properties.id, { onDelete: "cascade" }),
    date: date("date", { mode: "string" }).notNull(),
    category: text("category").notNull(),
    description: text("description").notNull().default(""),
    amountCents: integer("amount_cents").notNull(),
    paidBy: text("paid_by", { enum: EXPENSE_PAYERS }).notNull(),
    createdAt: createdAt(),
  },
  (t) => [index("expenses_property_date_idx").on(t.propertyId, t.date)],
);

export type Workspace = typeof workspaces.$inferSelect;
export type Owner = typeof owners.$inferSelect;
export type Property = typeof properties.$inferSelect;
export type ListingMapping = typeof listingMappings.$inferSelect;
export type ImportRecord = typeof imports.$inferSelect;
export type Transaction = typeof transactions.$inferSelect;
export type Expense = typeof expenses.$inferSelect;
