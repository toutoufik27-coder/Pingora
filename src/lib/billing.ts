/**
 * Subscription rules, independent of the billing provider and the database.
 *
 * Every new workspace starts a free trial with no card ("trialing"). Once the
 * co-host subscribes, the provider's webhooks move the status through Lemon
 * Squeezy's lifecycle: on_trial, active, past_due, paused, unpaid, cancelled,
 * expired.
 */

export const SUBSCRIPTION_STATUSES = [
  "trialing",
  "on_trial",
  "active",
  "past_due",
  "paused",
  "unpaid",
  "cancelled",
  "expired",
] as const;
export type SubscriptionStatus = (typeof SUBSCRIPTION_STATUSES)[number];

export const TRIAL_DAYS = 14;

export interface BillingState {
  subscriptionStatus: SubscriptionStatus;
  trialEndsAt: Date | null;
  currentPeriodEndsAt: Date | null;
}

const DAY_MS = 24 * 60 * 60 * 1000;

export function trialEndFrom(start: Date): Date {
  return new Date(start.getTime() + TRIAL_DAYS * DAY_MS);
}

/** Whether the workspace may use the app. Always true when billing is not configured. */
export function hasAccess(state: BillingState, now: Date, billingEnabled: boolean): boolean {
  if (!billingEnabled) return true;
  switch (state.subscriptionStatus) {
    case "active":
    case "on_trial":
    // Card declined: keep access while the provider retries the payment.
    case "past_due":
      return true;
    case "trialing":
      return state.trialEndsAt !== null && now < state.trialEndsAt;
    case "cancelled":
      // Cancelled subscriptions run until the end of the paid period.
      return state.currentPeriodEndsAt !== null && now < state.currentPeriodEndsAt;
    case "paused":
    case "unpaid":
    case "expired":
      return false;
  }
}

/** Whether the co-host has (or had) a paid subscription, as opposed to the free trial. */
export function isSubscribed(state: BillingState): boolean {
  return state.subscriptionStatus !== "trialing";
}

export function daysLeft(until: Date | null, now: Date): number {
  if (!until) return 0;
  return Math.max(0, Math.ceil((until.getTime() - now.getTime()) / DAY_MS));
}

/** One line describing the plan state, for the billing page and the app header. */
export function describeBilling(state: BillingState, now: Date): string {
  switch (state.subscriptionStatus) {
    case "trialing": {
      const days = daysLeft(state.trialEndsAt, now);
      return days > 0 ? `Free trial · ${days} day${days === 1 ? "" : "s"} left` : "Free trial ended";
    }
    case "on_trial":
      return "Subscribed · trial period";
    case "active":
      return "Subscribed";
    case "past_due":
      return "Payment failed · please update your card";
    case "paused":
      return "Subscription paused";
    case "unpaid":
      return "Subscription unpaid";
    case "cancelled":
      return state.currentPeriodEndsAt && now < state.currentPeriodEndsAt
        ? `Cancelled · access until ${state.currentPeriodEndsAt.toISOString().slice(0, 10)}`
        : "Subscription cancelled";
    case "expired":
      return "Subscription expired";
  }
}

// ---------------------------------------------------------------------------
// Lemon Squeezy webhooks

export interface SubscriptionUpdate {
  workspaceId: string | null;
  subscriptionId: string;
  customerId: string | null;
  status: SubscriptionStatus;
  currentPeriodEndsAt: Date | null;
  portalUrl: string | null;
  /** When the provider last changed the subscription. */
  updatedAt: Date | null;
}

const PROVIDER_STATUSES = new Set<string>(["on_trial", "active", "past_due", "paused", "unpaid", "cancelled", "expired"]);

function asDate(value: unknown): Date | null {
  if (typeof value !== "string") return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function record(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" ? (value as Record<string, unknown>) : {};
}

/**
 * Reads a Lemon Squeezy `subscription_*` webhook body. Returns null for events
 * that do not describe a subscription (orders, license keys, …).
 */
export function parseSubscriptionWebhook(payload: unknown): SubscriptionUpdate | null {
  const body = record(payload);
  const meta = record(body.meta);
  const eventName = typeof meta.event_name === "string" ? meta.event_name : "";
  const data = record(body.data);
  if (!eventName.startsWith("subscription_") || data.type !== "subscriptions" || data.id == null) return null;

  const attributes = record(data.attributes);
  const status = String(attributes.status ?? "");
  if (!PROVIDER_STATUSES.has(status)) return null;
  const custom = record(meta.custom_data);
  const urls = record(attributes.urls);

  return {
    workspaceId: typeof custom.workspace_id === "string" ? custom.workspace_id : null,
    subscriptionId: String(data.id),
    customerId: attributes.customer_id == null ? null : String(attributes.customer_id),
    status: status as SubscriptionStatus,
    // A cancelled subscription ends at `ends_at`; otherwise the paid period ends at the next renewal.
    currentPeriodEndsAt: asDate(status === "cancelled" || status === "expired" ? attributes.ends_at : attributes.renews_at),
    portalUrl: typeof urls.customer_portal === "string" ? urls.customer_portal : null,
    updatedAt: asDate(attributes.updated_at),
  };
}
