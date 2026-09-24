/**
 * Shared vocabulary for the co-host accounting domain, plus the labels the UI
 * and the PDF use for each value.
 */

/** How a line of an Airbnb transaction export is treated. */
export const TRANSACTION_KINDS = ["reservation", "adjustment", "resolution", "payout", "tax", "other"] as const;
export type TransactionKind = (typeof TRANSACTION_KINDS)[number];

/** Kinds that are stored and appear on owner statements. Payouts and taxes are not revenue. */
export const STATEMENT_KINDS = ["reservation", "adjustment", "resolution", "other"] as const satisfies readonly TransactionKind[];

/** What the commission percentage is applied to. */
export const COMMISSION_BASES = ["payout", "gross"] as const;
export type CommissionBase = (typeof COMMISSION_BASES)[number];

export const COMMISSION_BASE_LABELS: Record<CommissionBase, string> = {
  payout: "Airbnb payout (after Airbnb's host fee)",
  gross: "Gross booking revenue (before Airbnb's host fee)",
};

/** Who keeps the cleaning fee charged to guests. */
export const CLEANING_FEE_RECIPIENTS = ["owner", "cohost"] as const;
export type CleaningFeeRecipient = (typeof CLEANING_FEE_RECIPIENTS)[number];

export const CLEANING_FEE_RECIPIENT_LABELS: Record<CleaningFeeRecipient, string> = {
  owner: "The owner (it stays in owner revenue)",
  cohost: "Me, the co-host (I pay the cleaners)",
};

/** Where Airbnb sends the money, which decides who owes whom at the end of the month. */
export const PAYOUT_FLOWS = ["cohost_collects", "owner_collects", "airbnb_split"] as const;
export type PayoutFlow = (typeof PAYOUT_FLOWS)[number];

export const PAYOUT_FLOW_LABELS: Record<PayoutFlow, string> = {
  cohost_collects: "I receive the Airbnb payouts and pay the owner",
  owner_collects: "The owner receives the Airbnb payouts and pays me",
  airbnb_split: "Airbnb splits the payout and pays my fee directly",
};

/** The same flows, worded for the owner reading their statement. */
export const PAYOUT_FLOW_OWNER_LABELS: Record<PayoutFlow, string> = {
  cohost_collects: "Your co-host receives the Airbnb payouts and pays you",
  owner_collects: "You receive the Airbnb payouts and pay your co-host",
  airbnb_split: "Airbnb pays your co-host's fee directly",
};

export const PAYOUT_FLOW_SHORT_LABELS: Record<PayoutFlow, string> = {
  cohost_collects: "Co-host collects",
  owner_collects: "Owner collects",
  airbnb_split: "Airbnb split",
};

/** Which date places a transaction in a statement month. */
export const ATTRIBUTION_BASES = ["checkin", "payout_date"] as const;
export type AttributionBasis = (typeof ATTRIBUTION_BASES)[number];

export const ATTRIBUTION_BASIS_LABELS: Record<AttributionBasis, string> = {
  checkin: "Check-in date (bookings count in the month the stay starts)",
  payout_date: "Transaction date (bookings count in the month Airbnb pays them out)",
};

export const EXPENSE_PAYERS = ["cohost", "owner"] as const;
export type ExpensePaidBy = (typeof EXPENSE_PAYERS)[number];

export const EXPENSE_PAYER_LABELS: Record<ExpensePaidBy, string> = {
  cohost: "I paid it (reimburse from owner)",
  owner: "The owner paid it directly",
};

export const EXPENSE_CATEGORIES = [
  "Cleaning",
  "Laundry & linens",
  "Supplies",
  "Repairs & maintenance",
  "Utilities",
  "Software & subscriptions",
  "Other",
] as const;

export interface CommissionRule {
  base: CommissionBase;
  /** Commission rate in basis points: 20% = 2000. */
  rateBps: number;
  /** Leave the guest cleaning fee out of the commission base. */
  excludeCleaningFee: boolean;
  cleaningFeeTo: CleaningFeeRecipient;
  /** Charged once per booking (confirmation code). */
  flatFeePerReservationCents: number;
  /** Charged once per statement month, bookings or not. */
  monthlyFeeCents: number;
}

/** Where a transaction came from. Manual entries cover direct, VRBO and other bookings. */
export const TRANSACTION_SOURCES = ["airbnb", "manual"] as const;
export type TransactionSource = (typeof TRANSACTION_SOURCES)[number];

export const MANUAL_CHANNELS = ["Direct", "VRBO", "Booking.com", "Furnished Finder", "Other"] as const;

/** How an owner statement was delivered. */
export const SEND_METHODS = ["email", "manual"] as const;
export type SendMethod = (typeof SEND_METHODS)[number];
