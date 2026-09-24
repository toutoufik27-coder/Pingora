import Link from "next/link";
import type { ReactNode } from "react";
import { Icon } from "@/components/icons";
import { Logo } from "@/components/logo";
import { MobileMenu } from "@/components/nav-links";
import { buttonClass } from "@/components/ui";
import { APP_NAME, APP_TAGLINE, COMPANY_NAME, SUPPORT_EMAIL } from "@/lib/brand";

const NAV = [
  { href: "/#how-it-works", label: "How it works" },
  { href: "/#features", label: "Features" },
  { href: "/pricing", label: "Pricing" },
  { href: "/#faq", label: "FAQ" },
];

const FOOTER = [
  {
    title: "Product",
    links: [
      { href: "/#features", label: "Features" },
      { href: "/pricing", label: "Pricing" },
      { href: "/signup", label: "Start free trial" },
      { href: "/login", label: "Log in" },
    ],
  },
  {
    title: "Resources",
    links: [
      { href: "/#how-it-works", label: "How it works" },
      { href: "/#faq", label: "FAQ" },
      { href: "/samples/airbnb-transaction-history-sample.csv", label: "Sample Airbnb CSV" },
    ],
  },
  {
    title: "Company",
    links: [
      { href: `mailto:${SUPPORT_EMAIL}`, label: "Contact" },
      { href: "/terms", label: "Terms of service" },
      { href: "/privacy", label: "Privacy policy" },
    ],
  },
];

export default function MarketingLayout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col bg-white">
      <header className="sticky top-0 z-30 border-b border-ink-200/70 bg-white/80 backdrop-blur-md">
        <div className="relative mx-auto flex h-16 max-w-6xl items-center justify-between gap-4 px-4 md:px-8">
          <Logo />
          <nav
            aria-label="Main"
            className="hidden items-center gap-0.5 rounded-full border border-ink-200 bg-ink-50/80 p-1 text-sm md:flex"
          >
            {NAV.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="rounded-full px-4 py-1.5 text-ink-600 transition-colors hover:bg-white hover:text-ink-900 hover:shadow-sm"
              >
                {item.label}
              </Link>
            ))}
          </nav>
          <div className="hidden items-center gap-1 md:flex">
            <Link
              href="/login"
              className="rounded-full px-4 py-2 text-sm font-medium text-ink-700 transition-colors hover:bg-ink-100 hover:text-ink-900"
            >
              Log in
            </Link>
            <Link href="/signup" className={`${buttonClass("primary")} rounded-full! pr-3`}>
              Start free trial
              <Icon name="arrow" className="size-4" />
            </Link>
          </div>
          <div className="flex items-center gap-1 md:hidden">
            <Link href="/signup" className={`${buttonClass("primary", "sm")} rounded-full! px-3.5!`}>
              Try free
            </Link>
            <MobileMenu label="Open menu">
              <nav aria-label="Mobile" className="flex flex-col px-4">
                {NAV.map((item) => (
                  <Link key={item.href} href={item.href} className="rounded-lg px-3 py-3 text-ink-700 hover:bg-ink-50">
                    {item.label}
                  </Link>
                ))}
                <div className="mt-3 grid grid-cols-2 gap-2 border-t border-ink-100 pt-4">
                  <Link href="/login" className={buttonClass("secondary")}>
                    Log in
                  </Link>
                  <Link href="/signup" className={buttonClass("primary")}>
                    Start free trial
                  </Link>
                </div>
              </nav>
            </MobileMenu>
          </div>
        </div>
      </header>

      <main className="flex-1">{children}</main>

      <footer className="border-t border-ink-200 bg-ink-50">
        <div className="mx-auto grid max-w-6xl gap-10 px-4 py-12 md:grid-cols-5 md:px-8">
          <div className="md:col-span-2">
            <Logo />
            <p className="mt-4 max-w-xs text-sm text-ink-600">{APP_TAGLINE}.</p>
            <p className="mt-4 text-sm text-ink-600">
              Questions?{" "}
              <a href={`mailto:${SUPPORT_EMAIL}`} className="font-medium text-brand-700 hover:underline">
                {SUPPORT_EMAIL}
              </a>
            </p>
          </div>
          {FOOTER.map((column) => (
            <div key={column.title}>
              <h2 className="text-sm font-semibold text-ink-900">{column.title}</h2>
              <ul className="mt-4 space-y-3 text-sm">
                {column.links.map((link) => (
                  <li key={link.href}>
                    <Link href={link.href} className="text-ink-600 hover:text-ink-900">
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div className="border-t border-ink-200">
          <div className="mx-auto flex max-w-6xl flex-col gap-2 px-4 py-6 text-xs text-ink-500 sm:flex-row sm:justify-between md:px-8">
            <p>
              © {new Date().getFullYear()} {COMPANY_NAME}. All rights reserved.
            </p>
            <p>{APP_NAME} is an independent product and is not affiliated with or endorsed by Airbnb.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}
