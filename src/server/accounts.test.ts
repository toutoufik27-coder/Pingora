import { createHmac } from "node:crypto";
import { eq } from "drizzle-orm";
import { beforeAll, describe, expect, it } from "vitest";
import { monthPeriod } from "@/lib/dates";
import {
  authenticate,
  changePassword,
  createPasswordResetToken,
  deleteAccount,
  isPasswordResetTokenValid,
  resetPassword,
  signUp,
  updateProfile,
} from "./auth/accounts";
import { hashPassword, hashToken, verifyPassword } from "./auth/crypto";
import { cleanUpAuthTables } from "./auth/housekeeping";
import { consumeRateLimit } from "./auth/rate-limit";
import { createSession, SESSION_DURATION_MS, validateSessionToken } from "./auth/sessions";
import { applySubscriptionUpdate, verifyWebhookSignature } from "./billing";
import { openPgliteDatabase, type Database } from "./db/client";
import { owners, rateLimitHits, sessions, users, workspaces } from "./db/schema";
import { commitImport, NEW_PROPERTY } from "./imports";
import { createOwner, getOwner, getOwnerByPortalToken, listOwners, setOwnerPortalToken } from "./owners";
import { deleteProperty, listProperties, updateProperty } from "./properties";
import { latestSendsForPeriod, recordStatementSend, sentPeriodsForOwner, snapshotChanged } from "./statement-sends";
import { loadOwnerStatement } from "./statements";
import { createManualTransaction, deleteManualTransaction, listTransactions } from "./transactions";

const PASSWORD = "correct horse battery";

describe("password hashing", () => {
  it("verifies the right password only", async () => {
    const hash = await hashPassword(PASSWORD);
    expect(hash).toMatch(/^scrypt\$16384\$8\$1\$/);
    expect(await verifyPassword(PASSWORD, hash)).toBe(true);
    expect(await verifyPassword("wrong password!", hash)).toBe(false);
    expect(await verifyPassword(PASSWORD, "garbage")).toBe(false);
    expect(await hashPassword(PASSWORD)).not.toBe(hash);
  });
});

