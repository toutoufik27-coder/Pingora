import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { expect, type Page } from "@playwright/test";

export const PASSWORD = "e2e-password-123";
export const SAMPLE_CSV = path.resolve(process.cwd(), "public/samples/airbnb-transaction-history-sample.csv");
const OUTBOX = path.resolve(process.cwd(), ".e2e/outbox");

let counter = 0;
export function uniqueEmail(prefix: string): string {
  return `${prefix}-${Date.now()}-${++counter}@example.com`;
}

export async function signUp(page: Page, { name, business, email }: { name: string; business: string; email: string }) {
  await page.goto("/signup");
  await page.getByLabel("Your name").fill(name);
  await page.getByLabel("Business name").fill(business);
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(PASSWORD);
  await page.getByRole("checkbox").check();
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(page).toHaveURL(/\/dashboard$/);
}

export async function logIn(page: Page, email: string, password = PASSWORD) {
  await page.goto("/login");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Log in" }).click();
}

export async function logOut(page: Page) {
  await page.getByRole("button", { name: "Log out" }).first().click();
  await expect(page).toHaveURL(/\/login/);
}

export async function importSample(page: Page) {
  await page.goto("/import");
  await page.getByRole("button", { name: "Try the sample file" }).click();
  await page.getByRole("button", { name: /Import 15 transactions/ }).click();
  await expect(page.getByText("Import complete")).toBeVisible();
}

export interface OutboxEmail {
  to: string;
  subject: string;
  text: string;
  replyTo: string | null;
  from: string;
  attachments: { filename: string; bytes: number }[];
}

/** Emails "sent" by the server during the tests, newest last. */
export function outbox(to?: string): OutboxEmail[] {
  let files: string[];
  try {
    files = readdirSync(OUTBOX).sort();
  } catch {
    return [];
  }
  const emails = files.map((f) => JSON.parse(readFileSync(path.join(OUTBOX, f), "utf8")) as OutboxEmail);
  return to ? emails.filter((e) => e.to === to) : emails;
}
