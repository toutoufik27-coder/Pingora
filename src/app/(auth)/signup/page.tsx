import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { ActionForm } from "@/components/action-form";
import { Field, inputClass } from "@/components/ui";
import { TRIAL_DAYS } from "@/lib/billing";
import { signUpAction } from "@/server/actions/auth";
import { PASSWORD_MIN_LENGTH } from "@/server/auth/accounts";
import { getSession } from "@/server/context";

export const metadata: Metadata = { title: "Start your free trial" };

export default async function SignupPage() {
  if (await getSession()) redirect("/dashboard");

  return (
    <>
      <h1 className="text-xl font-semibold text-slate-900">Start your {TRIAL_DAYS}-day free trial</h1>
      <p className="mt-1 text-sm text-slate-600">
        No credit card needed. Already have an account?{" "}
        <Link href="/login" className="font-medium text-brand-700 hover:underline">
          Log in
        </Link>
      </p>
      <ActionForm action={signUpAction} submitLabel="Create account" pendingLabel="Creating…" className="mt-6 space-y-4">
        <Field label="Your name" htmlFor="name">
          <input id="name" name="name" autoComplete="name" required className={inputClass} />
        </Field>
        <Field label="Business name" htmlFor="businessName" hint="Printed on your owner statements. You can change it later.">
          <input id="businessName" name="businessName" autoComplete="organization" required placeholder="Harbor Co-Hosting" className={inputClass} />
        </Field>
        <Field label="Email" htmlFor="email">
          <input id="email" name="email" type="email" autoComplete="email" required className={inputClass} />
        </Field>
        <Field label="Password" htmlFor="password" hint={`At least ${PASSWORD_MIN_LENGTH} characters.`}>
          <input
            id="password"
            name="password"
            type="password"
            autoComplete="new-password"
            minLength={PASSWORD_MIN_LENGTH}
            required
            className={inputClass}
          />
        </Field>
        <label className="flex items-start gap-2 text-sm text-slate-600">
          <input type="checkbox" name="terms" required className="mt-0.5 size-4 accent-brand-600" />
          <span>
            I agree to the{" "}
            <Link href="/terms" target="_blank" className="underline">
              terms of service
            </Link>{" "}
            and{" "}
            <Link href="/privacy" target="_blank" className="underline">
              privacy policy
            </Link>
            .
          </span>
        </label>
      </ActionForm>
    </>
  );
}
