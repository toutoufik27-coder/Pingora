import { createHmac } from "node:crypto";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { eq } from "drizzle-orm";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

const SECRET = "whsec_test";

describe("POST /api/webhooks/lemonsqueezy", () => {
  const saved = { ...process.env };
  let workspaceId: string;

  beforeAll(async () => {
    process.env.PGLITE_DATA_DIR = mkdtempSync(path.join(tmpdir(), "cl-webhook-"));
    Object.assign(process.env, {
      LEMONSQUEEZY_API_KEY: "key",
      LEMONSQUEEZY_STORE_ID: "1",
      LEMONSQUEEZY_VARIANT_ID: "2",
      LEMONSQUEEZY_WEBHOOK_SECRET: SECRET,
    });
    const { getDb } = await import("@/server/db/client");
    const { createWorkspace } = await import("@/server/workspace");
    workspaceId = (await createWorkspace(await getDb(), "Webhook Co")).id;
  });

  afterAll(() => {
    process.env = saved;
  });

  function request(body: string, signature: string | null) {
    return new Request("http://localhost/api/webhooks/lemonsqueezy", {
      method: "POST",
      body,
      headers: signature ? { "x-signature": signature } : {},
    });
  }

  const payload = () =>
    JSON.stringify({
      meta: { event_name: "subscription_created", custom_data: { workspace_id: workspaceId } },
      data: {
        type: "subscriptions",
        id: "777",
        attributes: {
          status: "active",
          customer_id: 55,
          renews_at: "2026-10-24T00:00:00Z",
          updated_at: "2026-09-24T00:00:00Z",
          urls: { customer_portal: "https://example.lemonsqueezy.com/billing" },
        },
      },
    });

  it("rejects unsigned or tampered requests", async () => {
    const { POST } = await import("./route");
    const body = payload();
    expect((await POST(request(body, null))).status).toBe(401);
    expect((await POST(request(body, "0".repeat(64)))).status).toBe(401);
  });

  it("activates the workspace's subscription on a signed event", async () => {
    const { POST } = await import("./route");
    const { getDb } = await import("@/server/db/client");
    const { workspaces } = await import("@/server/db/schema");
    const body = payload();
    const signature = createHmac("sha256", SECRET).update(body).digest("hex");
    const response = await POST(request(body, signature));
    expect(response.status).toBe(200);
    const [workspace] = await (await getDb()).select().from(workspaces).where(eq(workspaces.id, workspaceId));
    expect(workspace).toMatchObject({
      subscriptionStatus: "active",
      billingSubscriptionId: "777",
      billingCustomerId: "55",
      billingPortalUrl: "https://example.lemonsqueezy.com/billing",
    });
  });

  it("acknowledges events it does not handle", async () => {
    const { POST } = await import("./route");
    const body = JSON.stringify({ meta: { event_name: "order_created" }, data: { type: "orders", id: "1" } });
    const signature = createHmac("sha256", SECRET).update(body).digest("hex");
    expect((await POST(request(body, signature))).status).toBe(200);
  });
});
