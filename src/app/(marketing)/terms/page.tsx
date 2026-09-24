import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";
import { TRIAL_DAYS } from "@/lib/billing";
import { APP_NAME, COMPANY_NAME, SUPPORT_EMAIL } from "@/lib/brand";

export const metadata: Metadata = { title: "Terms of service" };

export default function TermsPage() {
  return (
    <LegalPage title="Terms of service" updated="September 24, 2026">
      <p>
        These terms govern your use of {APP_NAME} (the &quot;Service&quot;), operated by {COMPANY_NAME} (&quot;we&quot;, &quot;us&quot;). By creating an
        account you agree to them. If you use the Service for a business, you accept them on its behalf.
      </p>

      <h2>1. The Service</h2>
      <p>
        {APP_NAME} helps short-term rental co-hosts and property managers prepare owner statements from booking data they upload or enter.
        We are not affiliated with Airbnb, VRBO or any other booking platform, and we do not provide accounting, tax or legal advice.
        Statements are calculated from the data and fee settings you provide; you are responsible for checking them before sending them to
        anyone.
      </p>

      <h2>2. Your account</h2>
      <ul>
        <li>You must give accurate information and keep your password secret. You are responsible for activity on your account.</li>
        <li>You must be at least 18 years old and able to form a binding contract.</li>
        <li>Tell us promptly at {SUPPORT_EMAIL} if you suspect unauthorized access.</li>
      </ul>

      <h2>3. Trial, subscription and payment</h2>
      <ul>
        <li>New accounts get a free trial of {TRIAL_DAYS} days. No payment details are needed for the trial.</li>
        <li>
          After the trial, continued use requires a paid subscription, billed monthly in advance. Payments are processed by our reseller
          and merchant of record, Lemon Squeezy, whose terms also apply to your purchase.
        </li>
        <li>Prices may change with at least 30 days&apos; notice before your next billing period.</li>
        <li>
          You can cancel at any time from the billing page. Cancellation takes effect at the end of the current billing period, and fees
          already paid are not refunded except where required by law.
        </li>
        <li>If a payment fails and is not resolved, we may suspend access until it is. Your data is kept while your account exists.</li>
      </ul>

      <h2>4. Your data</h2>
      <p>
        You keep all rights to the data you upload (&quot;Customer Data&quot;), including information about property owners and guests. You grant us
        permission to host, process and display it only to provide the Service to you. You confirm you have the right to upload it and to
        share statements with the owners you send them to. Our <a href="/privacy">privacy policy</a> explains how we handle personal data.
      </p>
      <p>You can export statements at any time and delete your account, which permanently deletes your Customer Data.</p>

      <h2>5. Acceptable use</h2>
      <ul>
        <li>Don&apos;t use the Service for anything unlawful, or to store data you have no right to process.</li>
        <li>Don&apos;t try to access other customers&apos; data, probe or disrupt the Service, or bypass its limits or security.</li>
        <li>Don&apos;t resell the Service without our written permission.</li>
      </ul>

      <h2>6. Availability and changes</h2>
      <p>
        We work to keep the Service available and your data safe, but we provide it &quot;as is&quot; without warranties of any kind, to the
        extent permitted by law. We may improve or change features; if we make a change that materially reduces the Service, we will tell
        you in advance.
      </p>

      <h2>7. Liability</h2>
      <p>
        To the extent permitted by law, we are not liable for indirect, incidental or consequential damages, lost profits or lost data,
        and our total liability for any claim is limited to the amount you paid us in the 12 months before the claim.
      </p>

      <h2>8. Termination</h2>
      <p>
        You may stop using the Service at any time. We may suspend or close accounts that break these terms, with notice where
        reasonable.
      </p>

      <h2>9. Changes to these terms</h2>
      <p>We may update these terms. If a change is material we will notify you by email or in the app before it takes effect.</p>

      <h2>10. Contact</h2>
      <p>
        Questions about these terms: <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
      </p>
    </LegalPage>
  );
}
