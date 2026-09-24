import { createHmac, timingSafeEqual } from "node:crypto";
import { and, eq, isNull, lte, or } from "drizzle-orm";
import type { SubscriptionUpdate } from "@/lib/billing";
import type { Database } from "./db/client";
import { workspaces, type User, type Workspace } from "./db/schema";
import { appUrl, lemonSqueezyConfig } from "./env";

/**
 * Lemon Squeezy integration: hosted checkout, signed webhooks and
 * cancellation. Lemon Squeezy is the merchant of record, so it also handles
 * sales tax and invoices.
 */

const API = "https://api.lemonsqueezy.com/v1";

async function lemonSqueezy(pathname: string, init: RequestInit): Promise<Response> {
  const config = lemonSqueezyConfig();
  if (!config) throw new Error("Billing is not configured");
  return fetch(`${API}${pathname}`, {
    ...init,
    headers: {
      Accept: "application/vnd.api+json",
      "Content-Type": "application/vnd.api+json",
      Authorization: `Bearer ${config.apiKey}`,
    },
  });
}

/** Creates a hosted checkout for the workspace and returns its URL. */
export async function createCheckoutUrl(workspace: Workspace, user: User): Promise<string> {
  const config = lemonSqueezyConfig();
  if (!config) throw new Error("Billing is not configured");
  const response = await lemonSqueezy("/checkouts", {
    method: "POST",
    body: JSON.stringify({
      data: {
        type: "checkouts",
        attributes: {
          checkout_data: { email: user.email, name: user.name, custom: { workspace_id: workspace.id } },
          product_options: { redirect_url: `${appUrl()}/billing?checkout=success` },
        },
        relationships: {
          store: { data: { type: "stores", id: config.storeId } },
          variant: { data: { type: "variants", id: config.variantId } },
        },
      },
    }),
  });
  const body = (await response.json().catch(() => ({}))) as { data?: { attributes?: { url?: string } } };
  const url = body.data?.attributes?.url;
  if (!response.ok || !url) throw new Error(`Checkout could not be created (status ${response.status})`);
  return url;
}

/** Cancels at the end of the paid period (used when an account is deleted). */
export async function cancelSubscription(subscriptionId: string): Promise<void> {
  const response = await lemonSqueezy(`/subscriptions/${encodeURIComponent(subscriptionId)}`, { method: "DELETE" });
  if (!response.ok && response.status !== 404) throw new Error(`Cancellation failed (status ${response.status})`);
}

/** Lemon Squeezy signs the raw body with HMAC-SHA256 (hex) in the X-Signature header. */
export function verifyWebhookSignature(rawBody: string, signature: string | null, secret: string): boolean {
  if (!signature) return false;
  const expected = Buffer.from(createHmac("sha256", secret).update(rawBody).digest("hex"), "utf8");
  const actual = Buffer.from(signature, "utf8");
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

/** Stores a subscription change on its workspace. Returns false when no workspace matches. */
export async function applySubscriptionUpdate(db: Database, update: SubscriptionUpdate): Promise<boolean> {
  const values = {
    subscriptionStatus: update.status,
    billingSubscriptionId: update.subscriptionId,
    billingCustomerId: update.customerId,
    currentPeriodEndsAt: update.currentPeriodEndsAt,
    billingPortalUrl: update.portalUrl,
    billingUpdatedAt: update.updatedAt,
  };
  const target = update.workspaceId
    ? eq(workspaces.id, update.workspaceId)
    : eq(workspaces.billingSubscriptionId, update.subscriptionId);
  // Webhooks can arrive out of order: never let an older event overwrite a newer one.
  const notOlder = update.updatedAt
    ? or(isNull(workspaces.billingUpdatedAt), lte(workspaces.billingUpdatedAt, update.updatedAt))
    : undefined;
  const updated = await db.update(workspaces).set(values).where(and(target, notOlder)).returning({ id: workspaces.id });
  if (updated.length > 0) return true;
  const [exists] = await db.select({ id: workspaces.id }).from(workspaces).where(target);
  return !!exists;
}