describe("accounts and sessions", () => {
  let db: Database;
  beforeAll(async () => {
    db = await openPgliteDatabase();
  });

  it("signs up a user into a new workspace and rejects a taken email", async () => {
    const user = await signUp(db, { name: "Ana", email: " Ana@Example.com ", password: PASSWORD, businessName: "Ana Hosting" });
    if (user === "email_taken") throw new Error("unexpected");
    expect(user.email).toBe("ana@example.com");
    const [workspace] = await db.select().from(workspaces).where(eq(workspaces.id, user.workspaceId));
    expect(workspace).toMatchObject({ name: "Ana Hosting", subscriptionStatus: "trialing" });
    expect(await signUp(db, { name: "Other", email: "ANA@example.com", password: PASSWORD, businessName: "X" })).toBe("email_taken");
  });

  it("authenticates case-insensitively and rejects wrong passwords and unknown emails", async () => {
    expect((await authenticate(db, "ANA@example.com", PASSWORD))?.name).toBe("Ana");
    expect(await authenticate(db, "ana@example.com", "wrong password")).toBeNull();
    expect(await authenticate(db, "nobody@example.com", PASSWORD)).toBeNull();
  });

  it("creates, validates, renews and expires sessions", async () => {
    const user = (await authenticate(db, "ana@example.com", PASSWORD))!;
    const start = new Date("2026-09-01T00:00:00Z");
    const { token, expiresAt } = await createSession(db, user.id, start);
    expect(expiresAt.getTime() - start.getTime()).toBe(SESSION_DURATION_MS);

    // The database never stores the token itself.
    const [stored] = await db.select().from(sessions).where(eq(sessions.userId, user.id));
    expect(stored.id).toBe(hashToken(token));
    expect(stored.id).not.toBe(token);

    const valid = await validateSessionToken(db, token, new Date("2026-09-02T00:00:00Z"));
    expect(valid?.user.id).toBe(user.id);
    expect(valid?.session.expiresAt).toEqual(expiresAt);

    // Used within 15 days of expiry: extended by 30 days.
    const renewAt = new Date("2026-09-20T00:00:00Z");
    const renewed = await validateSessionToken(db, token, renewAt);
    expect(renewed?.session.expiresAt).toEqual(new Date(renewAt.getTime() + SESSION_DURATION_MS));

    expect(await validateSessionToken(db, token, new Date("2027-01-01T00:00:00Z"))).toBeNull();
    expect(await validateSessionToken(db, token, renewAt)).toBeNull(); // deleted when found expired
    expect(await validateSessionToken(db, "made-up-token")).toBeNull();
  });

  it("resets a password once with a valid token and signs out other sessions", async () => {
    const user = (await authenticate(db, "ana@example.com", PASSWORD))!;
    await createSession(db, user.id);
    const now = new Date();
    const issued = await createPasswordResetToken(db, "ANA@example.com", now);
    expect(issued?.user.id).toBe(user.id);
    expect(await createPasswordResetToken(db, "nobody@example.com")).toBeNull();

    expect(await isPasswordResetTokenValid(db, issued!.token, now)).toBe(true);
    expect(await resetPassword(db, issued!.token, "a brand new password", new Date(now.getTime() + 2 * 60 * 60 * 1000))).toBeNull(); // expired
    const reset = await resetPassword(db, issued!.token, "a brand new password", now);
    expect(reset?.id).toBe(user.id);
    expect(await resetPassword(db, issued!.token, "again and again", now)).toBeNull(); // single use
    expect(await db.select().from(sessions).where(eq(sessions.userId, user.id))).toHaveLength(0);
    expect(await authenticate(db, "ana@example.com", "a brand new password")).not.toBeNull();
  });

  it("changes password and profile", async () => {
    const user = (await authenticate(db, "ana@example.com", "a brand new password"))!;
    expect(await changePassword(db, user.id, "wrong", "another password 1")).toBe(false);
    expect(await changePassword(db, user.id, "a brand new password", "another password 1")).toBe(true);
    await signUp(db, { name: "Ben", email: "ben@example.com", password: PASSWORD, businessName: "Ben Co" });
    expect(await updateProfile(db, user.id, { name: "Ana B", email: "BEN@example.com" })).toBe("email_taken");
    expect(await updateProfile(db, user.id, { name: "Ana B", email: "ana.b@example.com" })).toBe("ok");
    expect((await authenticate(db, "ana.b@example.com", "another password 1"))?.name).toBe("Ana B");
  });

  it("deletes an account with everything in its workspace, and nothing else", async () => {
    const ana = (await authenticate(db, "ana.b@example.com", "another password 1"))!;
    await createOwner(db, ana.workspaceId, { name: "Owner of Ana", email: null });
    const ben = (await authenticate(db, "ben@example.com", PASSWORD))!;
    await createOwner(db, ben.workspaceId, { name: "Owner of Ben", email: null });

    expect(await deleteAccount(db, ana.id, "wrong")).toBe(false);
    expect(await deleteAccount(db, ana.id, "another password 1")).toBe(true);
    expect(await db.select().from(users).where(eq(users.id, ana.id))).toHaveLength(0);
    expect((await db.select().from(owners)).map((o) => o.name)).toEqual(["Owner of Ben"]);
  });
});

describe("rate limiting", () => {
  it("allows up to the limit per window", async () => {
    const db = await openPgliteDatabase();
    const t0 = new Date("2026-09-01T00:00:00Z");
    for (let i = 0; i < 3; i++) expect(await consumeRateLimit(db, "login:a", 3, 60_000, t0)).toBe(true);
    expect(await consumeRateLimit(db, "login:a", 3, 60_000, t0)).toBe(false);
    expect(await consumeRateLimit(db, "login:b", 3, 60_000, t0)).toBe(true);
    expect(await consumeRateLimit(db, "login:a", 3, 60_000, new Date(t0.getTime() + 61_000))).toBe(true);
  });
});

describe("auth housekeeping", () => {
  it("removes expired sessions and old rate-limit hits only", async () => {
    const db = await openPgliteDatabase();
    const user = await signUp(db, { name: "H", email: "h@example.com", password: PASSWORD, businessName: "H" });
    if (user === "email_taken") throw new Error("unexpected");
    const now = new Date("2026-09-24T00:00:00Z");
    await createSession(db, user.id, new Date("2026-08-01T00:00:00Z")); // expired on Aug 31
    await createSession(db, user.id, now);
    await consumeRateLimit(db, "login:old", 5, 60_000, new Date("2026-09-20T00:00:00Z"));
    await consumeRateLimit(db, "login:new", 5, 60_000, now);
    await cleanUpAuthTables(db, now);
    expect(await db.select().from(sessions)).toHaveLength(1);
    expect((await db.select().from(rateLimitHits)).map((h) => h.key)).toEqual(["login:new"]);
  });
});

