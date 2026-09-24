import { boolean, date, index, integer, jsonb, pgTable, text, timestamp, uniqueIndex } from "drizzle-orm/pg-core";
import { SUBSCRIPTION_STATUSES } from "../../lib/billing";
import {
  ATTRIBUTION_BASES,
  CLEANING_FEE_RECIPIENTS,
  COMMISSION_BASES,
  EXPENSE_PAYERS,
  PAYOUT_FLOWS,
  SEND_METHODS,
  TRANSACTION_KINDS,
  TRANSACTION_SOURCES,
} from "../../lib/domain";

/**
 * One workspace is one co-hosting business (a paying customer). Every business
 * table carries a workspace id and every query filters on it.
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
  // Subscription state, kept in sync by the billing provider's webhooks.
  subscriptionStatus: text("subscription_status", { enum: SUBSCRIPTION_STATUSES }).notNull().default("trialing"),
  trialEndsAt: timestamp("trial_ends_at", { withTimezone: true }),
  currentPeriodEndsAt: timestamp("current_period_ends_at", { withTimezone: true }),
  billingCustomerId: text("billing_customer_id"),
  billingSubscriptionId: text("billing_subscription_id"),
  billingPortalUrl: text("billing_portal_url"),
  /** `updated_at` of the last applied subscription event; older events arriving late are ignored. */
  billingUpdatedAt: timestamp("billing_updated_at", { withTimezone: true }),
  createdAt: createdAt(),
});

export const users = pgTable(
  "users",
  {
    id: text("id").primaryKey(),
    workspaceId: text("workspace_id")
      .notNull()
      .references(() => workspaces.id, { onDelete: "cascade" }),
    /** Always stored lowercased. */
    email: text("email").notNull(),
    name: text("name").notNull(),
    passwordHash: text("password_hash").notNull(),
    createdAt: createdAt(),
  },
  (t) => [uniqueIndex("users_email_uq").on(t.email), index("users_workspace_idx").on(t.workspaceId)],
);

/** Sessions are looked up by the SHA-256 of the cookie token, so a database leak exposes no usable session. */
export const sessions = pgTable(
  "sessions",
  {
    id: text("id").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    createdAt: createdAt(),
  },
  (t) => [index("sessions_user_idx").on(t.userId)],
);

/** Single-use tokens (password reset), also stored hashed. */
export const authTokens = pgTable(
  "auth_tokens",
  {
    id: text("id").primaryKey(),
    userId: text("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    purpose: text("purpose", { enum: ["password_reset"] }).notNull(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    usedAt: timestamp("used_at", { withTimezone: true }),
    createdAt: createdAt(),
  },
  (t) => [index("auth_tokens_user_idx").on(t.userId)],
);

/** One row per attempt of a rate-limited action (login, sign-up, password reset). */
export const rateLimitHits = pgTable(
  "rate_limit_hits",
  {
    id: text("id").primaryKey(),
    key: text("key").notNull(),
    createdAt: createdAt(),
  },
  (t) => [index("rate_limit_hits_key_idx").on(t.key, t.createdAt)],
);

export const owners = pgTable(
  "owners",
  {
    id: text("id").primaryKey(),
    workspaceId: text("workspace_id")
      .notNull()
      .references(() => workspaces.id, { onDelete: "cascade" }),
    name: text("name").notNull(),
    email: text("email"),
    /** Secret for the owner's read-only statement page; null when no link is shared. */
    portalToken: text("portal_token"),
    createdAt: createdAt(),
  },
  (t) => [index("owners_workspace_idx").on(t.workspaceId), uniqueIndex("owners_portal_token_uq").on(t.portalToken)],
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
    /** Null for bookings entered by hand. */
    importId: text("import_id").references(() => imports.id, { onDelete: "cascade" }),
    propertyId: text("property_id")
      .notNull()
      .references(() => properties.id, { onDelete: "cascade" }),
    fingerprint: text("fingerprint").notNull(),
    source: text("source", { enum: TRANSACTION_SOURCES }).notNull().default("airbnb"),
    /** Booking channel shown on statements: "Airbnb", "VRBO", "Direct"… */
    channel: text("channel").notNull().default("Airbnb"),
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

/** Record of a statement delivered to an owner, with the totals at that moment. */
export const statementSends = pgTable(
  "statement_sends",
  {
    id: text("id").primaryKey(),
    workspaceId: text("workspace_id")
      .notNull()
      .references(() => workspaces.id, { onDelete: "cascade" }),
    ownerId: text("owner_id")
      .notNull()
      .references(() => owners.id, { onDelete: "cascade" }),
    /** "YYYY-MM". */
    period: text("period").notNull(),
    method: text("method", { enum: SEND_METHODS }).notNull(),
    sentTo: text("sent_to"),
    snapshot: jsonb("snapshot").$type<StatementSnapshot>().notNull(),
    createdAt: createdAt(),
  },
  (t) => [index("statement_sends_owner_period_idx").on(t.ownerId, t.period)],
);

export interface StatementSnapshot {
  bookings: number;
  payoutCents: number;
  cohostFeesCents: number;
  expensesCents: number;
  balanceDueToOwnerCents: number;
}

export type Workspace = typeof workspaces.$inferSelect;
export type User = typeof users.$inferSelect;
export type Session = typeof sessions.$inferSelect;
export type StatementSend = typeof statementSends.$inferSelect;
export type Owner = typeof owners.$inferSelect;
export type Property = typeof properties.$inferSelect;
export type ListingMapping = typeof listingMappings.$inferSelect;
export type ImportRecord = typeof imports.$inferSelect;
export type Transaction = typeof transactions.$inferSelect;
export type Expense = typeof expenses.$inferSelect;
