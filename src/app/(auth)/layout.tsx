import Link from "next/link";
import type { ReactNode } from "react";
import { Icon } from "@/components/icons";
import { Logo } from "@/components/logo";
import { TRIAL_DAYS } from "@/lib/billing";

const POINTS = [
  "Import your Airbnb transactions in seconds",
  "Statements for every owner, with your fees and expenses",
  "PDF, email and a private portal for owners",
  `${TRIAL_DAYS}-day free trial, no credit card`,
];

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <div className="grid min-h-screen lg:grid-cols-2">
      <div className="flex flex-col px-4 py-8 sm:px-8">
        <Logo />
        <div className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center py-10">{children}</div>
        <p className="text-center text-xs text-slate-500">
          <Link href="/terms" className="hover:underline">
            Terms
          </Link>{" "}
          ·{" "}
          <Link href="/privacy" className="hover:underline">
            Privacy
          </Link>
        </p>
      </div>
      <aside className="relative hidden overflow-hidden bg-brand-800 text-white lg:flex lg:flex-col lg:justify-center lg:px-16">
        <div aria-hidden className="absolute -top-32 -right-32 size-96 rounded-full bg-white/5" />
        <div aria-hidden className="absolute -bottom-24 -left-24 size-72 rounded-full bg-white/5" />
        <h2 className="relative max-w-md text-3xl font-bold tracking-tight">Month-end owner statements, done in minutes.</h2>
        <ul className="relative mt-8 space-y-4 text-brand-100">
          {POINTS.map((point) => (
            <li key={point} className="flex items-start gap-3">
              <span className="mt-0.5 grid size-6 shrink-0 place-items-center rounded-full bg-white/10">
                <Icon name="check" className="size-4 text-white" />
              </span>
              {point}
            </li>
          ))}
        </ul>
      </aside>
    </div>
  );
}
