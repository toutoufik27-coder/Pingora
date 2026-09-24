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
          <div className="px-3 pb-2 text-[11px] font-semibold tracking-wider text-slate-400 uppercase">{group.title}</div>
          <ul className="space-y-0.5">
            {group.links.map((link) => {
              const active = pathname === link.href || pathname.startsWith(`${link.href}/`);
              return (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    aria-current={active ? "page" : undefined}
                    className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors ${
                      active ? "bg-brand-50 font-medium text-brand-700" : "text-slate-600 hover:bg-slate-100 hover:text-slate-900"
                    }`}
                  >
                    <Icon name={link.icon} className={`size-[18px] shrink-0 ${active ? "text-brand-600" : "text-slate-400"}`} />
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
      <summary className="flex cursor-pointer list-none items-center rounded-lg p-2 text-slate-600 hover:bg-slate-100 [&::-webkit-details-marker]:hidden" aria-label={label}>
        <Icon name="menu" className="size-6 group-open:hidden" />
        <Icon name="close" className="hidden size-6 group-open:block" />
      </summary>
      <div className="absolute inset-x-0 top-full z-40 max-h-[calc(100vh-4rem)] overflow-y-auto border-b border-slate-200 bg-white py-4 shadow-lg">
        {children}
      </div>
    </details>
  );
}