describe("workspace isolation", () => {
  it("never returns another workspace's records", async () => {
    const db = await openPgliteDatabase();
    const a = await signUp(db, { name: "A", email: "a@example.com", password: PASSWORD, businessName: "A" });
    const b = await signUp(db, { name: "B", email: "b@example.com", password: PASSWORD, businessName: "B" });
    if (a === "email_taken" || b === "email_taken") throw new Error("unexpected");
    const owner = await createOwner(db, a.workspaceId, { name: "Private owner", email: null });
    expect(await getOwner(db, b.workspaceId, owner.id)).toBeNull();
    expect(await listOwners(db, b.workspaceId)).toEqual([]);
    expect(await setOwnerPortalToken(db, b.workspaceId, owner.id, "stolen")).toBe(false);
  });
});

describe("billing webhooks", () => {
  it("verifies signatures", () => {
    const body = '{"meta":{}}';
    const signature = createHmac("sha256", "secret").update(body).digest("hex");
    expect(verifyWebhookSignature(body, signature, "secret")).toBe(true);
    expect(verifyWebhookSignature(body, signature, "other")).toBe(false);
    expect(verifyWebhookSignature(`${body} `, signature, "secret")).toBe(false);
    expect(verifyWebhookSignature(body, null, "secret")).toBe(false);
  });

  it("applies subscription changes in order and ignores stale ones", async () => {
    const db = await openPgliteDatabase();
    const user = await signUp(db, { name: "C", email: "c@example.com", password: PASSWORD, businessName: "C" });
    if (user === "email_taken") throw new Error("unexpected");
    const base = {
      workspaceId: user.workspaceId,
      subscriptionId: "sub_1",
      customerId: "cus_1",
      portalUrl: "https://portal",
    };
    expect(
      await applySubscriptionUpdate(db, { ...base, status: "active", currentPeriodEndsAt: new Date("2026-10-01"), updatedAt: new Date("2026-09-01T10:00:00Z") }),
    ).toBe(true);
    // Later event without custom data finds the workspace by subscription id.
    expect(
      await applySubscriptionUpdate(db, {
        ...base,
        workspaceId: null,
        status: "cancelled",
        currentPeriodEndsAt: new Date("2026-10-01"),
        updatedAt: new Date("2026-09-05T10:00:00Z"),
      }),
    ).toBe(true);
    // A stale "active" event arriving late does not undo the cancellation.
    await applySubscriptionUpdate(db, { ...base, status: "active", currentPeriodEndsAt: new Date("2026-10-01"), updatedAt: new Date("2026-09-02T10:00:00Z") });
    const [workspace] = await db.select().from(workspaces).where(eq(workspaces.id, user.workspaceId));
    expect(workspace).toMatchObject({ subscriptionStatus: "cancelled", billingSubscriptionId: "sub_1", billingPortalUrl: "https://portal" });
    expect(
      await applySubscriptionUpdate(db, { ...base, workspaceId: null, subscriptionId: "unknown", status: "active", currentPeriodEndsAt: null, updatedAt: null }),
    ).toBe(false);
  });
});

