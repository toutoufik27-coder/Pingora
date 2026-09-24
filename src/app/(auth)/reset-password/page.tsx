import type { Metadata } from "next";
import Link from "next/link";
import { ActionForm } from "@/components/action-form";
import { Field, inputClass } from "@/components/ui";
import { firstParam } from "@/lib/search-params";
import { resetPasswordAction } from "@/server/actions/auth";
import { isPasswordResetTokenValid, PASSWORD_MIN_LENGTH } from "@/server/auth/accounts";
import { getDb } from "@/server/db/client";

export const metadata: Metadata = { title: "Choose a new password", robots: { index: false } };

export default async function ResetPasswordPage({ searchParams }: PageProps<"/reset-password">) {
  const token = firstParam(await searchParams, "token") ?? "";
  const valid = token.length > 0 && token.length <= 200 && (await isPasswordResetTokenValid(await getDb(), token));

  if (!valid) {
    return (
      <>
        <h1 className="text-xl font-semibold text-slate-900">This link has expired</h1>
        <p className="mt-2 text-sm text-slate-600">Reset links work once and for one hour.</p>
        <p className="mt-6 text-sm">
          <Link href="/forgot-password" className="font-medium text-brand-700 hover:underline">
            Send a new link →
          </Link>
        </p>
      </>
    );
  }

  return (
    <>
      <h1 className="text-xl font-semibold text-slate-900">Choose a new password</h1>
      <p className="mt-1 text-sm text-slate-600">You&apos;ll be signed out of your other devices.</p>
      <ActionForm action={resetPasswordAction} submitLabel="Save new password" className="mt-6 space-y-4">
        <input type="hidden" name="token" value={token} />
        <Field label="New password" htmlFor="password" hint={`At least ${PASSWORD_MIN_LENGTH} characters.`}>
          <input id="password" name="password" type="password" autoComplete="new-password" minLength={PASSWORD_MIN_LENGTH} required className={inputClass} />
        </Field>
        <Field label="Repeat new password" htmlFor="confirm">
          <input id="confirm" name="confirm" type="password" autoComplete="new-password" required className={inputClass} />
        </Field>
      </ActionForm>
    </>
  );
}
