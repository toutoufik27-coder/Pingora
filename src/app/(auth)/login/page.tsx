import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { ActionForm } from "@/components/action-form";
import { Field, inputClass } from "@/components/ui";
import { firstParam } from "@/lib/search-params";
import { logInAction } from "@/server/actions/auth";
import { getSession, safeNextPath } from "@/server/context";

export const metadata: Metadata = { title: "Log in" };

export default async function LoginPage({ searchParams }: PageProps<"/login">) {
  const next = safeNextPath(firstParam(await searchParams, "next"));
  if (await getSession()) redirect(next);

  return (
    <>
      <h1 className="text-2xl font-semibold tracking-tight text-ink-900">Log in</h1>
      <p className="mt-1 text-sm text-ink-600">
        New here?{" "}
        <Link href="/signup" className="font-medium text-brand-700 hover:underline">
          Start your free trial
        </Link>
      </p>
      <ActionForm action={logInAction} submitLabel="Log in" pendingLabel="Logging in…" className="mt-6 space-y-4">
        <input type="hidden" name="next" value={next} />
        <Field label="Email" htmlFor="email">
          <input id="email" name="email" type="email" autoComplete="email" required className={inputClass} />
        </Field>
        <Field label="Password" htmlFor="password">
          <input id="password" name="password" type="password" autoComplete="current-password" required className={inputClass} />
        </Field>
        <p className="text-sm">
          <Link href="/forgot-password" className="text-ink-600 hover:underline">
            Forgot your password?
          </Link>
        </p>
      </ActionForm>
    </>
  );
}
