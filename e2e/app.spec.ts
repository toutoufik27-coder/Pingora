import { expect, test } from "@playwright/test";
import { importSample, logIn, logOut, outbox, PASSWORD, SAMPLE_CSV, signUp, uniqueEmail } from "./helpers";

test("marketing pages, robots and health check", async ({ page, request }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Owner statements in minutes, not evenings.");
  await page.getByRole("link", { name: "Pricing" }).first().click();
  await expect(page.getByRole("heading", { name: "Simple pricing" })).toBeVisible();
  await page.goto("/terms");
  await expect(page.getByRole("heading", { name: "Terms of service" })).toBeVisible();
  await page.goto("/privacy");
  await expect(page.getByRole("heading", { name: "Privacy policy" })).toBeVisible();

  expect((await request.get("/robots.txt")).status()).toBe(200);
  expect(await (await request.get("/api/health")).json()).toEqual({ ok: true });
  const headers = (await request.get("/")).headers();
  expect(headers["x-frame-options"]).toBe("DENY");
  expect(headers["x-powered-by"]).toBeUndefined();
});

test("app pages require a login and return there afterwards", async ({ page }) => {
  await page.goto("/statements?month=2026-08");
  await expect(page).toHaveURL(/\/login\?next=%2Fstatements%3Fmonth%3D2026-08/);

  const email = uniqueEmail("redirect");
  await signUp(page, { name: "Rae", business: "Rae Hosting", email });
  await logOut(page);
  await page.goto("/statements?month=2026-08");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(PASSWORD);
  await page.getByRole("button", { name: "Log in" }).click();
  await expect(page).toHaveURL(/\/statements\?month=2026-08$/);

  await logOut(page);
  await logIn(page, email, "not the password");
  await expect(page.getByText("Wrong email or password.")).toBeVisible();
});