describe("statement delivery, portal and manual bookings", () => {
  let db: Database;
  let workspaceId: string;
  let workspace: typeof workspaces.$inferSelect;
  let ownerId: string;
  let propertyId: string;

  beforeAll(async () => {
    db = await openPgliteDatabase();
    const user = await signUp(db, { name: "D", email: "d@example.com", password: PASSWORD, businessName: "D Co" });
    if (user === "email_taken") throw new Error("unexpected");
    workspaceId = user.workspaceId;
    [workspace] = await db.select().from(workspaces).where(eq(workspaces.id, workspaceId));
    const csv = "Date,Type,Confirmation code,Start date,Nights,Guest,Listing,Amount,Service fee,Gross earnings\n08/04/2026,Reservation,HM1,08/03/2026,3,Emily,Loft,504.40,15.60,520.00\n";
    await commitImport(db, workspace, { csvText: csv, fileName: "a.csv", mappings: { Loft: NEW_PROPERTY } });
    ownerId = (await createOwner(db, workspaceId, { name: "Dana", email: "dana@example.com" })).id;
    propertyId = (await listProperties(db, workspaceId))[0].id;
    await updateProperty(db, workspaceId, propertyId, {
      name: "Loft",
      ownerId,
      payoutFlow: "cohost_collects",
      commissionBase: "payout",
      commissionRateBps: 2000,
      excludeCleaningFee: true,
      cleaningFeeTo: "owner",
      flatFeePerReservationCents: 0,
      monthlyFeeCents: 0,
    });
  });

  it("adds manual bookings to statements and deletes only manual rows", async () => {
    expect(
      await createManualTransaction(db, workspaceId, {
        propertyId,
        kind: "reservation",
        channel: "VRBO",
        date: "2026-08-20",
        nights: 2,
        guest: "Victor",
        confirmationCode: "VR-1",
        details: "",
        payoutCents: 40000,
        channelFeeCents: 2000,
        cleaningFeeCents: 5000,
      }),
    ).toBe("ok");
    expect(
      await createManualTransaction(db, "other-workspace", {
        propertyId,
        kind: "adjustment",
        channel: "Direct",
        date: "2026-08-20",
        nights: null,
        guest: "",
        confirmationCode: "",
        details: "",
        payoutCents: 100,
        channelFeeCents: 0,
        cleaningFeeCents: 0,
      }),
    ).toBe("unknown_property");

    const statement = await loadOwnerStatement(db, workspace, ownerId, monthPeriod("2026-08"));
    const lines = statement!.properties[0].lines;
    expect(lines.map((l) => [l.transaction.channel, l.transaction.guest, l.grossCents])).toEqual([
      ["Airbnb", "Emily", 52000],
      ["VRBO", "Victor", 42000],
    ]);
    expect(lines[1].fee.commissionCents).toBe(7000); // 20% of (400 − 50 cleaning)

    const listed = await listTransactions(db, workspaceId, monthPeriod("2026-08"));
    const airbnb = listed.find((t) => t.source === "airbnb")!;
    const manual = listed.find((t) => t.source === "manual")!;
    expect(await deleteManualTransaction(db, workspaceId, airbnb.id)).toBe(false);
    expect(await deleteManualTransaction(db, "other-workspace", manual.id)).toBe(false);
    expect(await deleteManualTransaction(db, workspaceId, manual.id)).toBe(true);
    expect(await listTransactions(db, workspaceId, monthPeriod("2026-08"), propertyId)).toHaveLength(1);
  });

  it("records sends, detects later changes and lists sent months for the portal", async () => {
    const statement = (await loadOwnerStatement(db, workspace, ownerId, monthPeriod("2026-08")))!;
    await recordStatementSend(db, workspaceId, statement, "email", "dana@example.com");
    const latest = await latestSendsForPeriod(db, workspaceId, "2026-08");
    expect(latest.get(ownerId)).toMatchObject({ method: "email", sentTo: "dana@example.com" });
    expect(snapshotChanged(latest.get(ownerId)!.snapshot, statement)).toBe(false);

    await createManualTransaction(db, workspaceId, {
      propertyId,
      kind: "adjustment",
      channel: "Direct",
      date: "2026-08-25",
      nights: null,
      guest: "",
      confirmationCode: "",
      details: "Late fee",
      payoutCents: 2500,
      channelFeeCents: 0,
      cleaningFeeCents: 0,
    });
    const changed = (await loadOwnerStatement(db, workspace, ownerId, monthPeriod("2026-08")))!;
    expect(snapshotChanged(latest.get(ownerId)!.snapshot, changed)).toBe(true);
    expect(await sentPeriodsForOwner(db, ownerId)).toEqual(["2026-08"]);
  });

  it("shares and revokes the owner portal link", async () => {
    expect(await setOwnerPortalToken(db, workspaceId, ownerId, "portal-token-123")).toBe(true);
    expect((await getOwnerByPortalToken(db, "portal-token-123"))?.id).toBe(ownerId);
    await setOwnerPortalToken(db, workspaceId, ownerId, null);
    expect(await getOwnerByPortalToken(db, "portal-token-123")).toBeNull();
    expect(await getOwnerByPortalToken(db, "")).toBeNull();
  });

  it("deletes a property with its bookings", async () => {
    expect(await deleteProperty(db, "other-workspace", propertyId)).toBe(false);
    expect(await deleteProperty(db, workspaceId, propertyId)).toBe(true);
    expect(await listTransactions(db, workspaceId, monthPeriod("2026-08"))).toEqual([]);
  });
});
