import Link from "next/link";
import { redirect } from "next/navigation";
import type { ReactNode } from "react";
import { Icon } from "@/components/icons";
import { Logo } from "@/components/logo";
import { MobileMenu, NavLinks } from "@/components/nav-links";
import { daysLeft, describeBilling, TRIAL_DAYS } from "@/lib/billing";
import { logOutAction } from "@/server/actions/auth";
import { getSession, workspaceHasAccess } from "@/server/context";
import type { User, Workspace } from "@/server/db/schema";
import { isBillingEnabled } from "@/server/env";

function initials(name: string): string {
  return (
    name
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]!.toUpperCase())
      .join("") || "?"
  );
}

function AccountBox({ user, workspace }: { user: User; workspace: Workspace }) {
  return (
    <div className="px-3">
      <div className="flex items-center gap-3 rounded-lg px-3 py-2">
        <span aria-hidden className="grid size-9 shrink-0 place-items-center rounded-full bg-slate-100 text-sm font-semibold text-slate-600">
          {initials(user.name)}
        </span>
        <div className="min-w-0 text-sm">
          <div className="truncate font-medium text-slate-900">{user.name}</div>
          <div className="truncate text-slate-500">{workspace.name}</div>
        </div>
      </div>
      <div className="mt-1 grid grid-cols-2 gap-1">
        <Link href="/account" className="flex items-center justify-center gap-2 rounded-lg px-3 py-2 text-sm text-slate-600 hover:bg-slate-100 hover:text-slate-900">
          <Icon name="user" className="size-4" />
          Account
        </Link>
        <form action={logOutAction}>
          <button type="submit" className="flex w-full items-center justify-center gap-2 rounded-lg px-3 py-2 text-sm text-slate-600 hover:bg-slate-100 hover:text-slate-900">
            <Icon name="logout" className="size-4" />
            Log out
          </button>
        </form>
      </div>
    </div>
  );
}

function PlanCard({ workspace }: { workspace: Workspace }) {
  const now = new Date();
  if (!isBillingEnabled() || workspace.subscriptionStatus === "active") return null;
  const trial = workspace.subscriptionStatus === "trialing";
  const left = trial ? daysLeft(workspace.trialEndsAt, now) : 0;
  return (
    <div className="mx-3 rounded-xl border border-brand-100 bg-brand-50 p-4 text-sm">
      <div className="font-medium text-brand-800">{describeBilling(workspace, now)}</div>
      {trial ? (
        <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-white" aria-hidden>
          <div className="h-full rounded-full bg-brand-600" style={{ width: `${Math.round(((TRIAL_DAYS - Math.min(left, TRIAL_DAYS)) / TRIAL_DAYS) * 100)}%` }} />
        </div>
      ) : null}
      <Link href="/billing" className="mt-3 inline-flex items-center gap-1 font-medium text-brand-700 hover:underline">
        {trial ? "Choose a plan" : "Manage billing"}
        <Icon name="arrow" className="size-4" />
      </Link>
    </div>
  );
}

export default async function AppLayout({ children }: { children: ReactNode }) {
  const session = await getSession();
  if (!session) redirect("/login");
  const { user, workspace } = session;
  const now = new Date();
  const blocked = isBillingEnabled() && !workspaceHasAccess(workspace, now);
  const pastDue = isBillingEnabled() && workspace.subscriptionStatus === "past_due";

  return (
    <div className="lg:flex lg:min-h-screen">
      {/* Desktop sidebar */}
      <aside className="hidden border-r border-slate-200 bg-white lg:sticky lg:top-0 lg:flex lg:h-screen lg:w-64 lg:shrink-0 lg:flex-col">
        <div className="px-6 py-5">
          <Logo href="/dashboard" />
        </div>
        <div className="flex-1 overflow-y-auto pb-6">
          <NavLinks />
        </div>
        <div className="space-y-4 border-t border-slate-100 py-4">
          <PlanCard workspace={workspace} />
          <AccountBox user={user} workspace={workspace} />
        </div>
      </aside>

      {/* Mobile top bar */}
      <header className="sticky top-0 z-30 flex items-center justify-between border-b border-slate-200 bg-white/90 px-4 py-3 backdrop-blur lg:hidden">
        <Logo href="/dashboard" />
        <MobileMenu label="Open menu">
          <NavLinks />
          <div className="mt-6 space-y-4 border-t border-slate-100 pt-4">
            <PlanCard workspace={workspace} />
            <AccountBox user={user} workspace={workspace} />
          </div>
        </MobileMenu>
      </header>

      <main className="min-w-0 flex-1">
        {blocked || pastDue ? (
          <div className="border-b border-amber-200 bg-amber-50 px-4 py-2 text-center text-sm text-amber-900 md:px-10">
            {describeBilling(workspace, now)}.{" "}
            <Link href="/billing" className="font-medium underline">
              {workspace.subscriptionStatus === "trialing" ? "Subscribe to continue" : "Update billing"}
            </Link>
          </div>
        ) : null}
        <div className="px-4 py-6 md:px-8 md:py-8 xl:px-12">
          <div className="mx-auto max-w-6xl">{children}</div>
        </div>
      </main>
    </div>
  );
}
