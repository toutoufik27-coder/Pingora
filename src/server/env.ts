/**
 * Runtime configuration from environment variables (see .env.example).
 * Read lazily so tests and scripts can change them.
 */

/** Public URL of the app. On Vercel it falls back to the production domain when APP_URL is not set. */
export function appUrl(): string {
  const vercel = process.env.VERCEL_PROJECT_PRODUCTION_URL || process.env.VERCEL_URL;
  const url = process.env.APP_URL || (vercel ? `https://${vercel}` : "http://localhost:3000");
  return url.replace(/\/+$/, "");
}

export function isProduction(): boolean {
  return process.env.NODE_ENV === "production";
}

export interface EmailConfig {
  resendApiKey: string | null;
  from: string;
  /** Development only: write outgoing emails as JSON files here instead of dropping them. */
  outboxDir: string | null;
}

export function emailConfig(): EmailConfig {
  return {
    resendApiKey: process.env.RESEND_API_KEY || null,
    from: process.env.EMAIL_FROM || "CoHost Ledger <no-reply@example.com>",
    outboxDir: process.env.EMAIL_OUTBOX_DIR || null,
  };
}

export interface LemonSqueezyConfig {
  apiKey: string;
  storeId: string;
  variantId: string;
  webhookSecret: string;
}

/** Null when billing is not configured, in which case every workspace has full access. */
export function lemonSqueezyConfig(): LemonSqueezyConfig | null {
  const apiKey = process.env.LEMONSQUEEZY_API_KEY;
  const storeId = process.env.LEMONSQUEEZY_STORE_ID;
  const variantId = process.env.LEMONSQUEEZY_VARIANT_ID;
  const webhookSecret = process.env.LEMONSQUEEZY_WEBHOOK_SECRET;
  if (!apiKey || !storeId || !variantId || !webhookSecret) return null;
  return { apiKey, storeId, variantId, webhookSecret };
}

export function isBillingEnabled(): boolean {
  return lemonSqueezyConfig() !== null;
}
