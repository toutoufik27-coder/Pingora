import type { Metadata } from "next";
import Link from "next/link";
import { ActionForm } from "@/components/action-form";
import { Field, inputClass } from "@/components/ui";
import { requestPasswordResetAction } from "@/server/actions/auth";

export const metadata: Metadata = { title: "Reset your password" };

export default function ForgotPasswordPage() {
  return (
    <>
      <h1 className="text-xl font-semibold text-slate-900">Reset your password</h1>
      <p className="mt-1 text-sm text-slate-600">We&apos;ll email you a link to choose a new one.</p>
      <ActionForm action={requestPasswordResetAction} submitLabel="Send reset link" pendingLabel="Sending…" className="mt-6 space-y-4">
        <Field label="Email" htmlFor="email">
          <input id="email" name="email" type="email" autoComplete="email" required className={inputClass} />
        </Field>
      </ActionForm>
      <p className="mt-6 text-sm">
        <Link href="/login" className="text-slate-600 hover:underline">
          ← Back to log in
        </Link>
      </p>
    </>
  );
}
