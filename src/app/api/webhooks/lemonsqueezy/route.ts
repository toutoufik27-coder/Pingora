import { parseSubscriptionWebhook } from "@/lib/billing";
import { applySubscriptionUpdate, verifyWebhookSignature } from "@/server/billing";
import { getDb } from "@/server/db/client";
import { lemonSqueezyConfig } from "@/server/env";

/** Lemon Squeezy → Settings → Webhooks: point to /api/webhooks/lemonsqueezy with the subscription events. */
export async function POST(request: Request) {
  const config = lemonSqueezyConfig();
  if (!config) return new Response("Billing is not configured", { status: 404 });

  const rawBody = await request.text();
  if (!verifyWebhookSignature(rawBody, request.headers.get("x-signature"), config.webhookSecret)) {
    return new Response("Invalid signature", { status: 401 });
  }

  let payload: unknown;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const update = parseSubscriptionWebhook(payload);
  if (!update) return new Response("Ignored", { status: 200 });
  const applied = await applySubscriptionUpdate(await getDb(), update);
  // 200 even when no workspace matches (e.g. an account deleted since), so the provider stops retrying.
  return new Response(applied ? "OK" : "No matching workspace", { status: 200 });
}
