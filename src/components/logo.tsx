import Link from "next/link";
import { APP_NAME } from "@/lib/brand";

/** House with ledger lines: the same mark as the favicon and home-screen icon. */
export function LogoMark({ className = "size-8" }: { className?: string }) {
  return (
    <svg aria-hidden viewBox="0 0 32 32" className={`shrink-0 ${className}`}>
      <rect width="32" height="32" rx="9" className="fill-brand-600" />
      <path d="M9 15.5 16 9.5l7 6v7a1 1 0 0 1-1 1H10a1 1 0 0 1-1-1Z" fill="none" stroke="#fff" strokeWidth="2" strokeLinejoin="round" />
      <path d="M12.5 18.5h7M12.5 21h4.5" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

export function Logo({ href = "/" }: { href?: string }) {
  const [first, ...rest] = APP_NAME.split(" ");
  return (
    <Link href={href} aria-label={APP_NAME} className="flex items-center gap-2.5 text-[17px] font-semibold tracking-tight text-ink-900">
      <LogoMark />
      <span aria-hidden>
        {first}
        {rest.length ? <span className="text-brand-600"> {rest.join(" ")}</span> : null}
      </span>
    </Link>
  );
}
