"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, type ReactNode } from "react";
import { Icon, type IconName } from "./icons";

const GROUPS: { title: string; links: { href: string; label: string; icon: IconName }[] }[] = [
  {
    title: "Monthly work",
    links: [
      { href: "/dashboard", label: "Dashboard", icon: "dashboard" },
      { href: "/import", label: "Import from Airbnb", icon: "upload" },
      { href: "/statements", label: "Owner statements", icon: "statement" },
      { href: "/transactions", label: "Bookings", icon: "calendar" },
      { href: "/expenses", label: "Expenses", icon: "receipt" },
    ],
  },
  {
    title: "Setup",
    links: [
      { href: "/properties", label: "Properties", icon: "home" },
      { href: "/owners", label: "Owners", icon: "users" },
    ],
  },
  {
    title: "Business",
    links: [
      { href: "/reports/annual", label: "Annual summary", icon: "chart" },
      { href: "/settings", label: "Settings", icon: "settings" },
      { href: "/billing", label: "Billing", icon: "card" },
    ],
  },
];

export function NavLinks() {
  const pathname = usePathname();
  return (
    <nav aria-label="Main" className="space-y-6 px-3">
      {GROUPS.map((group) => (
        <div key={group.title}>
          <div className="px-3 pb-2 text-[11px] font-semibold tracking-wider text-ink-400 uppercase">{group.title}</div>
          <ul className="space-y-0.5">
            {group.links.map((link) => {
              const active = pathname === link.href || pathname.startsWith(`${link.href}/`);
              return (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    aria-current={active ? "page" : undefined}
                    className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors ${
                      active ? "bg-brand-50 font-medium text-brand-700" : "text-ink-600 hover:bg-ink-100 hover:text-ink-900"
                    }`}
                  >
                    <Icon name={link.icon} className={`size-[18px] shrink-0 ${active ? "text-brand-600" : "text-ink-400"}`} />
                    {link.label}
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      ))}
    </nav>
  );
}

/** Slide-down menu for small screens; closes itself after navigating. */
export function MobileMenu({ label, children }: { label: string; children: ReactNode }) {
  const pathname = usePathname();
  const details = useRef<HTMLDetailsElement>(null);
  useEffect(() => {
    if (details.current) details.current.open = false;
  }, [pathname]);
  return (
    <details ref={details} className="group">
      <summary
        className="flex cursor-pointer list-none items-center rounded-lg p-2 text-ink-600 hover:bg-ink-100 [&::-webkit-details-marker]:hidden"
        aria-label={label}
      >
        <Icon name="menu" className="size-6 group-open:hidden" />
        <Icon name="close" className="hidden size-6 group-open:block" />
      </summary>
      <div className="absolute inset-x-0 top-full z-40 max-h-[calc(100vh-4rem)] overflow-y-auto border-b border-ink-200 bg-white py-4 shadow-lg">
        {children}
      </div>
    </details>
  );
}

const EXTRA_SECTIONS: Record<string, string> = { "/account": "Account" };

/** "Workspace / Section" trail for the top bar, derived from the current path. */
export function SectionCrumb({ workspace }: { workspace: string }) {
  const pathname = usePathname();
  const link = GROUPS.flatMap((group) => group.links).find((l) => pathname === l.href || pathname.startsWith(`${l.href}/`));
  const section = link?.label ?? EXTRA_SECTIONS[pathname];
  return (
    <div className="flex min-w-0 items-center gap-2 text-sm">
      <span className="truncate text-ink-500">{workspace}</span>
      {section ? (
        <>
          <Icon name="chevron" className="size-4 shrink-0 text-ink-300" />
          <span className="truncate font-medium text-ink-900">{section}</span>
        </>
      ) : null}
    </div>
  );
}
