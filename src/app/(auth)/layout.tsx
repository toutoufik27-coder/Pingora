import Link from "next/link";
import type { ReactNode } from "react";
import { Logo } from "@/components/logo";

export default function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col items-center px-4 py-10">
      <Logo />
      <div className="mt-8 w-full max-w-md rounded-xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">{children}</div>
      <p className="mt-6 text-xs text-slate-500">
        <Link href="/terms" className="hover:underline">
          Terms
        </Link>{" "}
        ·{" "}
        <Link href="/privacy" className="hover:underline">
          Privacy
        </Link>
      </p>
    </div>
  );
}