test("a co-host prepares, sends and shares August statements", async ({ page, browser }) => {
  const email = uniqueEmail("cohost");
  await signUp(page, { name: "Casey Host", business: "Harbor Co-Hosting", email });
  await expect(page.getByRole("heading", { name: "Harbor Co-Hosting" })).toBeVisible();
  await expect(page.getByText("Get set up")).toBeVisible();

  // Import, then re-upload the same file: nothing new
  await importSample(page);
  await page.reload();
  await expect(page.getByRole("button", { name: "Try the sample file" })).toHaveCount(0);
  await page.locator('input[type="file"]').setInputFiles(SAMPLE_CSV);
  await expect(page.getByRole("button", { name: "Nothing new to import" })).toBeVisible();
  await expect(page.getByText("Linked to Sunny Loft Downtown")).toBeVisible();

  // Owners
  await page.goto("/owners");
  for (const [name, ownerEmail] of [
    ["Dana Smith", "dana.owner@example.com"],
    ["Ravi Patel", ""],
  ]) {
    await page.getByLabel("Name").fill(name);
    await page.getByLabel("Email").fill(ownerEmail);
    await page.getByRole("button", { name: "Add owner" }).click();
    await expect(page.getByText(`Added ${name}.`)).toBeVisible();
  }

  // Properties
  async function editProperty(name: string, changes: { owner: string; flow?: string; rate?: string; flatFee?: string; monthlyFee?: string }) {
    await page.goto("/properties");
    await page.getByRole("link", { name, exact: true }).click();
    await page.getByLabel("Owner", { exact: true }).selectOption({ label: changes.owner });
    if (changes.flow) await page.getByLabel(changes.flow).check();
    if (changes.rate) await page.getByLabel("Commission rate (%)").fill(changes.rate);
    if (changes.flatFee) await page.getByLabel("Flat fee per booking ($)").fill(changes.flatFee);
    if (changes.monthlyFee) await page.getByLabel("Monthly management fee ($)").fill(changes.monthlyFee);
    await page.getByRole("button", { name: "Save property" }).click();
    await expect(page.getByText("Saved. Statements now use these settings.")).toBeVisible();
  }
  await editProperty("Sunny Loft Downtown", { owner: "Dana Smith" });
  await editProperty("Lakeview Cabin", { owner: "Dana Smith", flatFee: "25" });
  await editProperty("Beach Bungalow #2", {
    owner: "Ravi Patel",
    flow: "The owner receives the Airbnb payouts and pays me",
    rate: "18",
    monthlyFee: "100",
  });
  await page.getByLabel("Commission rate (%)").fill("150");
  await page.getByRole("button", { name: "Save property" }).click();
  await expect(page.getByText(/Enter a commission rate between 0 and 100/)).toBeVisible();

  // Expense
  await page.goto("/expenses?month=2026-08");
  await page.getByLabel("Property").selectOption({ label: "Lakeview Cabin" });
  await page.getByLabel("Date").fill("2026-08-12");
  await page.getByLabel("Amount ($)").fill("64.50");
  await page.getByLabel("Category").selectOption("Supplies");
  await page.getByLabel("Description").fill("Coffee, soap and paper towels");
  await page.getByRole("button", { name: "Add expense" }).click();
  await expect(page.getByText("Added $64.50 supplies expense.")).toBeVisible();

  // Statements: numbers checked by hand
  await page.goto("/statements?month=2026-08");
  const dana = page.getByRole("row", { name: /Dana Smith/ });
  await expect(dana).toContainText("$3,593.85"); // payouts
  await expect(dana).toContainText("$669.77"); // fees: 336.03 + 283.74 + 2 × $25
  await expect(dana).toContainText("Pay owner $2,859.58"); // 3,593.85 − 669.77 − 64.50
  await expect(dana).toContainText("Not sent");
  await expect(page.getByRole("row", { name: /Ravi Patel/ })).toContainText("Owner pays you $381.83");

  // Email Dana's statement
  await dana.getByRole("link", { name: "Dana Smith" }).click();
  await expect(page.getByRole("heading", { name: "Dana Smith · August 2026" })).toBeVisible();
  await page.getByLabel("Personal note (optional)").fill("Great month!");
  await page.getByRole("button", { name: "Email PDF to dana.owner@example.com" }).click();
  await expect(page.getByText(/Statement recorded as sent to dana.owner@example.com/)).toBeVisible();
  const [sent] = outbox("dana.owner@example.com");
  expect(sent.subject).toBe("August 2026 owner statement from Harbor Co-Hosting");
  expect(sent.replyTo).toBe(email);
  expect(sent.from).toContain('"Harbor Co-Hosting"');
  expect(sent.text).toContain("Great month!");
  expect(sent.text).toContain("Balance due to you: $2,859.58.");
  expect(sent.attachments).toEqual([{ filename: "dana-smith-statement-2026-08.pdf", bytes: expect.any(Number) }]);
  await expect(page.getByText(/Emailed to dana.owner@example.com on/)).toBeVisible();

  // Downloads
  const pdf = await page.request.get(page.url().replace(/\?.*/, "/pdf?month=2026-08"));
  expect(pdf.headers()["content-type"]).toBe("application/pdf");
  expect((await pdf.body()).subarray(0, 5).toString()).toBe("%PDF-");
  const csv = await page.request.get(page.url().replace(/\?.*/, "/csv?month=2026-08"));
  expect(csv.headers()["content-disposition"]).toContain("dana-smith-statement-2026-08.csv");
  expect(await csv.text()).toContain("Balance due to owner,2026-08,,,,,,,,,,,2859.58,,,");

  // Ravi has no email: the bulk send reports it
  await page.goto("/statements?month=2026-08");
  await page.getByRole("button", { name: "Email 1 unsent statement" }).click();
  await expect(page.getByText(/Ravi Patel \(Add an email address for Ravi Patel first\.\)/)).toBeVisible();

  // Owner portal, opened by someone who is not logged in
  await page.goto("/owners");
  await page.getByRole("link", { name: "Dana Smith" }).click();
  await page.getByRole("button", { name: "Create portal link" }).click();
  const portalUrl = await page.getByLabel("Portal link").inputValue();
  expect(portalUrl).toMatch(/^http:\/\/localhost:3100\/o\/[\w-]{40,}$/);
  const guest = await browser.newContext();
  const ownerPage = await guest.newPage();
  await ownerPage.goto(portalUrl);
  await expect(ownerPage.getByRole("heading", { name: "Dana Smith · August 2026" })).toBeVisible();
  await expect(ownerPage.getByText("Due to you $2,859.58").first()).toBeVisible();
  expect((await ownerPage.request.get(`${portalUrl}/pdf?month=2026-08`)).status()).toBe(200);
  expect((await ownerPage.request.get(`${portalUrl}/pdf?month=2026-09`)).status()).toBe(404); // not sent yet
  expect((await ownerPage.request.get("/o/not-a-real-token/pdf?month=2026-08")).status()).toBe(404);

  // A direct booking changes the sent statement
  await page.goto("/transactions?month=2026-08");
  await page.getByLabel("Property", { exact: true }).selectOption({ label: "Sunny Loft Downtown" });
  await page.getByLabel("Channel", { exact: true }).selectOption("VRBO");
  await page.getByLabel("Check-in / date").fill("2026-08-28");
  await page.getByLabel("Nights").fill("2");
  await page.getByLabel("Guest").fill("Victor Vale");
  await page.getByLabel("Payout ($)").fill("400");
  await page.getByRole("button", { name: "Add", exact: true }).click();
  await expect(page.getByText("Added VRBO booking of $400.00.")).toBeVisible();
  await expect(page.getByRole("cell", { name: /Victor Vale/ })).toBeVisible();
  await page.goto("/statements?month=2026-08");
  await expect(page.getByRole("row", { name: /Dana Smith/ })).toContainText("Changed since sent");

  // Turning the portal link off
  await page.goto("/owners");
  await page.getByRole("link", { name: "Dana Smith" }).click();
  page.once("dialog", (d) => d.accept());
  await page.getByRole("button", { name: "Turn off link" }).click();
  await expect(page.getByRole("button", { name: "Create portal link" })).toBeVisible();
  await ownerPage.goto(portalUrl);
  await expect(ownerPage.getByText("Page not found")).toBeVisible();
  await guest.close();

  // Billing without a payment provider, annual summary, settings
  await page.goto("/billing");
  await expect(page.getByText("Billing is not configured")).toBeVisible();
  await page.goto("/reports/annual?year=2026");
  await expect(page.getByRole("heading", { name: "Annual summary · 2026" })).toBeVisible();
  await page.goto("/settings");
  await page.getByLabel(/Transaction date/).check();
  await page.getByRole("button", { name: "Save settings" }).click();
  await expect(page.getByText("Settings saved.")).toBeVisible();
});

