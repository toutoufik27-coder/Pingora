import { describe, expect, it } from "vitest";
import { daysLeft, describeBilling, hasAccess, parseSubscriptionWebhook, trialEndFrom, type BillingState } from "./billing";

const now = new Date("2026-09-10T12:00:00Z");
const later = new Date("2026-09-20T00:00:00Z");
const earlier = new Date("2026-09-01T00:00:00Z");

function state(overrides: Partial<BillingState>): BillingState {
  return { subscriptionStatus: "trialing", trialEndsAt: later, currentPeriodEndsAt: null, ...overrides };
}

describe("hasAccess", () => {
  it("lets everyone in when billing is not configured", () => {
    expect(hasAccess(state({ subscriptionStatus: "expired" }), now, false)).toBe(true);
  });

  it("allows a running trial and blocks an ended one", () => {
    expect(hasAccess(state({}), now, true)).toBe(true);
    expect(hasAccess(state({ trialEndsAt: earlier }), now, true)).toBe(false);
    expect(hasAccess(state({ trialEndsAt: null }), now, true)).toBe(false);
  });

  it("allows paying and retrying subscriptions", () => {
    for (const status of ["active", "on_trial", "past_due"] as const) {
      expect(hasAccess(state({ subscriptionStatus: status, trialEndsAt: earlier }), now, true)).toBe(true);
    }
  });

  it("keeps cancelled subscriptions until the paid period ends", () => {
    expect(hasAccess(state({ subscriptionStatus: "cancelled", currentPeriodEndsAt: later }), now, true)).toBe(true);
    expect(hasAccess(state({ subscriptionStatus: "cancelled", currentPeriodEndsAt: earlier }), now, true)).toBe(false);
  });

  it("blocks paused, unpaid and expired subscriptions", () => {
    for (const status of ["paused", "unpaid", "expired"] as const) {
      expect(hasAccess(state({ subscriptionStatus: status, currentPeriodEndsAt: later }), now, true)).toBe(false);
    }
  });
});

describe("trial helpers", () => {
  it("computes the trial end and days left", () => {
    expect(trialEndFrom(earlier).toISOString()).toBe("2026-09-15T00:00:00.000Z");
    expect(daysLeft(later, now)).toBe(10);
    expect(daysLeft(earlier, now)).toBe(0);
    expect(daysLeft(null, now)).toBe(0);
  });

  it("describes the plan", () => {
    expect(describeBilling(state({}), now)).toBe("Free trial · 10 days left");
    expect(describeBilling(state({ trialEndsAt: earlier }), now)).toBe("Free trial ended");
    expect(describeBilling(state({ subscriptionStatus: "active" }), now)).toBe("Subscribed");
    expect(describeBilling(state({ subscriptionStatus: "cancelled", currentPeriodEndsAt: later }), now)).toBe(
      "Cancelled · access until 2026-09-20",
    );
  });
});

describe("parseSubscriptionWebhook", () => {
  const payload = {
    meta: { event_name: "subscription_updated", custom_data: { workspace_id: "ws_1" } },
    data: {
      type: "subscriptions",
      id: 4321,
      attributes: {
        status: "active",
        customer_id: 99,
        renews_at: "2026-10-10T00:00:00.000000Z",
        ends_at: null,
        updated_at: "2026-09-10T08:00:00.000000Z",
        urls: { customer_portal: "https://store.lemonsqueezy.com/billing?x=1" },
      },
    },
  };

  it("reads the subscription state", () => {
    expect(parseSubscriptionWebhook(payload)).toEqual({
      workspaceId: "ws_1",
      subscriptionId: "4321",
      customerId: "99",
      status: "active",
      currentPeriodEndsAt: new Date("2026-10-10T00:00:00Z"),
      portalUrl: "https://store.lemonsqueezy.com/billing?x=1",
      updatedAt: new Date("2026-09-10T08:00:00Z"),
    });
  });

  it("uses ends_at for cancelled subscriptions", () => {
    const cancelled = {
      ...payload,
      data: { ...payload.data, attributes: { ...payload.data.attributes, status: "cancelled", ends_at: "2026-10-10T00:00:00Z" } },
    };
    expect(parseSubscriptionWebhook(cancelled)?.currentPeriodEndsAt).toEqual(new Date("2026-10-10T00:00:00Z"));
  });

  it("ignores other events and malformed bodies", () => {
    expect(parseSubscriptionWebhook({ ...payload, meta: { event_name: "order_created" } })).toBeNull();
    expect(parseSubscriptionWebhook({ ...payload, data: { ...payload.data, attributes: { status: "weird" } } })).toBeNull();
    expect(parseSubscriptionWebhook(null)).toBeNull();
    expect(parseSubscriptionWebhook("nope")).toBeNull();
  });
});
