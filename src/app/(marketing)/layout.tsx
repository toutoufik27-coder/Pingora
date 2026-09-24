import Link from "next/link";
import type { ReactNode } from "react";
import { Logo } from "@/components/logo";
import { buttonClass } from "@/components/ui";
import { APP_NAME, COMPANY_NAME, SUPPORT_EMAIL } from "@/lib/brand";

export default function MarketingLayout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col bg-white">
      <header className="border-b border-slate-100">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-4 md:px-8">
          <Logo />
          <nav className="flex items-center gap-1 text-sm sm:gap-3">
            <Link href="/#features" className="hidden px-2 py-1 text-slate-600 hover:text-slate-900 sm:inline">
              Features
            </Link>
            <Link href="/pricing" className="px-2 py-1 text-slate-600 hover:text-slate-900">
              Pricing
            </Link>
            <Link href="/login" className="px-2 py-1 text-slate-600 hover:text-slate-900">
              Log in
            </Link>
            <Link href="/signup" className={buttonClass("primary", "sm")}>
              Start free trial
            </Link>
          </nav>
        </div>
      </header>
      <main className="flex-1">{children}</main>
      <footer className="border-t border-slate-100 bg-slate-50">
        <div className="mx-auto flex max-w-6xl flex-col gap-4 px-4 py-8 text-sm text-slate-500 sm:flex-row sm:items-center sm:justify-between md:px-8">
          <p>
            © {new Date().getFullYear()} {COMPANY_NAME}. {APP_NAME} is not affiliated with Airbnb.
          </p>
          <nav className="flex flex-wrap gap-4">
            <Link href="/pricing" className="hover:text-slate-900">
              Pricing
            </Link>
            <Link href="/terms" className="hover:text-slate-900">
              Terms
            </Link>
            <Link href="/privacy" className="hover:text-slate-900">
              Privacy
            </Link>
            <a href={`mailto:${SUPPORT_EMAIL}`} className="hover:text-slate-900">
              Contact
            </a>
          </nav>
        </div>
      </footer>
    </div>
  );
}