test("password reset by email", async ({ page }) => {
  const email = uniqueEmail("reset");
  await signUp(page, { name: "Robin", business: "Robin Stays", email });
  await logOut(page);

  await page.goto("/forgot-password");
  await page.getByLabel("Email").fill(email);
  await page.getByRole("button", { name: "Send reset link" }).click();
  await expect(page.getByText(/If an account uses that email/)).toBeVisible();
  const link = outbox(email).at(-1)!.text.match(/http:\/\/\S+\/reset-password\?token=\S+/)![0];

  await page.goto(link);
  await page.getByLabel("New password", { exact: true }).fill("a-new-password-456");
  await page.getByLabel("Repeat new password").fill("a-new-password-456");
  await page.getByRole("button", { name: "Save new password" }).click();
  await expect(page).toHaveURL(/\/dashboard$/);

  await page.goto(link);
  await expect(page.getByRole("heading", { name: "This link has expired" })).toBeVisible();
  await page.goto("/dashboard");
  await logOut(page);
  await logIn(page, email);
  await expect(page.getByText("Wrong email or password.")).toBeVisible();
  await logIn(page, email, "a-new-password-456");
  await expect(page).toHaveURL(/\/dashboard$/);
});

test("accounts never see each other's data", async ({ page }) => {
  await signUp(page, { name: "Alex", business: "Alex Co", email: uniqueEmail("alex") });
  await page.goto("/owners");
  await page.getByLabel("Name").fill("Private Owner");
  await page.getByRole("button", { name: "Add owner" }).click();
  await page.getByRole("link", { name: "Private Owner" }).click();
  await expect(page).toHaveURL(/\/owners\/[\w-]+$/);
  const ownerUrl = page.url();
  await logOut(page);

  await signUp(page, { name: "Blake", business: "Blake Co", email: uniqueEmail("blake") });
  await page.goto("/owners");
  await expect(page.getByText("No owners yet")).toBeVisible();
  await page.goto(ownerUrl);
  await expect(page.getByText("Page not found")).toBeVisible();
});

test("phone-sized screens never scroll sideways", async ({ page }) => {
  await signUp(page, { name: "Mo", business: "Mobile Hosting", email: uniqueEmail("mobile") });
  await importSample(page);
  await page.setViewportSize({ width: 390, height: 844 });
  for (const url of ["/", "/pricing", "/dashboard", "/import", "/statements?month=2026-08", "/transactions?month=2026-08", "/properties", "/owners", "/expenses?month=2026-08", "/reports/annual?year=2026", "/settings", "/billing", "/account"]) {
    await page.goto(url);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    expect(overflow, `horizontal overflow on ${url}`).toBeLessThanOrEqual(0);
  }
});

test("deleting an account removes the login", async ({ page }) => {
  const email = uniqueEmail("delete");
  await signUp(page, { name: "Del", business: "Del Co", email });
  await page.goto("/account");
  await page.getByLabel("Password", { exact: true }).fill(PASSWORD);
  await page.getByLabel('Type "DELETE" to confirm').fill("DELETE");
  await page.getByRole("button", { name: "Delete my account" }).click();
  await expect(page).toHaveURL(/\/\?account=deleted$/);
  await expect(page.getByText("Your account and all of its data have been deleted.")).toBeVisible();
  await logIn(page, email);
  await expect(page.getByText("Wrong email or password.")).toBeVisible();
});
