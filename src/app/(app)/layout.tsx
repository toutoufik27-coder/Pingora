import Link from "next/link";
import type { ReactNode } from "react";
import { redirect } from "next/navigation";
import { Logo } from "@/components/logo";
import { NavLinks } from "@/components/nav-links";
import { describeBilling } from "@/lib/billing";
import { logOutAction } from "@/server/actions/auth";
import { getSession, workspaceHasAccess } from "@/server/context";
import { isBillingEnabled } from "@/server/env";

export default async function AppLayout({ children }: { children: ReactNode }) {
  const session = await getSession();
  if (!session) redirect("/login");
  const { user, workspace } = session;
  const billing = isBillingEnabled();
  const now = new Date();
  const showBanner = billing && (workspace.subscriptionStatus === "trialing" || !workspaceHasAccess(workspace, now) || workspace.subscriptionStatus === "past_due");

  return (
    <div className="md:flex md:min-h-screen">
      <aside className="border-b border-slate-200 bg-white md:flex md:w-60 md:shrink-0 md:flex-col md:border-r md:border-b-0">
        <div className="px-5 pt-5 pb-3 md:pb-5">
          <Logo href="/dashboard" />
        </div>
        <NavLinks />
        <div className="hidden border-t border-slate-100 px-5 py-4 text-sm md:mt-auto md:block">
          <div className="truncate font-medium text-slate-900">{workspace.name}</div>
          <div className="truncate text-slate-500">{user.email}</div>
          <div className="mt-3 flex items-center gap-3">
            <Link href="/account" className="text-slate-600 hover:text-slate-900 hover:underline">
              Account
            </Link>
            <form action={logOutAction}>
              <button type="submit" className="text-slate-600 hover:text-slate-900 hover:underline">
                Log out
              </button>
            </form>
          </div>
        </div>
      </aside>
      <main className="min-w-0 flex-1">
        {showBanner ? (
          <div className="border-b border-amber-200 bg-amber-50 px-4 py-2 text-center text-sm text-amber-900 md:px-10">
            {describeBilling(workspace, now)}.{" "}
            <Link href="/billing" className="font-medium underline">
              {workspace.subscriptionStatus === "trialing" ? "Subscribe" : "Manage billing"}
            </Link>
          </div>
        ) : null}
        <div className="px-4 py-6 md:px-10 md:py-8">
          <div className="mx-auto max-w-6xl">{children}</div>
        </div>
        <div className="flex items-center justify-center gap-4 border-t border-slate-200 px-4 py-4 text-sm md:hidden">
          <Link href="/account" className="text-slate-600 underline">
            Account
          </Link>
          <form action={logOutAction}>
            <button type="submit" className="text-slate-600 underline">
              Log out
            </button>
          </form>
        </div>
      </main>
    </div>
  );
}
