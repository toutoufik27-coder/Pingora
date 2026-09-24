import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";
import { APP_NAME, COMPANY_NAME, SUPPORT_EMAIL } from "@/lib/brand";

export const metadata: Metadata = { title: "Privacy policy" };

export default function PrivacyPage() {
  return (
    <LegalPage title="Privacy policy" updated="September 24, 2026">
      <p>
        This policy explains what personal data {COMPANY_NAME} collects when you use {APP_NAME}, why, and the choices you have.
      </p>

      <h2>What we collect</h2>
      <ul>
        <li>
          <strong>Account data:</strong> your name, email address, business name and a hashed version of your password (we never store the
          password itself).
        </li>
        <li>
          <strong>Customer data you upload or enter:</strong> booking records exported from Airbnb or added by hand (which include guest names
          and confirmation codes), owner names and email addresses, properties, fees and expenses.
        </li>
        <li>
          <strong>Billing data:</strong> your subscription status and identifiers from our payment provider. Card details are collected and
          stored by Lemon Squeezy, not by us.
        </li>
        <li>
          <strong>Technical data:</strong> a session cookie that keeps you signed in, and standard server logs (such as IP address and time of
          request) used for security and troubleshooting.
        </li>
      </ul>

      <h2>How we use it</h2>
      <ul>
        <li>To provide the Service: calculate and display statements, generate PDFs and send the emails you ask us to send.</li>
        <li>To secure the Service, for example to limit repeated failed sign-in attempts.</li>
        <li>To bill your subscription and send service messages such as password resets.</li>
      </ul>
      <p>We do not sell personal data and we do not use your customer data for advertising.</p>

      <h2>Who we share it with</h2>
      <p>We use a small number of service providers to run {APP_NAME}, each bound to protect the data:</p>
      <ul>
        <li>Hosting and database providers, which store the application and its data.</li>
        <li>Resend, which delivers the emails the Service sends.</li>
        <li>Lemon Squeezy, our merchant of record, which processes payments and invoices.</li>
      </ul>
      <p>
        Statements you send go to the owner email addresses you enter. We may disclose data if required by law or to protect the rights and
        safety of our users.
      </p>

      <h2>Cookies</h2>
      <p>We only use a strictly necessary cookie to keep you signed in. We do not use advertising or tracking cookies.</p>

      <h2>Retention and deletion</h2>
      <p>
        We keep your data while your account exists. Deleting your account from the Account page permanently removes your business data
        and login. Copies in our hosting provider&apos;s backups are removed as those backups expire.
      </p>

      <h2>Your rights</h2>
      <p>
        Depending on where you live (for example under the GDPR or the CCPA) you may have the right to access, correct, export or delete your
        personal data, and to object to certain processing. Most of this you can do in the app; for anything else, email us. If you are a
        property owner or guest whose data a co-host entered, please contact that co-host first, as they control that data.
      </p>

      <h2>Security</h2>
      <p>
        Data is transmitted over HTTPS, passwords are hashed with scrypt, session tokens are stored only as hashes, and every account&apos;s
        data is isolated from other accounts.
      </p>

      <h2>Contact</h2>
      <p>
        Questions or requests: <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
      </p>
    </LegalPage>
  );
}
